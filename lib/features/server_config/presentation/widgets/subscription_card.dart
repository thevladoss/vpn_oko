import 'package:flutter/material.dart';
import 'package:vpn_osin/core/theme/osin_tones.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription.dart';

const List<String> _units = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ', 'ПБ'];

String formatDataSize(int bytes) {
  if (bytes <= 0) return '0 Б';
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < _units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  final isWhole = value == value.roundToDouble();
  final rounded = unit == 0 || isWhole || value >= 100
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return '$rounded ${_units[unit]}';
}

String _formatExpiry(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

class SubscriptionCard extends StatelessWidget {
  const SubscriptionCard({
    required this.subscription,
    required this.busy,
    required this.onRefresh,
    required this.onDelete,
    super.key,
  });

  final Subscription subscription;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onDelete;

  String? get _trafficText {
    if (subscription.total <= 0) return 'Трафик: безлимит';
    final used = subscription.upload + subscription.download;
    final remaining = subscription.total - used;
    final left = remaining < 0 ? 0 : remaining;
    return 'Осталось ${formatDataSize(left)} '
        'из ${formatDataSize(subscription.total)}';
  }

  String? get _expiryText {
    final expiresAt = subscription.expiresAt;
    if (expiresAt == null) return null;
    return 'До ${_formatExpiry(expiresAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final tones = context.osinTones;
    final textTheme = Theme.of(context).textTheme;
    final traffic = _trafficText;
    final expiry = _expiryText;
    return Container(
      decoration: BoxDecoration(
        color: tones.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Icon(Icons.cloud_sync_rounded, color: tones.textSecondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subscription.name,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: tones.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (traffic != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    traffic,
                    style: textTheme.bodySmall?.copyWith(
                      color: tones.textSecondary,
                    ),
                  ),
                ],
                if (expiry != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    expiry,
                    style: textTheme.bodySmall?.copyWith(
                      color: tones.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (busy)
            SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tones.accentConnected,
                  ),
                ),
              ),
            )
          else
            IconButton(
              onPressed: onRefresh,
              tooltip: 'Обновить',
              icon: Icon(Icons.refresh_rounded, color: tones.accentConnected),
            ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Удалить',
            icon: Icon(Icons.delete_outline_rounded, color: tones.accentError),
          ),
        ],
      ),
    );
  }
}
