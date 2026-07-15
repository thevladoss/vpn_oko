import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vpn_oko/core/theme/oko_motion.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/features/server_config/domain/entities/latency_result.dart';
import 'package:vpn_oko/features/server_config/presentation/widgets/latency_pill.dart';
import 'package:vpn_oko/features/server_config/presentation/widgets/protocol_badge.dart';

class ServerListTile extends StatefulWidget {
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

  @override
  State<ServerListTile> createState() => _ServerListTileState();
}

class _ServerListTileState extends State<ServerListTile>
    with SingleTickerProviderStateMixin {
  static const double _actionWidth = 100;
  static const double _maxReveal = _actionWidth * 2;
  static const double _velocityThreshold = 320;

  late final AnimationController _controller;
  Animation<double>? _snap;
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: OkoMotion.statusCrossfade,
    )..addListener(_onSnapTick);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSnapTick() {
    final snap = _snap;
    if (snap == null) return;
    setState(() => _offset = snap.value);
  }

  bool get _isOpen => _offset > 0.5;

  String get _address => widget.host.contains(':')
      ? '[${widget.host}]:${widget.port}'
      : '${widget.host}:${widget.port}';

  void _onDragUpdate(DragUpdateDetails details) {
    _controller.stop();
    setState(
      () => _offset = (_offset - details.delta.dx).clamp(0.0, _maxReveal),
    );
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final bool open;
    if (velocity < -_velocityThreshold) {
      open = true;
    } else if (velocity > _velocityThreshold) {
      open = false;
    } else {
      open = _offset > _maxReveal / 2;
    }
    _animateTo(open ? _maxReveal : 0);
  }

  void _animateTo(double target) {
    if (_offset == target) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _snap = null;
      setState(() => _offset = target);
      return;
    }
    _snap = Tween<double>(begin: _offset, end: target).animate(
      CurvedAnimation(
        parent: _controller,
        curve: OkoMotion.statusCrossfadeCurve,
      ),
    );
    _controller.reset();
    unawaited(_controller.forward());
  }

  void _handleBodyTap() {
    if (_isOpen) {
      _animateTo(0);
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    widget.onSelect();
  }

  void _handleAction(VoidCallback action) {
    unawaited(HapticFeedback.mediumImpact());
    _animateTo(0);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Container(
        decoration: BoxDecoration(
          color: tones.surfaceCard,
          borderRadius: BorderRadius.circular(20),
        ),
        foregroundDecoration: widget.active
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tones.accentConnected, width: 1.5),
              )
            : null,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RevealAction(
                    icon: Icons.edit_rounded,
                    label: 'Переименовать',
                    color: tones.accentTransitional,
                    onTap: () => _handleAction(widget.onRename),
                  ),
                  _RevealAction(
                    icon: Icons.delete_rounded,
                    label: 'Удалить',
                    color: tones.accentError,
                    onTap: () => _handleAction(widget.onDelete),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: Offset(-_offset, 0),
              child: _TileBody(
                name: widget.name,
                address: _address,
                protocol: widget.protocol,
                latency: widget.latency,
                active: widget.active,
                onTap: _handleBodyTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealAction extends StatelessWidget {
  const _RevealAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall ?? const TextStyle();
    return SizedBox(
      width: _ServerListTileState._actionWidth,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: color.withValues(alpha: 0.16),
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TileBody extends StatelessWidget {
  const _TileBody({
    required this.name,
    required this.address,
    required this.protocol,
    required this.latency,
    required this.active,
    required this.onTap,
  });

  final String name;
  final String address;
  final String protocol;
  final LatencyResult? latency;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Semantics(
        selected: active,
        button: true,
        child: Material(
          color: tones.surfaceCard,
          child: InkWell(
            onTap: onTap,
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
                          address,
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
    );
  }
}
