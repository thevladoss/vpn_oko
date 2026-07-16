import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_parse_result.dart';
import 'package:vpn_osin/features/server_config/domain/services/proxy_parser.dart';
import 'package:vpn_osin/features/server_config/domain/services/proxy_serializer.dart';
import 'package:vpn_osin/features/server_config/domain/services/subscription_parser.dart';

const _uuid = 'b831381d-6324-4d53-ad4f-8cda48b30811';

ProxyConfig _roundtrip(ProxyConfig config) {
  final url = proxyConfigToUrl(config);
  final parsed = parseProxyUrl(url);
  expect(parsed, isA<ProxyParsed>(), reason: 'не распарсилось: $url');
  return (parsed as ProxyParsed).config;
}

void main() {
  group('proxyConfigToUrl round-trip через parseProxyUrl', () {
    test('vless reality со всеми полями', () {
      const config = VlessConfig(
        host: 'example.com',
        port: 443,
        name: 'Tokyo Node',
        uuid: _uuid,
        transport: 'tcp',
        security: 'reality',
        sni: 'www.microsoft.com',
        flow: 'xtls-rprx-vision',
        publicKey: 'AbCdEf0123',
        shortId: '01ab',
        fingerprint: 'chrome',
        alpn: ['h2', 'http/1.1'],
      );
      expect(_roundtrip(config), config);
    });

    test('vless ws + tls с path и host-заголовком', () {
      const config = VlessConfig(
        host: 'cdn.example',
        port: 8443,
        name: 'WS Edge',
        uuid: _uuid,
        transport: 'ws',
        security: 'tls',
        sni: 'cdn.example',
        wsPath: '/vpn',
        wsHostHeader: 'front.example',
      );
      expect(_roundtrip(config), config);
    });

    test('vless grpc с serviceName', () {
      const config = VlessConfig(
        host: 'g.example',
        port: 2053,
        name: 'gRPC',
        uuid: _uuid,
        transport: 'grpc',
        security: 'tls',
        grpcServiceName: 'GunService',
      );
      expect(_roundtrip(config), config);
    });

    test('vless минимальный (name == host, дефолты)', () {
      const config = VlessConfig(
        host: 'min.example',
        port: 443,
        name: 'min.example',
        uuid: _uuid,
        transport: 'tcp',
        security: 'none',
      );
      expect(_roundtrip(config), config);
    });

    test('vmess ws + tls', () {
      const config = VmessConfig(
        host: 'v.example',
        port: 443,
        name: 'Vmess WS',
        uuid: _uuid,
        network: 'ws',
        tls: true,
        sni: 'v.example',
        alpn: ['h2'],
        wsPath: '/vm',
        wsHostHeader: 'h.example',
      );
      expect(_roundtrip(config), config);
    });

    test('vmess минимальный', () {
      const config = VmessConfig(
        host: 'vm.example',
        port: 80,
        name: 'vm.example',
        uuid: _uuid,
      );
      expect(_roundtrip(config), config);
    });

    test('trojan ws со всеми полями', () {
      const config = TrojanConfig(
        host: 't.example',
        port: 8443,
        name: 'Trojan Osaka',
        password: 'p4ssw0rd',
        network: 'ws',
        sni: 't.example',
        alpn: ['h2'],
        wsPath: '/tj',
        wsHostHeader: 'h.example',
        allowInsecure: true,
      );
      expect(_roundtrip(config), config);
    });

    test('trojan минимальный', () {
      const config = TrojanConfig(
        host: 'tm.example',
        port: 443,
        name: 'tm.example',
        password: 'secret',
      );
      expect(_roundtrip(config), config);
    });

    test('shadowsocks (SIP002 base64 userinfo)', () {
      const config = ShadowsocksConfig(
        host: 's.example',
        port: 8388,
        name: 'SS Node',
        method: 'aes-256-gcm',
        password: 'ssp4ss',
      );
      expect(_roundtrip(config), config);
    });

    test('hysteria2 с obfs и insecure', () {
      const config = Hysteria2Config(
        host: 'hy.example',
        port: 443,
        name: 'Hy Node',
        password: 'hyp4ss',
        sni: 'hy.example',
        obfs: 'salamander',
        obfsPassword: 'obfsp4ss',
        allowInsecure: true,
      );
      expect(_roundtrip(config), config);
    });

    test('hysteria2 минимальный', () {
      const config = Hysteria2Config(
        host: 'hym.example',
        port: 443,
        name: 'hym.example',
        password: 'secret',
      );
      expect(_roundtrip(config), config);
    });
  });

  group('sing-box JSON восстанавливается через канонический URL', () {
    test('vless reality из sing-box → URL → тот же config', () {
      const body =
          '{"outbounds":[{"type":"vless","tag":"SB Tokyo",'
          '"server":"sb.example","server_port":443,"uuid":"$_uuid",'
          '"flow":"xtls-rprx-vision","tls":{"enabled":true,'
          '"server_name":"sb.example","reality":{"enabled":true,'
          '"public_key":"PBKvalue","short_id":"ab12"},'
          '"utls":{"fingerprint":"chrome"}}}]}';
      final import = parseSubscription(body);
      expect(import.servers, hasLength(1));

      final config = import.servers.single.config;
      final parsed = parseProxyUrl(proxyConfigToUrl(config));

      expect(parsed, isA<ProxyParsed>());
      expect((parsed as ProxyParsed).config, config);
    });

    test('shadowsocks из sing-box → URL → тот же config', () {
      const body =
          '{"outbounds":[{"type":"shadowsocks","tag":"SB SS",'
          '"server":"ss.sb","server_port":8388,'
          '"method":"aes-256-gcm","password":"sbpass"}]}';
      final import = parseSubscription(body);
      expect(import.servers, hasLength(1));

      final config = import.servers.single.config;
      final parsed = parseProxyUrl(proxyConfigToUrl(config));

      expect(parsed, isA<ProxyParsed>());
      expect((parsed as ProxyParsed).config, config);
    });
  });
}
