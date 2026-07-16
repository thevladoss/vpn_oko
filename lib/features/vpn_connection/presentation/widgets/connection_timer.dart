import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/formatters/duration_format.dart';

class ConnectionTimer extends StatefulWidget {
  const ConnectionTimer({required this.connectedSince, super.key});

  final DateTime? connectedSince;

  @override
  State<ConnectionTimer> createState() => _ConnectionTimerState();
}

class _ConnectionTimerState extends State<ConnectionTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(ConnectionTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connectedSince != widget.connectedSince) {
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    if (widget.connectedSince == null) {
      return;
    }
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final since = widget.connectedSince;
    if (since == null) {
      return const SizedBox.shrink();
    }
    return FittedBox(
      child: Text(
        hhmmss(DateTime.now().difference(since)),
        style: Theme.of(context).textTheme.displayLarge?.copyWith(
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}
