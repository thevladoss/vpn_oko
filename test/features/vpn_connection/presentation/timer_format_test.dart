import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/formatters/duration_format.dart';

void main() {
  group('hhmmss', () {
    test('renders mm:ss below one hour', () {
      expect(hhmmss(Duration.zero), '00:00');
      expect(hhmmss(const Duration(seconds: 5)), '00:05');
      expect(hhmmss(const Duration(seconds: 59)), '00:59');
      expect(hhmmss(const Duration(seconds: 60)), '01:00');
      expect(hhmmss(const Duration(seconds: 3599)), '59:59');
    });

    test('switches to hh:mm:ss starting at one hour', () {
      expect(hhmmss(const Duration(seconds: 3600)), '01:00:00');
      expect(
        hhmmss(const Duration(hours: 1, minutes: 1, seconds: 1)),
        '01:01:01',
      );
      expect(
        hhmmss(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03',
      );
    });

    test('carries minute overflow into hours', () {
      expect(hhmmss(const Duration(minutes: 75)), '01:15:00');
    });

    test('does not truncate hours above two digits', () {
      expect(hhmmss(const Duration(hours: 100)), '100:00:00');
    });

    test('clamps negative durations to zero', () {
      expect(hhmmss(const Duration(seconds: -1)), '00:00');
      expect(
        hhmmss(const Duration(hours: -2, minutes: -3, seconds: -4)),
        '00:00',
      );
    });
  });
}
