import 'package:flutter/material.dart';
import 'package:vpn_oko/features/vpn_logs/domain/entities/log_entry.dart';

class LogLine extends StatelessWidget {
  const LogLine({required this.entry, super.key});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
