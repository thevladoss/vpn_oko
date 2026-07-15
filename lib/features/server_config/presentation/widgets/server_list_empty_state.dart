import 'package:flutter/material.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';

class ServerListEmptyState extends StatelessWidget {
  const ServerListEmptyState({this.onAdd, super.key});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    final onAdd = this.onAdd;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.dns_rounded, size: 32, color: tones.textSecondary),
        const SizedBox(height: 16),
        Text(
          'Добавьте первый сервер',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: tones.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Вставьте vless://-ссылку или отсканируйте QR-код.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: tones.textSecondary),
        ),
        if (onAdd != null) ...[
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.content_paste_rounded),
            label: const Text('Вставить из буфера'),
          ),
        ],
      ],
    );
  }
}
