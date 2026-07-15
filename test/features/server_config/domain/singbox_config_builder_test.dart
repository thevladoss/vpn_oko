import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_oko/features/server_config/domain/services/singbox_config_builder.dart';

const _uuid = 'b831381d-6324-4d53-ad4f-8cda48b30811';

const _vlessReality = VlessConfig(
  host: 'reality.example.com',
  port: 443,
  name: 'Reality',
  uuid: _uuid,
  transport: 'tcp',
  security: 'reality',
  sni: 'www.microsoft.com',
  flow: 'xtls-rprx-vision',
  publicKey: 'pbk-fake',
  shortId: 'sid-fake',
  fingerprint: 'chrome',
);

const _vlessWs = VlessConfig(
  host: 'ws.example.com',
  port: 443,
  name: 'WS',
  uuid: _uuid,
  transport: 'ws',
  security: 'tls',
  sni: 'ws.example.com',
  wsPath: '/vless',
  wsHostHeader: 'cdn.example.com',
);

const _vlessGrpc = VlessConfig(
  host: 'grpc.example.com',
  port: 443,
  name: 'GRPC',
  uuid: _uuid,
  transport: 'grpc',
  security: 'tls',
  sni: 'grpc.example.com',
  grpcServiceName: 'GunService',
);

const _vmess = VmessConfig(
  host: 'vmess.example.com',
  port: 443,
  name: 'VMess',
  uuid: _uuid,
  network: 'ws',
  tls: true,
  wsPath: '/vmess',
);

const _trojan = TrojanConfig(
  host: 'trojan.example.com',
  port: 443,
  name: 'Trojan',
  password: 'trojan-pass',
  sni: 'trojan.example.com',
  allowInsecure: true,
);

const _shadowsocks = ShadowsocksConfig(
  host: 'ss.example.com',
  port: 8388,
  name: 'SS',
  method: 'aes-256-gcm',
  password: 'ss-pass',
);

const _hysteria2 = Hysteria2Config(
  host: 'hy2.example.com',
  port: 443,
  name: 'HY2',
  password: 'hy2-pass',
  sni: 'hy2.example.com',
  obfs: 'salamander',
  obfsPassword: 'obfs-pass',
  allowInsecure: true,
);

Map<String, Object?> _proxyOf(ProxyConfig config) {
  final map = buildSingboxConfig(config);
  final outbounds = (map['outbounds']! as List<Object?>)
      .cast<Map<String, Object?>>();
  return outbounds.firstWhere((o) => o['tag'] == 'proxy');
}

Map<String, Object?> _tlsOf(ProxyConfig config) =>
    _proxyOf(config)['tls']! as Map<String, Object?>;

Map<String, Object?> _transportOf(ProxyConfig config) =>
    _proxyOf(config)['transport']! as Map<String, Object?>;

void main() {
  group('каркас конфига', () {
    final map = buildSingboxConfig(_vlessReality);

    test('tun-inbound с auto_route/gvisor/mtu 1500 и адрес-списком', () {
      final inbounds = (map['inbounds']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final tun = inbounds.firstWhere((i) => i['type'] == 'tun');

      expect(tun['auto_route'], isTrue);
      expect(tun['stack'], 'gvisor');
      expect(tun['mtu'], 1500);
      expect(tun['strict_route'], isFalse);
      final addresses = (tun['address']! as List<Object?>).cast<String>();
      expect(addresses, hasLength(2));
      expect(addresses.every((a) => a.isNotEmpty), isTrue);
    });

    test('route.final == proxy и auto_detect_interface', () {
      final route = map['route']! as Map<String, Object?>;

      expect(route['final'], 'proxy');
      expect(route['auto_detect_interface'], isTrue);
    });

    test('нет legacy dns-outbound; DNS-хайджек через route action', () {
      final outbounds = (map['outbounds']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(outbounds.any((o) => o['type'] == 'dns'), isFalse);

      final rules = ((map['route']! as Map<String, Object?>)['rules']!
              as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(rules.any((r) => r['action'] == 'hijack-dns'), isTrue);
    });

    test('DNS anti-leak: сервер с detour proxy присутствует', () {
      final dns = map['dns']! as Map<String, Object?>;
      final servers = (dns['servers']! as List<Object?>)
          .cast<Map<String, Object?>>();

      expect(servers.any((s) => s['detour'] == 'proxy'), isTrue);
    });

    test('proxy-outbound присутствует', () {
      final outbounds = (map['outbounds']! as List<Object?>)
          .cast<Map<String, Object?>>();

      expect(outbounds.any((o) => o['tag'] == 'proxy'), isTrue);
    });
  });

  group('VLESS Reality (tcp)', () {
    final proxy = _proxyOf(_vlessReality);
    final tls = _tlsOf(_vlessReality);

    test('поля outbound', () {
      expect(proxy['type'], 'vless');
      expect(proxy['server'], _vlessReality.host);
      expect(proxy['server_port'], _vlessReality.port);
      expect(proxy['uuid'], _uuid);
      expect(proxy['flow'], 'xtls-rprx-vision');
      expect(proxy.containsKey('transport'), isFalse);
    });

    test('tls + utls + reality', () {
      expect(tls['enabled'], isTrue);
      expect(tls['server_name'], 'www.microsoft.com');

      final utls = tls['utls']! as Map<String, Object?>;
      expect(utls['fingerprint'], 'chrome');

      final reality = tls['reality']! as Map<String, Object?>;
      expect(reality['enabled'], isTrue);
      expect(reality['public_key'], 'pbk-fake');
      expect(reality['short_id'], 'sid-fake');
    });
  });

  group('VLESS транспорты', () {
    test('ws: path + Host-заголовок', () {
      final transport = _transportOf(_vlessWs);

      expect(transport['type'], 'ws');
      expect(transport['path'], '/vless');
      final headers = transport['headers']! as Map<String, Object?>;
      expect(headers['Host'], 'cdn.example.com');
    });

    test('grpc: service_name', () {
      final transport = _transportOf(_vlessGrpc);

      expect(transport['type'], 'grpc');
      expect(transport['service_name'], 'GunService');
    });
  });

  group('прочие протоколы', () {
    test('VMess ws+tls', () {
      final proxy = _proxyOf(_vmess);

      expect(proxy['type'], 'vmess');
      expect(proxy['uuid'], _uuid);
      expect(proxy['alter_id'], 0);
      expect(proxy['security'], 'auto');
      expect(_tlsOf(_vmess)['enabled'], isTrue);
      expect(_transportOf(_vmess)['type'], 'ws');
    });

    test('Trojan tls.insecure == allowInsecure', () {
      final proxy = _proxyOf(_trojan);
      final tls = _tlsOf(_trojan);

      expect(proxy['type'], 'trojan');
      expect(proxy['password'], 'trojan-pass');
      expect(tls['enabled'], isTrue);
      expect(tls['insecure'], isTrue);
    });

    test('Shadowsocks без tls', () {
      final proxy = _proxyOf(_shadowsocks);

      expect(proxy['type'], 'shadowsocks');
      expect(proxy['method'], 'aes-256-gcm');
      expect(proxy['password'], 'ss-pass');
      expect(proxy.containsKey('tls'), isFalse);
    });

    test('Hysteria2 obfs + tls.insecure', () {
      final proxy = _proxyOf(_hysteria2);
      final tls = _tlsOf(_hysteria2);
      final obfs = proxy['obfs']! as Map<String, Object?>;

      expect(proxy['type'], 'hysteria2');
      expect(proxy['password'], 'hy2-pass');
      expect(obfs['type'], 'salamander');
      expect(obfs['password'], 'obfs-pass');
      expect(tls['server_name'], 'hy2.example.com');
      expect(tls['insecure'], isTrue);
    });
  });

  group('toSingboxJson', () {
    test('round-trip: jsonDecode == buildSingboxConfig', () {
      for (final config in <ProxyConfig>[
        _vlessReality,
        _vlessWs,
        _vlessGrpc,
        _vmess,
        _trojan,
        _shadowsocks,
        _hysteria2,
      ]) {
        final json = toSingboxJson(config);
        final decoded = jsonDecode(json) as Map<String, Object?>;

        expect(decoded, buildSingboxConfig(config));
      }
    });
  });
}
