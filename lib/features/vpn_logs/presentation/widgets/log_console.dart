import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_oko/core/theme/oko_motion.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/bloc/logs_cubit.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/bloc/logs_state.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/widgets/log_line.dart';

class LogConsole extends StatelessWidget {
  const LogConsole({super.key});

  static const double _bottomThreshold = 24;

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    return DraggableScrollableSheet(
      initialChildSize: 0.12,
      minChildSize: 0.12,
      maxChildSize: 0.70,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: tones.surfaceElevated,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _Header(onCopy: () => _copyAll(context)),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is UserScrollNotification) {
                      _syncAutoScroll(context, scrollController);
                    }
                    return false;
                  },
                  child: BlocConsumer<LogsCubit, LogsState>(
                    listener: (context, state) =>
                        _followTail(state, scrollController),
                    builder: (context, state) {
                      if (state.entries.isEmpty) {
                        return _EmptyState(controller: scrollController);
                      }
                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: state.entries.length,
                        itemBuilder: (_, index) =>
                            LogLine(entry: state.entries[index]),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _syncAutoScroll(BuildContext context, ScrollController controller) {
    if (!controller.hasClients) return;
    final position = controller.position;
    if (!position.hasContentDimensions) return;
    final atBottom =
        position.pixels >= position.maxScrollExtent - _bottomThreshold;
    if (atBottom) {
      context.read<LogsCubit>().resumeAutoScroll();
    } else {
      context.read<LogsCubit>().pauseAutoScroll();
    }
  }

  void _followTail(LogsState state, ScrollController controller) {
    if (!state.autoScroll || !controller.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;
      unawaited(
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: OkoMotion.autoscroll,
          curve: OkoMotion.autoscrollCurve,
        ),
      );
    });
  }

  Future<void> _copyAll(BuildContext context) async {
    final cubit = context.read<LogsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final count = cubit.state.entries.length;
    await Clipboard.setData(ClipboardData(text: cubit.plainText()));
    await HapticFeedback.selectionClick();
    messenger.showSnackBar(
      SnackBar(content: Text('Copied $count lines')),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onCopy});

  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 8),
          Row(
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Logs',
                  style: textTheme.titleMedium
                      ?.copyWith(color: tones.textPrimary),
                ),
              ),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Copy all logs',
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    onPressed: onCopy,
                    icon: Icon(Icons.copy_rounded, color: tones.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terminal_rounded, size: 32, color: tones.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Waiting for events',
              style: textTheme.bodyMedium?.copyWith(color: tones.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Tunnel logs stream here in real time.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: tones.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}
