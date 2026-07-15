import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/features/server_config/domain/entities/latency_result.dart';
import 'package:vpn_oko/features/server_config/presentation/widgets/latency_pill.dart';
import 'package:vpn_oko/features/server_config/presentation/widgets/protocol_badge.dart';

class ServerListTile extends StatelessWidget {
  const ServerListTile({
    required this.dismissKey,
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    required this.active,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
    this.latency,
    super.key,
  });

  final Key dismissKey;
  final String name;
  final String host;
  final int port;
  final String protocol;
  final LatencyResult? latency;
  final bool active;
  final VoidCallback onSelect;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  String get _address => host.contains(':') ? '[$host]:$port' : '$host:$port';

  Future<bool> _confirm(DismissDirection direction) async {
    unawaited(HapticFeedback.mediumImpact());
    if (direction == DismissDirection.endToStart) {
      onDelete();
    } else {
      onRename();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    return Dismissible(
      key: dismissKey,
      confirmDismiss: _confirm,
      background: const _SwipeAction(
        icon: Icons.edit_rounded,
        alignment: Alignment.centerLeft,
        tone: _SwipeTone.rename,
      ),
      secondaryBackground: const _SwipeAction(
        icon: Icons.delete_rounded,
        alignment: Alignment.centerRight,
        tone: _SwipeTone.delete,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: tones.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: active
              ? Border.all(color: tones.accentConnected, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: MergeSemantics(
                child: Semantics(
                  selected: active,
                  button: true,
                  child: Material(
                    type: MaterialType.transparency,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        unawaited(HapticFeedback.mediumImpact());
                        onSelect();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.dns_rounded, color: tones.textSecondary),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: tones.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _address,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: tones.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      ProtocolBadge(protocol: protocol),
                                      const SizedBox(width: 8),
                                      LatencyPill(latency: latency),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (active) ...[
                              const SizedBox(width: 12),
                              Icon(
                                Icons.check_circle_rounded,
                                color: tones.accentConnected,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _TileMenu(onRename: onRename, onDelete: onDelete),
          ],
        ),
      ),
    );
  }
}

enum _SwipeTone { rename, delete }

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.icon,
    required this.alignment,
    required this.tone,
  });

  final IconData icon;
  final AlignmentGeometry alignment;
  final _SwipeTone tone;

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final color = switch (tone) {
      _SwipeTone.rename => tones.accentTransitional,
      _SwipeTone.delete => tones.accentError,
    };
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: color),
    );
  }
}

enum _TileMenuAction { rename, delete }

class _TileMenu extends StatelessWidget {
  const _TileMenu({required this.onRename, required this.onDelete});

  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    return PopupMenuButton<_TileMenuAction>(
      icon: Icon(Icons.more_vert_rounded, color: tones.textSecondary),
      tooltip: 'Действия',
      onSelected: (action) => switch (action) {
        _TileMenuAction.rename => onRename(),
        _TileMenuAction.delete => onDelete(),
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _TileMenuAction.rename,
          child: Text('Переименовать'),
        ),
        PopupMenuItem(
          value: _TileMenuAction.delete,
          child: Text('Удалить'),
        ),
      ],
    );
  }
}
