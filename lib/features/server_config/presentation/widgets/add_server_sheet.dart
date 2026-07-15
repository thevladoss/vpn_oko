import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_oko/core/theme/oko_motion.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_oko/features/server_config/domain/entities/proxy_parse_result.dart';
import 'package:vpn_oko/features/server_config/domain/services/proxy_parser.dart';
import 'package:vpn_oko/features/server_config/presentation/cubit/server_list_cubit.dart';
import 'package:vpn_oko/features/server_config/presentation/widgets/protocol_badge.dart';
import 'package:vpn_oko/features/server_config/presentation/widgets/proxy_error_text.dart';
import 'package:vpn_oko/features/server_config/presentation/widgets/vless_config_card.dart';

class AddServerSheet extends StatefulWidget {
  const AddServerSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<ServerListCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const AddServerSheet(),
      ),
    );
  }

  @override
  State<AddServerSheet> createState() => _AddServerSheetState();
}

class _AddServerSheetState extends State<AddServerSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ProxyParseResult? get _result {
    final text = _controller.text.trim();
    if (text.isEmpty) return null;
    return parseProxyUrl(text);
  }

  Future<void> _paste() async {
    unawaited(HapticFeedback.mediumImpact());
    final raw = await context.read<ServerListCubit>().clipboard.readText();
    if (!mounted || raw == null) return;
    setState(() {
      _controller.text = raw.trim();
    });
  }

  Future<void> _submit() async {
    unawaited(HapticFeedback.mediumImpact());
    final cubit = context.read<ServerListCubit>();
    final navigator = Navigator.of(context);
    await cubit.addFromScan(_controller.text.trim());
    await navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    final result = _result;
    final config = result is ProxyParsed ? result.config : null;
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tones.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, media.padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tones.textSecondary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  'Добавить сервер',
                  style: textTheme.titleMedium?.copyWith(
                    color: tones.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _LinkField(controller: _controller, onChanged: _onChanged),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste_rounded),
                  label: const Text('Вставить из буфера'),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : OkoMotion.statusCrossfade,
                switchInCurve: OkoMotion.statusCrossfadeCurve,
                switchOutCurve: OkoMotion.statusCrossfadeCurve,
                child: _Preview(result: result),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: config == null ? null : _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Добавить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onChanged(String _) => setState(() {});
}

class _LinkField extends StatelessWidget {
  const _LinkField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: 3,
      minLines: 1,
      autocorrect: false,
      enableSuggestions: false,
      style: textTheme.bodyMedium?.copyWith(color: tones.textPrimary),
      decoration: InputDecoration(
        filled: true,
        fillColor: tones.surfaceCard,
        hintText: 'vless://…',
        hintStyle: textTheme.bodyMedium?.copyWith(color: tones.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tones.accentConnected, width: 1.5),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.result});

  final ProxyParseResult? result;

  @override
  Widget build(BuildContext context) {
    return switch (result) {
      null => const _IdleHint(key: ValueKey('idle')),
      ProxyParseFailure(:final error) => _ParseErrorBlock(
        key: const ValueKey('error'),
        error: error,
      ),
      ProxyParsed(:final config) => _ConfigPreview(
        key: const ValueKey('preview'),
        config: config,
      ),
    };
  }
}

class _IdleHint extends StatelessWidget {
  const _IdleHint({super.key});

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: tones.surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Вставьте vless://-ссылку — покажем превью перед добавлением.',
        textAlign: TextAlign.center,
        style: textTheme.bodySmall?.copyWith(color: tones.textSecondary),
      ),
    );
  }
}

class _ParseErrorBlock extends StatelessWidget {
  const _ParseErrorBlock({required this.error, super.key});

  final ProxyParseError error;

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tones.accentError.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: tones.accentError),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              describeProxyError(error),
              style: textTheme.bodySmall?.copyWith(
                color: tones.accentError,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigPreview extends StatelessWidget {
  const _ConfigPreview({required this.config, super.key});

  final ProxyConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ProtocolBadge(protocol: _protocolLabel(config)),
        ),
        const SizedBox(height: 12),
        _ProxyPreviewCard(config: config),
      ],
    );
  }
}

class _ProxyPreviewCard extends StatelessWidget {
  const _ProxyPreviewCard({required this.config});

  final ProxyConfig config;

  String get _address => config.host.contains(':')
      ? '[${config.host}]:${config.port}'
      : '${config.host}:${config.port}';

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tones.surfaceCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.dns_rounded, color: tones.textSecondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.name,
                  style: textTheme.bodyMedium?.copyWith(
                    color: tones.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _address,
                  style: textTheme.bodySmall?.copyWith(
                    color: tones.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  maskUuid(_secretOf(config)),
                  style: textTheme.bodySmall?.copyWith(
                    color: tones.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _protocolLabel(ProxyConfig config) => switch (config) {
  VlessConfig() => 'vless',
  VmessConfig() => 'vmess',
  TrojanConfig() => 'trojan',
  ShadowsocksConfig() => 'ss',
  Hysteria2Config() => 'hysteria2',
};

String _secretOf(ProxyConfig config) => switch (config) {
  VlessConfig(:final uuid) => uuid,
  VmessConfig(:final uuid) => uuid,
  TrojanConfig(:final password) => password,
  ShadowsocksConfig(:final password) => password,
  Hysteria2Config(:final password) => password,
};
