import 'package:vpn_oko/core/bridge/vpn_api.g.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_state.dart';

VpnState _statusToState(VpnStatusMessage status, int? connectedSinceEpochMs) =>
    switch (status) {
      VpnStatusMessage.disconnected => const VpnDisconnected(),
      VpnStatusMessage.connecting => const VpnConnecting(),
      VpnStatusMessage.connected => VpnConnected(
          connectedSince: DateTime.fromMillisecondsSinceEpoch(
            connectedSinceEpochMs ?? 0,
          ),
        ),
      VpnStatusMessage.disconnecting => const VpnDisconnecting(),
      VpnStatusMessage.error => const VpnError('unknown'),
    };

VpnState statusToEntity(StatusChangedMessage m) =>
    _statusToState(m.status, m.connectedSinceEpochMs);

VpnState snapshotToEntity(VpnStatusSnapshotMessage m) =>
    _statusToState(m.status, m.connectedSinceEpochMs);

TrafficStats trafficToEntity(TrafficChangedMessage m) =>
    TrafficStats(rxBytes: m.rxBytes, txBytes: m.txBytes);
