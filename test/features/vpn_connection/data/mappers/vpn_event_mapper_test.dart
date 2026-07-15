import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/core/bridge/vpn_api.g.dart';
import 'package:vpn_oko/features/vpn_connection/data/mappers/vpn_event_mapper.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/demo_limit.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/traffic_stats.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_state.dart';

void main() {
  group('statusToEntity', () {
    test('disconnected maps to VpnDisconnected', () {
      final result = statusToEntity(
        StatusChangedMessage(status: VpnStatusMessage.disconnected),
      );
      expect(result, const VpnDisconnected());
    });

    test('connecting maps to VpnConnecting', () {
      final result = statusToEntity(
        StatusChangedMessage(status: VpnStatusMessage.connecting),
      );
      expect(result, const VpnConnecting());
    });

    test('connected maps to VpnConnected with epoch timestamp', () {
      final result = statusToEntity(
        StatusChangedMessage(
          status: VpnStatusMessage.connected,
          connectedSinceEpochMs: 1000,
        ),
      );
      expect(
        result,
        VpnConnected(
          connectedSince: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
      );
    });

    test('connected with null epoch yields null connectedSince', () {
      final result = statusToEntity(
        StatusChangedMessage(status: VpnStatusMessage.connected),
      );
      expect(result, const VpnConnected());
    });

    test('disconnecting maps to VpnDisconnecting', () {
      final result = statusToEntity(
        StatusChangedMessage(status: VpnStatusMessage.disconnecting),
      );
      expect(result, const VpnDisconnecting());
    });

    test('error maps to VpnError', () {
      final result = statusToEntity(
        StatusChangedMessage(status: VpnStatusMessage.error),
      );
      expect(result, isA<VpnError>());
    });
  });

  group('errorToEntity', () {
    test('carries the real message from ErrorMessage', () {
      final result = errorToEntity(
        ErrorMessage(code: 'consent_denied', message: 'User denied consent'),
      );

      expect(result, const VpnError('User denied consent'));
    });
  });

  group('trafficToEntity', () {
    test('maps rx and tx bytes', () {
      final result =
          trafficToEntity(TrafficChangedMessage(rxBytes: 5, txBytes: 7));
      expect(result, const TrafficStats(rxBytes: 5, txBytes: 7));
    });
  });

  group('demoToEntity', () {
    test('maps cooldownUntilEpochMs to DateTime with justExpired true', () {
      final result = demoToEntity(
        DemoExpiredMessage(cooldownUntilEpochMs: 5000),
      );

      expect(
        result,
        DemoExpiry(
          cooldownUntil: DateTime.fromMillisecondsSinceEpoch(5000),
          justExpired: true,
        ),
      );
    });
  });

  group('snapshotToDemo', () {
    test('cooldownUntilEpochMs present yields DemoExpiry justExpired false', () {
      final result = snapshotToDemo(
        VpnStatusSnapshotMessage(
          status: VpnStatusMessage.disconnected,
          rxBytes: 0,
          txBytes: 0,
          cooldownUntilEpochMs: 9000,
        ),
      );

      expect(
        result,
        DemoExpiry(
          cooldownUntil: DateTime.fromMillisecondsSinceEpoch(9000),
          justExpired: false,
        ),
      );
    });

    test('null cooldownUntilEpochMs yields null', () {
      final result = snapshotToDemo(
        VpnStatusSnapshotMessage(
          status: VpnStatusMessage.disconnected,
          rxBytes: 0,
          txBytes: 0,
        ),
      );

      expect(result, isNull);
    });
  });

  group('snapshotToEntity sessionEndsAt', () {
    test('connected takes sessionEndsAt from sessionEndsAtEpochMs', () {
      final result = snapshotToEntity(
        VpnStatusSnapshotMessage(
          status: VpnStatusMessage.connected,
          connectedSinceEpochMs: 1000,
          rxBytes: 0,
          txBytes: 0,
          sessionEndsAtEpochMs: 400000,
        ),
      );

      expect(
        result,
        VpnConnected(
          connectedSince: DateTime.fromMillisecondsSinceEpoch(1000),
          sessionEndsAt: DateTime.fromMillisecondsSinceEpoch(400000),
        ),
      );
    });

    test('connected derives sessionEndsAt from connectedSince', () {
      final connectedSince = DateTime.fromMillisecondsSinceEpoch(1000);
      final result = snapshotToEntity(
        VpnStatusSnapshotMessage(
          status: VpnStatusMessage.connected,
          connectedSinceEpochMs: 1000,
          rxBytes: 0,
          txBytes: 0,
        ),
      );

      expect(
        result,
        VpnConnected(
          connectedSince: connectedSince,
          sessionEndsAt: connectedSince.add(kDemoSessionDuration),
        ),
      );
    });

    test('disconnected snapshot stays without sessionEndsAt', () {
      final result = snapshotToEntity(
        VpnStatusSnapshotMessage(
          status: VpnStatusMessage.disconnected,
          rxBytes: 0,
          txBytes: 0,
        ),
      );

      expect(result, const VpnDisconnected());
    });
  });
}
