import 'package:flutter/material.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/features/server_config/domain/entities/latency_result.dart';

class LatencyPill extends StatelessWidget {
  const LatencyPill({required this.latency, super.key});

  final LatencyResult? latency;

  String get _label => switch (latency) {
    LatencyMeasured(:final rtt) => '${rtt.inMilliseconds} ms',
    LatencyUnreachable() => 'недоступен',
    null => '…',
  };

  Color _color(OkoTones tones) => switch (latency) {
    LatencyMeasured(:final rtt) when rtt.inMilliseconds < 100 =>
      tones.accentConnected,
    LatencyMeasured(:final rtt) when rtt.inMilliseconds < 300 =>
      tones.accentTransitional,
    LatencyMeasured() => tones.accentError,
    LatencyUnreachable() => tones.accentError,
    null => tones.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final color = _color(tones);
    final style = Theme.of(context).textTheme.labelSmall ?? const TextStyle();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label,
        style: style.copyWith(color: color),
      ),
    );
  }
}
