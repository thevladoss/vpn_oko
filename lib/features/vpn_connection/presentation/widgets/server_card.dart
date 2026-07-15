import 'package:flutter/material.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';

class ServerCard extends StatelessWidget {
  const ServerCard({
    required this.serverName,
    required this.host,
    required this.port,
    this.onTap,
    super.key,
  });

  final String serverName;
  final String host;
  final int port;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    final content = Padding(
      padding: const EdgeInsets.all(24),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
          if (onTap != null) ...[
            const SizedBox(width: 12),
            Icon(Icons.chevron_right_rounded, color: tones.textSecondary),
          ],
        ],
      ),
    );
    final decoration = BoxDecoration(
      color: tones.surfaceCard,
      borderRadius: BorderRadius.circular(20),
    );
    if (onTap == null) {
      return Container(decoration: decoration, child: content);
    }
    return Container(
      decoration: decoration,
      child: Semantics(
        button: true,
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: content,
          ),
        ),
      ),
    );
  }
}
