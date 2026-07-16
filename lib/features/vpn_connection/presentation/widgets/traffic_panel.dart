import 'package:flutter/material.dart';
import 'package:vpn_osin/core/theme/vpn_status.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/traffic_tile.dart';

class TrafficPanel extends StatelessWidget {
  const TrafficPanel({
    required this.rxBytes,
    required this.txBytes,
    required this.status,
    super.key,
  });

  final int rxBytes;
  final int txBytes;
  final VpnStatus status;

  @override
  Widget build(BuildContext context) {
    final active = status == VpnStatus.connected;
    return Row(
      children: [
        Expanded(
          child: TrafficTile(
            direction: TrafficDirection.down,
            bytes: rxBytes,
            active: active,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TrafficTile(
            direction: TrafficDirection.up,
            bytes: txBytes,
            active: active,
          ),
        ),
      ],
    );
  }
}
