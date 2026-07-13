import 'package:flutter/material.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/formatters/byte_format.dart';

enum TrafficDirection { down, up }

class TrafficTile extends StatelessWidget {
  const TrafficTile({
    required this.direction,
    required this.bytes,
    required this.active,
    super.key,
  });

  final TrafficDirection direction;
  final int bytes;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    final accent = active ? tones.accentConnected : tones.textSecondary;
    final isDown = direction == TrafficDirection.down;
    final icon =
        isDown ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    final label = isDown ? 'DOWN' : 'UP';
    final (value, unit) = formatBytesParts(bytes);
    final formatted = '$value $unit';
    final semantics = isDown ? 'Downloaded $formatted' : 'Uploaded $formatted';

    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Container(
        height: 72,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tones.surfaceCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(color: accent),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: textTheme.titleMedium?.copyWith(
                    color: tones.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: textTheme.bodySmall?.copyWith(
                    color: tones.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
