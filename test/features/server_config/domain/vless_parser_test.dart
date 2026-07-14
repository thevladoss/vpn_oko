import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/features/server_config/domain/entities/vless_parse_result.dart';
import 'package:vpn_oko/features/server_config/domain/services/vless_parser.dart';

const _uuid = 'b831381d-6324-4d53-ad4f-8cda48b30811';

void main() {
  group('parseVless', () {
    test('reality/tcp — все поля', () {
      final result = parseVless(
        'vless://$_uuid@example.com:443'
        '?type=tcp&security=reality&sni=www.microsoft.com'
        '&pbk=k&fp=chrome#Tokyo',
      );

      expect(result, isA<VlessParsed>());
      final config = (result as VlessParsed).config;
      expect(config.uuid, _uuid);
      expect(config.host, 'example.com');
      expect(config.port, 443);
      expect(config.transport, 'tcp');
      expect(config.security, 'reality');
      expect(config.sni, 'www.microsoft.com');
      expect(config.name, 'Tokyo');
    });

    test('ws/tls и grpc — разные type/security', () {
      final ws = parseVless('vless://$_uuid@h:443?type=ws&security=tls#N');
      expect(ws, isA<VlessParsed>());
      final wsConfig = (ws as VlessParsed).config;
      expect(wsConfig.transport, 'ws');
      expect(wsConfig.security, 'tls');

      final grpc = parseVless('vless://$_uuid@h:443?type=grpc#N');
      expect((grpc as VlessParsed).config.transport, 'grpc');
    });

    test('percent-encoded имя декодируется (пробел и эмодзи)', () {
      final spaced = parseVless('vless://$_uuid@h:443#My%20Server') as VlessParsed;
      expect(spaced.config.name, 'My Server');

      final emoji = parseVless(
        'vless://$_uuid@h:443#Tokyo%20%F0%9F%87%AF%F0%9F%87%B5',
      ) as VlessParsed;
      expect(emoji.config.name, 'Tokyo 🇯🇵');
    });

    test('битый percent-encoded фрагмент — failure(malformed), не бросает', () {
      expect(
        parseVless('vless://$_uuid@h:443#%D0'),
        const VlessParseFailure(VlessError.malformed),
      );
      expect(
        parseVless('vless://$_uuid@h:443#%FF'),
        const VlessParseFailure(VlessError.malformed),
      );
    });

    test('битый percent-encoded query — failure(malformed), не бросает', () {
      expect(
        parseVless('vless://$_uuid@h:443?sni=%D0#N'),
        const VlessParseFailure(VlessError.malformed),
      );
    });

    test('IPv6-хост без скобок', () {
      final result = parseVless(
        'vless://$_uuid@[2606:4700:4700::1111]:8443?type=tcp',
      );

      expect(result, isA<VlessParsed>());
      final config = (result as VlessParsed).config;
      expect(config.host, '2606:4700:4700::1111');
      expect(config.port, 8443);
    });

    test('порт вне диапазона 1..65535 — failure(port)', () {
      expect(
        parseVless('vless://$_uuid@h:70000'),
        const VlessParseFailure(VlessError.port),
      );
    });

    test('нечисловой порт — failure(malformed)', () {
      expect(
        parseVless('vless://$_uuid@h:abc'),
        const VlessParseFailure(VlessError.malformed),
      );
    });

    test('пустой и битый uuid — failure(uuid)', () {
      expect(
        parseVless('vless://@h:443'),
        const VlessParseFailure(VlessError.uuid),
      );
      expect(
        parseVless('vless://not-a-uuid@h:443'),
        const VlessParseFailure(VlessError.uuid),
      );
    });

    test('пустой host — failure(host)', () {
      expect(
        parseVless('vless://$_uuid@:443'),
        const VlessParseFailure(VlessError.host),
      );
    });

    test('чужая схема и пустая строка — failure(scheme)', () {
      expect(
        parseVless('https://x'),
        const VlessParseFailure(VlessError.scheme),
      );
      expect(parseVless(''), const VlessParseFailure(VlessError.scheme));
    });

    test('ведущие/хвостовые пробелы из буфера — trim + parse', () {
      final result = parseVless('  vless://$_uuid@h:443#N\n  ');

      expect(result, isA<VlessParsed>());
      final config = (result as VlessParsed).config;
      expect(config.host, 'h');
      expect(config.port, 443);
      expect(config.name, 'N');
    });

    test('отсутствующие параметры — дефолты tcp/none, sni=null, name=host', () {
      final result = parseVless('vless://$_uuid@h:443');

      expect(result, isA<VlessParsed>());
      final config = (result as VlessParsed).config;
      expect(config.transport, 'tcp');
      expect(config.security, 'none');
      expect(config.sni, isNull);
      expect(config.name, 'h');
    });
  });
}
