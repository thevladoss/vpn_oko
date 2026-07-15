import 'package:flutter/material.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_oko/features/server_config/domain/entities/server_profile.dart';

enum ServerTileAction { rename, delete }

class ServerListTile extends StatelessWidget {
  const ServerListTile({
    required this.profile,
    required this.isActive,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    super.key,
  });

  final ServerProfile profile;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  String get _protocol => switch (profile.config) {
    VlessConfig() => 'VLESS',
    VmessConfig() => 'VMess',
    TrojanConfig() => 'Trojan',
    ShadowsocksConfig() => 'Shadowsocks',
    Hysteria2Config() => 'Hysteria2',
  };

  String get _address {
    final host = profile.config.host;
    final wrapped = host.contains(':') ? '[$host]' : host;
    return '$wrapped:${profile.config.port}';
  }

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    final accent = isActive ? tones.accentConnected : tones.textSecondary;
    return Material(
      color: tones.surfaceCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                isActive
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: accent,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.label,
                      style: textTheme.bodyMedium?.copyWith(
                        color: tones.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _ProtocolBadge(label: _protocol),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _address,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: tones.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<ServerTileAction>(
                icon: Icon(Icons.more_vert_rounded, color: tones.textSecondary),
                onSelected: (action) => switch (action) {
                  ServerTileAction.rename => onRename(),
                  ServerTileAction.delete => onDelete(),
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: ServerTileAction.rename,
                    child: Text('Переименовать'),
                  ),
                  PopupMenuItem(
                    value: ServerTileAction.delete,
                    child: Text('Удалить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtocolBadge extends StatelessWidget {
  const _ProtocolBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tones.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: tones.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
