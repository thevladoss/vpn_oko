import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_osin/core/theme/osin_motion.dart';
import 'package:vpn_osin/core/theme/osin_tones.dart';
import 'package:vpn_osin/features/vpn_logs/presentation/bloc/logs_cubit.dart';
import 'package:vpn_osin/features/vpn_logs/presentation/bloc/logs_state.dart';
import 'package:vpn_osin/features/vpn_logs/presentation/widgets/log_line.dart';

class LogConsole extends StatefulWidget {
  const LogConsole({super.key});

  static const double collapsedHeight = 64;

  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole>
    with SingleTickerProviderStateMixin {
  static const double _bottomThreshold = 24;
  static const double _expandedFraction = 0.70;
  static const double _flingVelocity = 320;

  late final AnimationController _controller;
  final ScrollController _scroll = ScrollController();
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: OsinMotion.autoscroll,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  double get _expandedHeight =>
      MediaQuery.sizeOf(context).height * _expandedFraction;

  double get _dragRange => _expandedHeight - LogConsole.collapsedHeight;

  void _animateTo({required bool open, required bool haptic}) {
    if (haptic) unawaited(HapticFeedback.selectionClick());
    _open = open;
    unawaited(
      _controller.animateTo(
        open ? 1 : 0,
        duration: OsinMotion.autoscroll,
        curve: OsinMotion.autoscrollCurve,
      ),
    );
  }

  void _toggle() => _animateTo(open: !_open, haptic: true);

  void _onDragUpdate(DragUpdateDetails details) {
    if (_dragRange <= 0) return;
    final delta = details.primaryDelta ?? 0;
    _controller.value =
        (_controller.value - delta / _dragRange).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    final open = velocity.abs() > _flingVelocity
        ? velocity < 0
        : _controller.value >= 0.5;
    _animateTo(open: open, haptic: _open != open);
  }

  @override
  Widget build(BuildContext context) {
    final tones = context.osinTones;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final height =
              LogConsole.collapsedHeight + _dragRange * _controller.value;
          return SizedBox(
            height: height + bottomInset,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tones.surfaceElevated,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Column(
                  children: [
                    _Header(
                      onTap: _toggle,
                      onDragUpdate: _onDragUpdate,
                      onDragEnd: _onDragEnd,
                      onCopy: () => _copyAll(context),
                    ),
                    Expanded(child: ClipRect(child: child)),
                  ],
                ),
              ),
            ),
          );
        },
        child: BlocConsumer<LogsCubit, LogsState>(
          listener: (context, state) => _followTail(state),
          builder: (context, state) {
            if (state.entries.isEmpty) {
              return const SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                child: _EmptyState(),
              );
            }
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification) {
                  _syncAutoScroll(context);
                }
                return false;
              },
              child: ListView.builder(
                controller: _scroll,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: state.entries.length,
                itemBuilder: (_, index) => LogLine(entry: state.entries[index]),
              ),
            );
          },
        ),
      ),
    );
  }

  void _syncAutoScroll(BuildContext context) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    final atBottom =
        position.pixels >= position.maxScrollExtent - _bottomThreshold;
    if (atBottom) {
      context.read<LogsCubit>().resumeAutoScroll();
    } else {
      context.read<LogsCubit>().pauseAutoScroll();
    }
  }

  void _followTail(LogsState state) {
    if (!state.autoScroll || !_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      if (!position.hasContentDimensions) return;
      unawaited(
        _scroll.animateTo(
          position.maxScrollExtent,
          duration: OsinMotion.autoscroll,
          curve: OsinMotion.autoscrollCurve,
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
  const _Header({
    required this.onTap,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onCopy,
  });

  final VoidCallback onTap;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    final tones = context.osinTones;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Toggle logs panel',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onVerticalDragUpdate: onDragUpdate,
        onVerticalDragEnd: onDragEnd,
        child: SizedBox(
          height: LogConsole.collapsedHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 4),
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
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tones = context.osinTones;
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
