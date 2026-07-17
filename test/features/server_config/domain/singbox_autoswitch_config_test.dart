import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_osin/features/server_config/domain/services/singbox_config_builder.dart';

const _uuid = 'b831381d-6324-4d53-ad4f-8cda48b30811';

const _vless = VlessConfig(
  host: 'vless.example.com',
  port: 443,
  name: 'VLESS',
  uuid: _uuid,
  transport: 'tcp',
  security: 'reality',
  sni: 'www.microsoft.com',
  flow: 'xtls-rprx-vision',
  publicKey: 'pbk-fake',
  shortId: 'sid-fake',
  fingerprint: 'chrome',
);

const _trojan = TrojanConfig(
  host: 'trojan.example.com',
  port: 443,
  name: 'Trojan',
  password: 'trojan-pass',
  sni: 'trojan.example.com',
);

const _shadowsocks = ShadowsocksConfig(
  host: 'ss.example.com',
  port: 8388,
  name: 'SS',
  method: 'aes-256-gcm',
  password: 'ss-pass',
);

List<Map<String, Object?>> _outboundsOf(Map<String, Object?> config) =>
    (config['outbounds']! as List<Object?>).cast<Map<String, Object?>>();

Map<String, Object?> _byTag(Map<String, Object?> config, String tag) =>
    _outboundsOf(config).firstWhere((o) => o['tag'] == tag);

void main() {
  group('buildAutoSwitchConfig — структура группы', () {
    final config = buildAutoSwitchConfig([_vless, _trojan, _shadowsocks]);
    final outbounds = _outboundsOf(config);

    test('N серверных outbound + urltest + direct', () {
      expect(outbounds, hasLength(5));
      final types = outbounds.map((o) => o['type']).toList();
      expect(types.where((t) => t == 'urltest'), hasLength(1));
      expect(types.where((t) => t == 'direct'), hasLength(1));
    });

    test('серверные outbound имеют уникальные теги proxy-0..N-1', () {
      final serverTags = outbounds
          .where((o) => o['type'] != 'urltest' && o['type'] != 'direct')
          .map((o) => o['tag'])
          .toList();
      expect(serverTags, ['proxy-0', 'proxy-1', 'proxy-2']);
    });

    test('серверные outbound сохраняют тип протокола по порядку', () {
      expect(_byTag(config, 'proxy-0')['type'], 'vless');
      expect(_byTag(config, 'proxy-1')['type'], 'trojan');
      expect(_byTag(config, 'proxy-2')['type'], 'shadowsocks');
    });

    test('серверный outbound переносит поля протокола', () {
      final proxy0 = _byTag(config, 'proxy-0');
      expect(proxy0['server'], 'vless.example.com');
      expect(proxy0['uuid'], _uuid);
      expect(proxy0['flow'], 'xtls-rprx-vision');
    });

    test('urltest outbound: тег proxy, поля из locked-decision', () {
      final urltest = _byTag(config, 'proxy');
      expect(urltest['type'], 'urltest');
      expect(urltest['outbounds'], ['proxy-0', 'proxy-1', 'proxy-2']);
      expect(urltest['url'], 'https://www.gstatic.com/generate_204');
      expect(urltest['interval'], '3m');
      expect(urltest['tolerance'], 50);
      expect(urltest['idle_timeout'], '30m');
    });

    test('direct outbound присутствует', () {
      expect(_byTag(config, 'direct')['type'], 'direct');
    });

    test('route.final proxy, dns detour proxy, tun как в одиночном', () {
      final route = config['route']! as Map<String, Object?>;
      expect(route['final'], 'proxy');

      final dns = config['dns']! as Map<String, Object?>;
      final servers = (dns['servers']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(servers.any((s) => s['detour'] == 'proxy'), isTrue);

      final inbounds = (config['inbounds']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final tun = inbounds.firstWhere((i) => i['type'] == 'tun');
      expect(tun['auto_route'], isTrue);
      expect(tun['stack'], 'gvisor');
    });
  });

  group('buildAutoSwitchConfig — edge cases', () {
    test('один сервер: proxy-0 + urltest(outbounds:[proxy-0]) + direct', () {
      final config = buildAutoSwitchConfig([_vless]);
      final outbounds = _outboundsOf(config);

      expect(outbounds, hasLength(3));
      expect(_byTag(config, 'proxy-0')['type'], 'vless');
      final urltest = _byTag(config, 'proxy');
      expect(urltest['type'], 'urltest');
      expect(urltest['outbounds'], ['proxy-0']);
    });

    test('пустой список: urltest с пустыми outbounds + direct', () {
      final config = buildAutoSwitchConfig(const []);
      final outbounds = _outboundsOf(config);

      expect(outbounds, hasLength(2));
      final urltest = _byTag(config, 'proxy');
      expect(urltest['type'], 'urltest');
      expect(urltest['outbounds'], <String>[]);
      expect(_byTag(config, 'direct')['type'], 'direct');
    });
  });

  group('toAutoSwitchJson', () {
    test('round-trip: jsonDecode == buildAutoSwitchConfig', () {
      final servers = [_vless, _trojan, _shadowsocks];
      final json = toAutoSwitchJson(servers);
      final decoded = jsonDecode(json) as Map<String, Object?>;

      expect(decoded, buildAutoSwitchConfig(servers));
    });
  });
}
