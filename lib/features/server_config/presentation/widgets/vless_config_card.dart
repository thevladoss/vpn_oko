import 'package:flutter/material.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/features/server_config/domain/entities/latency_result.dart';
import 'package:vpn_oko/features/server_config/domain/entities/vless_config.dart';

String maskUuid(String uuid) => uuid.length >= 12
    ? '${uuid.substring(0, 8)}…${uuid.substring(uuid.length - 4)}'
    : '••••';

class VlessConfigCard extends StatelessWidget {
  const VlessConfigCard({
    required this.config,
    this.latency,
    super.key,
  });

  final VlessConfig config;
  final LatencyResult? latency;

  String get _address => config.host.contains(':')
      ? '[${config.host}]:${config.port}'
      : '${config.host}:${config.port}';

  String get _meta {
    final base = '${config.transport} · ${config.security}';
    final sni = config.sni;
    return sni == null ? base : '$base · $sni';
  }

  String get _latencyLabel => switch (latency) {
    LatencyMeasured(:final rtt) => '· ${rtt.inMilliseconds} ms',
    LatencyUnreachable() => '· недоступен',
    null => '',
  };

  Color _latencyColor(OkoTones tones) => switch (latency) {
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
    final textTheme = Theme.of(context).textTheme;
    final latencyLabel = _latencyLabel;
    return Container(
      padding: const EdgeInsets.all(24),
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
                  _meta,
                  style: textTheme.bodySmall?.copyWith(
                    color: tones.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  maskUuid(config.uuid),
                  style: textTheme.bodySmall?.copyWith(
                    color: tones.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (latencyLabel.isNotEmpty) ...[
            const SizedBox(width: 12),
            Text(
              latencyLabel,
              style: textTheme.bodySmall?.copyWith(
                color: _latencyColor(tones),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
