import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/features/vpn_connection/domain/entities/vpn_state.dart';

void main() {
  group('VpnState equality', () {
    test('VpnDisconnected instances are equal by value', () {
      expect(const VpnDisconnected(), equals(const VpnDisconnected()));
    });

    test('VpnConnecting instances are equal by value', () {
      expect(const VpnConnecting(), equals(const VpnConnecting()));
    });

    test('VpnDisconnecting instances are equal by value', () {
      expect(const VpnDisconnecting(), equals(const VpnDisconnecting()));
    });

    test('VpnConnected is equal when connectedSince matches', () {
      final since = DateTime.utc(2026);
      expect(
        VpnConnected(connectedSince: since),
        equals(VpnConnected(connectedSince: since)),
      );
    });

    test('VpnConnected differs when connectedSince differs', () {
      expect(
        VpnConnected(connectedSince: DateTime.utc(2026)),
        isNot(equals(VpnConnected(connectedSince: DateTime.utc(2027)))),
      );
    });

    test('VpnError is equal for the same message', () {
      expect(const VpnError('a'), equals(const VpnError('a')));
    });

    test('VpnError differs for different messages', () {
      expect(const VpnError('a'), isNot(equals(const VpnError('b'))));
    });

    test('different subtypes are not equal', () {
      expect(const VpnConnecting(), isNot(equals(const VpnDisconnecting())));
    });
  });
}
