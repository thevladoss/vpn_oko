import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_osin/core/theme/osin_motion.dart';
import 'package:vpn_osin/core/theme/osin_tones.dart';
import 'package:vpn_osin/core/widgets/top_alert.dart';
import 'package:vpn_osin/core/widgets/top_alert_scope.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_osin/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/server_list_cubit.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/server_list_state.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/empty_server_paste_field.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/proxy_error_text.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/server_list_tile.dart';

String _protocolOf(ProxyConfig config) => switch (config) {
  VlessConfig() => 'vless',
  VmessConfig() => 'vmess',
  TrojanConfig() => 'trojan',
  ShadowsocksConfig() => 'ss',
  Hysteria2Config() => 'hysteria2',
};

class ServerManagementSheet extends StatefulWidget {
  const ServerManagementSheet({super.key});

  @override
  State<ServerManagementSheet> createState() => _ServerManagementSheetState();
}

class _ServerManagementSheetState extends State<ServerManagementSheet>
    with SingleTickerProviderStateMixin {
  static const Duration _total = Duration(milliseconds: 590);
  static const int _maxStaggerSteps = 4;

  late final AnimationController _entrance;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: _total);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      unawaited(_entrance.forward());
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  TopAlertKind _kindFor(ServerListNotice notice) => switch (notice) {
    NoticeSaved() => TopAlertKind.success,
    NoticeDuplicate() => TopAlertKind.error,
    NoticeInvalid() => TopAlertKind.error,
  };

  Interval _interval(Duration start) {
    final begin = start.inMilliseconds / _total.inMilliseconds;
    final end =
        (start.inMilliseconds + OsinMotion.enterScreen.inMilliseconds) /
        _total.inMilliseconds;
    return Interval(begin, end, curve: OsinMotion.enterScreenCurve);
  }

  Interval _tileInterval(int index) {
    final step = index > _maxStaggerSteps ? _maxStaggerSteps : index;
    return _interval(OsinMotion.staggerServerCard * step);
  }

  @override
  Widget build(BuildContext context) {
    final tones = context.osinTones;
    final textTheme = Theme.of(context).textTheme;
    return BlocConsumer<ServerListCubit, ServerListState>(
      listenWhen: (previous, current) =>
          current.notice != null && current.notice != previous.notice,
      listener: (context, state) {
        final notice = state.notice;
        if (notice == null) return;
        unawaited(HapticFeedback.mediumImpact());
        TopAlertScope.of(context).show(_noticeText(notice), _kindFor(notice));
      },
      builder: (context, state) {
        return SafeArea(
          child: ConstrainedBox(
            key: const ValueKey('sheet-bounds'),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Серверы',
                        style: textTheme.titleLarge?.copyWith(
                          color: tones.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            context.read<ServerListCubit>().addFromClipboard(),
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('Вставить из буфера'),
                      ),
                      const SizedBox(height: 20),
                      Flexible(
                        child: state.servers.isEmpty
                            ? _Staggered(
                                animation: _entrance,
                                interval: _interval(OsinMotion.staggerIris),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: EmptyServerPasteField(
                                    onPaste: () => context
                                        .read<ServerListCubit>()
                                        .addFromClipboard(),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                itemCount: state.servers.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final profile = state.servers[index];
                                  return _Staggered(
                                    animation: _entrance,
                                    interval: _tileInterval(index),
                                    child: ServerListTile(
                                      dismissKey: ValueKey(
                                        'server-${profile.id}',
                                      ),
                                      name: profile.label,
                                      host: profile.config.host,
                                      port: profile.config.port,
                                      protocol: _protocolOf(profile.config),
                                      active: profile.id == state.activeId,
                                      onSelect: () => context
                                          .read<ServerListCubit>()
                                          .setActive(profile.id),
                                      onRename: () => _rename(context, profile),
                                      onDelete: () => _delete(context, profile),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _noticeText(ServerListNotice notice) => switch (notice) {
    NoticeSaved(:final label) => 'Сервер «$label» сохранён',
    NoticeDuplicate() => 'Такой сервер уже есть',
    NoticeInvalid(:final error) => describeProxyError(error),
  };

  Future<void> _rename(BuildContext context, ServerProfile profile) async {
    final cubit = context.read<ServerListCubit>();
    final label = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: profile.label),
    );
    if (label == null) return;
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    await cubit.rename(profile.id, trimmed);
    if (!context.mounted) return;
    unawaited(HapticFeedback.mediumImpact());
    TopAlertScope.of(context).show('Имя обновлено', TopAlertKind.success);
  }

  Future<void> _delete(BuildContext context, ServerProfile profile) async {
    final cubit = context.read<ServerListCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить сервер?'),
        content: Text(
          '«${profile.label}» будет удалён без возможности отмены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await cubit.delete(profile.id);
    }
  }
}

class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.animation,
    required this.interval,
    required this.child,
  });

  final Animation<double> animation;
  final Interval interval;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = interval.transform(animation.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 24),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial)
      ..selection = TextSelection.collapsed(offset: widget.initial.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Переименовать сервер'),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Название'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
