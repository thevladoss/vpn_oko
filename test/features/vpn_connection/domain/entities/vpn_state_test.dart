import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_state.dart';
import 'package:vpn_oko/features/vpn_logs/domain/entities/log_entry.dart';

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

  group('LogEntry equality', () {
    test('entries with equal fields are equal', () {
      final time = DateTime.utc(2026);
      expect(
        LogEntry(text: 'up', level: LogLevel.info, time: time),
        equals(LogEntry(text: 'up', level: LogLevel.info, time: time)),
      );
    });

    test('entries differ when level differs', () {
      final time = DateTime.utc(2026);
      expect(
        LogEntry(text: 'up', level: LogLevel.info, time: time),
        isNot(equals(LogEntry(text: 'up', level: LogLevel.error, time: time))),
      );
    });

    test('LogLevel resolves by name', () {
      expect(LogLevel.values.byName('warning'), equals(LogLevel.warning));
    });
  });
}
