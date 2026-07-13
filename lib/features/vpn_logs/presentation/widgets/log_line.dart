import 'package:flutter/material.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/core/theme/oko_typography.dart';
import 'package:vpn_oko/features/vpn_logs/domain/entities/log_entry.dart';

class LogLine extends StatelessWidget {
  const LogLine({required this.entry, super.key});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final tones = Theme.of(context).extension<OkoTones>()!;
    final mono = OkoTypography.mono(Theme.of(context).brightness);
    final levelColor = switch (entry.level) {
      LogLevel.info => tones.textSecondary,
      LogLevel.warning => tones.accentTransitional,
      LogLevel.error => tones.accentError,
    };
    return Semantics(
      label: '${entry.level.name}: ${entry.text}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Text.rich(
            TextSpan(
              style: mono.copyWith(color: levelColor),
              children: [
                TextSpan(
                  text: '${_hms(entry.time)}  ',
                  style: TextStyle(color: tones.textSecondary),
                ),
                TextSpan(text: entry.text),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _hms(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}
