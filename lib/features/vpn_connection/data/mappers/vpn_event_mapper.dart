import 'package:vpn_osin/core/bridge/vpn_api.g.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/demo_limit.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/vpn_state.dart';

VpnState _statusToState(VpnStatusMessage status, int? connectedSinceEpochMs) =>
    switch (status) {
      VpnStatusMessage.disconnected => const VpnDisconnected(),
      VpnStatusMessage.connecting => const VpnConnecting(),
      VpnStatusMessage.connected => VpnConnected(
          connectedSince: connectedSinceEpochMs == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(connectedSinceEpochMs),
        ),
      VpnStatusMessage.disconnecting => const VpnDisconnecting(),
      VpnStatusMessage.error => const VpnError('unknown'),
    };

VpnState statusToEntity(StatusChangedMessage m) =>
    _statusToState(m.status, m.connectedSinceEpochMs);

VpnState snapshotToEntity(VpnStatusSnapshotMessage m) {
  final base = _statusToState(m.status, m.connectedSinceEpochMs);
  if (base is VpnConnected) {
    return VpnConnected(
      connectedSince: base.connectedSince,
      sessionEndsAt: _snapshotSessionEndsAt(m, base.connectedSince),
    );
  }
  return base;
}

DateTime? _snapshotSessionEndsAt(
  VpnStatusSnapshotMessage m,
  DateTime? connectedSince,
) {
  final endsAt = m.sessionEndsAtEpochMs;
  if (endsAt != null) {
    return DateTime.fromMillisecondsSinceEpoch(endsAt);
  }
  return connectedSince?.add(kDemoSessionDuration);
}

DemoExpiry demoToEntity(DemoExpiredMessage m) => DemoExpiry(
      cooldownUntil:
          DateTime.fromMillisecondsSinceEpoch(m.cooldownUntilEpochMs),
      justExpired: true,
    );

DemoExpiry? snapshotToDemo(VpnStatusSnapshotMessage m) {
  final cooldown = m.cooldownUntilEpochMs;
  if (cooldown == null) {
    return null;
  }
  return DemoExpiry(
    cooldownUntil: DateTime.fromMillisecondsSinceEpoch(cooldown),
    justExpired: false,
  );
}

VpnState errorToEntity(ErrorMessage m) => VpnError(m.message);

TrafficStats trafficToEntity(TrafficChangedMessage m) =>
    TrafficStats(rxBytes: m.rxBytes, txBytes: m.txBytes);
