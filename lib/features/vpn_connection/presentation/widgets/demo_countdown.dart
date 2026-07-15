import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/formatters/duration_format.dart';

class DemoCountdown extends StatefulWidget {
  const DemoCountdown({required this.deadline, this.style, super.key});

  final DateTime deadline;
  final TextStyle? style;

  @override
  State<DemoCountdown> createState() => _DemoCountdownState();
}

class _DemoCountdownState extends State<DemoCountdown> {
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(DemoCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) {
      _sync();
    }
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    if (_remaining() <= Duration.zero) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining() <= Duration.zero) {
        _timer?.cancel();
        _timer = null;
      }
      setState(() {});
    });
  }

  Duration _remaining() => widget.deadline.difference(DateTime.now());

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(hhmmss(_remaining()), style: widget.style);
  }
}
