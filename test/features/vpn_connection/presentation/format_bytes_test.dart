import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/formatters/byte_format.dart';

void main() {
  group('formatBytes', () {
    test('returns whole bytes below 1024', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(812), '812 B');
      expect(formatBytes(1023), '1023 B');
    });

    test('switches to KB at the 1024 boundary with one decimal', () {
      expect(formatBytes(1024), '1.0 KB');
      expect(formatBytes(1536), '1.5 KB');
    });

    test('switches to MB at the 1024*1024 boundary', () {
      expect(formatBytes(1048576), '1.0 MB');
      expect(formatBytes(12400000), '11.8 MB');
    });

    test('switches to GB at the 1024^3 boundary', () {
      expect(formatBytes(1073741824), '1.0 GB');
    });
  });

  group('formatBytesParts', () {
    test('splits value and unit without brittle string parsing', () {
      expect(formatBytesParts(0), ('0', 'B'));
      expect(formatBytesParts(1023), ('1023', 'B'));
      expect(formatBytesParts(1024), ('1.0', 'KB'));
      expect(formatBytesParts(1536), ('1.5', 'KB'));
      expect(formatBytesParts(1048576), ('1.0', 'MB'));
      expect(formatBytesParts(1073741824), ('1.0', 'GB'));
    });

    test('formatBytes composes the same parts', () {
      final (value, unit) = formatBytesParts(1536);
      expect(formatBytes(1536), '$value $unit');
    });
  });
}
