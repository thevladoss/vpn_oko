import 'package:flutter/material.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';

class ServerCard extends StatelessWidget {
  const ServerCard({
    required this.serverName,
    required this.host,
    required this.port,
    super.key,
  });

  final String serverName;
  final String host;
  final int port;

  @override
  Widget build(BuildContext context) {
    final tones = Theme.of(context).extension<OkoTones>()!;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tones.surfaceCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.dns_rounded, color: tones.textSecondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serverName,
                  style: textTheme.bodyMedium?.copyWith(
                    color: tones.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$host:$port',
                  style: textTheme.bodySmall?.copyWith(
                    color: tones.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: tones.textSecondary),
        ],
      ),
    );
  }
}
