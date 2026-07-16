import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/bridge/vpn_api.g.dart';
import 'package:vpn_osin/features/vpn_logs/data/mappers/log_mapper.dart';
import 'package:vpn_osin/features/vpn_logs/domain/entities/log_entry.dart';

LogMessage _log(String level) =>
    LogMessage(text: 'body', timestampMillis: 1234, level: level);

void main() {
  group('logToEntity', () {
    test('lowercase levels map to matching LogLevel', () {
      expect(logToEntity(_log('info')).level, LogLevel.info);
      expect(logToEntity(_log('warning')).level, LogLevel.warning);
      expect(logToEntity(_log('error')).level, LogLevel.error);
    });

    test('preserves text and timestamp', () {
      final result = logToEntity(_log('info'));
      expect(result.text, 'body');
      expect(result.time, DateTime.fromMillisecondsSinceEpoch(1234));
    });

    test('is case-insensitive for level names', () {
      expect(logToEntity(_log('INFO')).level, LogLevel.info);
      expect(logToEntity(_log('Info')).level, LogLevel.info);
      expect(logToEntity(_log('WARNING')).level, LogLevel.warning);
    });

    test('unknown level falls back to info without ArgumentError', () {
      expect(logToEntity(_log('debug')).level, LogLevel.info);
      expect(logToEntity(_log('')).level, LogLevel.info);
      expect(() => logToEntity(_log('debug')), returnsNormally);
    });
  });
}
