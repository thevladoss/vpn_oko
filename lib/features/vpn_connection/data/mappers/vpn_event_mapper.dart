import 'package:vpn_oko/core/bridge/vpn_api.g.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_state.dart';

VpnState statusToEntity(StatusChangedMessage m) => switch (m.status) {
      VpnStatusMessage.disconnected => const VpnDisconnected(),
      VpnStatusMessage.connecting => const VpnConnecting(),
      VpnStatusMessage.connected => VpnConnected(
          connectedSince: DateTime.fromMillisecondsSinceEpoch(
            m.connectedSinceEpochMs ?? 0,
          ),
        ),
      VpnStatusMessage.disconnecting => const VpnDisconnecting(),
      VpnStatusMessage.error => const VpnError('unknown'),
    };

TrafficStats trafficToEntity(TrafficChangedMessage m) =>
    TrafficStats(rxBytes: m.rxBytes, txBytes: m.txBytes);
