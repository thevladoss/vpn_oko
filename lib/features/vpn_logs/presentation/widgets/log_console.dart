import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_oko/core/theme/oko_motion.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/bloc/logs_cubit.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/bloc/logs_state.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/widgets/log_line.dart';

class LogConsole extends StatefulWidget {
  const LogConsole({super.key});

  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  static const double _bottomThreshold = 24;
  static const double _collapsed = 0.12;
  static const double _expanded = 0.70;
  static const double _headerExtent = 60;

  final DraggableScrollableController _sheet =
      DraggableScrollableController();

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_sheet.isAttached) return;
    final target = _sheet.size > (_collapsed + _expanded) / 2
        ? _collapsed
        : _expanded;
    unawaited(
      _sheet.animateTo(
        target,
        duration: OkoMotion.autoscroll,
        curve: OkoMotion.autoscrollCurve,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    return DraggableScrollableSheet(
      controller: _sheet,
      initialChildSize: _collapsed,
      minChildSize: _collapsed,
      maxChildSize: _expanded,
      snap: true,
      snapSizes: const [_collapsed, _expanded],
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: tones.surfaceElevated,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
                return CustomScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _HeaderDelegate(
                        extent: _headerExtent,
                        onCopy: () => _copyAll(context),
                        onToggle: _toggle,
                      ),
                    ),
                    if (state.entries.isEmpty)
                      const SliverToBoxAdapter(child: _EmptyState())
                    else
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 16),
                        sliver: SliverList.builder(
                          itemCount: state.entries.length,
                          itemBuilder: (_, index) =>
                              LogLine(entry: state.entries[index]),
                        ),
                      ),
                  ],
                );
              },
            ),
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
      final position = controller.position;
      if (!position.hasContentDimensions) return;
      unawaited(
        controller.animateTo(
          position.maxScrollExtent,
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

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  const _HeaderDelegate({
    required this.extent,
    required this.onCopy,
    required this.onToggle,
  });

  final double extent;
  final Future<void> Function() onCopy;
  final VoidCallback onToggle;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Toggle logs panel',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: ColoredBox(
          color: tones.surfaceElevated,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
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
                const SizedBox(height: 6),
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
                    Icon(Icons.expand_less_rounded, color: tones.textSecondary),
                    const Spacer(),
                    Semantics(
                      button: true,
                      label: 'Copy all logs',
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          onPressed: onCopy,
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.copy_rounded,
                            color: tones.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_HeaderDelegate oldDelegate) {
    return extent != oldDelegate.extent;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
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
    );
  }
}
