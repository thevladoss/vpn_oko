import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_parse_result.dart';
import 'package:vpn_osin/features/server_config/domain/services/proxy_parser.dart';

const _uuid = 'b831381d-6324-4d53-ad4f-8cda48b30811';

String _b64(String value) => base64.encode(utf8.encode(value));

void main() {
  group('parseProxyUrl — маршрутизация', () {
    test('vless:// → ProxyParsed(VlessConfig)', () {
      final result = parseProxyUrl(
        'vless://$_uuid@example.com:443?type=tcp&security=reality#R',
      );

      expect(result, isA<ProxyParsed>());
      final config = (result as ProxyParsed).config;
      expect(config, isA<VlessConfig>());
      expect((config as VlessConfig).uuid, _uuid);
    });

    test('неподдерживаемая схема http:// → unsupported', () {
      expect(
        parseProxyUrl('http://x'),
        const ProxyParseFailure(ProxyParseError.unsupported),
      );
    });

    test('пустая строка → empty', () {
      expect(
        parseProxyUrl(''),
        const ProxyParseFailure(ProxyParseError.empty),
      );
      expect(
        parseProxyUrl('   '),
        const ProxyParseFailure(ProxyParseError.empty),
      );
    });

    test('строка без схемы %%% → unsupported, без throw', () {
      final result = parseProxyUrl('%%%');
      expect(result, isA<ProxyParseFailure>());
      expect((result as ProxyParseFailure).error, ProxyParseError.unsupported);
    });
  });

  group('parseProxyUrl — vmess', () {
    final json = jsonEncode({
      'v': '2',
      'ps': 'Node',
      'add': '1.2.3.4',
      'port': '443',
      'id': _uuid,
      'aid': '0',
      'net': 'ws',
      'host': 'h',
      'path': '/p',
      'tls': 'tls',
      'sni': 's',
    });

    test('base64-JSON → ProxyParsed(VmessConfig) со всеми полями', () {
      final result = parseProxyUrl('vmess://${_b64(json)}');

      expect(result, isA<ProxyParsed>());
      final config = (result as ProxyParsed).config;
      expect(config, isA<VmessConfig>());
      final vmess = config as VmessConfig;
      expect(vmess.uuid, _uuid);
      expect(vmess.host, '1.2.3.4');
      expect(vmess.port, 443);
      expect(vmess.network, 'ws');
      expect(vmess.tls, isTrue);
      expect(vmess.sni, 's');
      expect(vmess.wsPath, '/p');
      expect(vmess.wsHostHeader, 'h');
      expect(vmess.name, 'Node');
    });

    test('без padding — парсится через base64.normalize', () {
      final noPad = _b64(json).replaceAll('=', '');
      final result = parseProxyUrl('vmess://$noPad');

      expect(result, isA<ProxyParsed>());
      expect((result as ProxyParsed).config, isA<VmessConfig>());
    });

    test('битый base64 vmess://%%% → malformed, без throw', () {
      final result = parseProxyUrl('vmess://%%%');
      expect(result, isA<ProxyParseFailure>());
      expect((result as ProxyParseFailure).error, ProxyParseError.malformed);
    });
  });

  group('parseProxyUrl — trojan', () {
    test('trojan:// с ws-транспортом → TrojanConfig', () {
      final result = parseProxyUrl(
        'trojan://pass@h:443?security=tls&sni=s&type=ws&path=%2Fw&host=cdn#T',
      );

      expect(result, isA<ProxyParsed>());
      final config = (result as ProxyParsed).config as TrojanConfig;
      expect(config.password, 'pass');
      expect(config.sni, 's');
      expect(config.network, 'ws');
      expect(config.wsPath, '/w');
      expect(config.wsHostHeader, 'cdn');
      expect(config.name, 'T');
    });
  });

  group('parseProxyUrl — shadowsocks', () {
    test('SIP002 base64(method:password)@host:port → ShadowsocksConfig', () {
      final userInfo = _b64('aes-256-gcm:pass');
      final result = parseProxyUrl('ss://$userInfo@h:8388#SS');

      expect(result, isA<ProxyParsed>());
      final config = (result as ProxyParsed).config as ShadowsocksConfig;
      expect(config.method, 'aes-256-gcm');
      expect(config.password, 'pass');
      expect(config.host, 'h');
      expect(config.port, 8388);
      expect(config.name, 'SS');
    });

    test('legacy base64(method:password@host:port) → тот же результат', () {
      final body = _b64('aes-256-gcm:pass@h:8388');
      final result = parseProxyUrl('ss://$body#SS');

      expect(result, isA<ProxyParsed>());
      final config = (result as ProxyParsed).config as ShadowsocksConfig;
      expect(config.method, 'aes-256-gcm');
      expect(config.password, 'pass');
      expect(config.host, 'h');
      expect(config.port, 8388);
    });
  });

  group('parseProxyUrl — hysteria2', () {
    test('hysteria2:// с obfs → Hysteria2Config', () {
      final result = parseProxyUrl(
        'hysteria2://pass@h:443'
        '?sni=s&obfs=salamander&obfs-password=op&insecure=1#H2',
      );

      expect(result, isA<ProxyParsed>());
      final config = (result as ProxyParsed).config as Hysteria2Config;
      expect(config.password, 'pass');
      expect(config.sni, 's');
      expect(config.obfs, 'salamander');
      expect(config.obfsPassword, 'op');
      expect(config.allowInsecure, isTrue);
    });

    test('алиас hy2:// → Hysteria2Config', () {
      final result = parseProxyUrl('hy2://pass@h:443#X');

      expect(result, isA<ProxyParsed>());
      final config = (result as ProxyParsed).config as Hysteria2Config;
      expect(config.password, 'pass');
      expect(config.name, 'X');
    });
  });
}
