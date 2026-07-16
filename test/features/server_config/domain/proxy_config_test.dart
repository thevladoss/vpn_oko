import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';

const _uuid = 'b831381d-6324-4d53-ad4f-8cda48b30811';

void main() {
  group('VlessConfig', () {
    test('равные поля — равны', () {
      const a = VlessConfig(
        host: 'example.com',
        port: 443,
        name: 'Tokyo',
        uuid: _uuid,
        transport: 'tcp',
        security: 'reality',
        sni: 'www.microsoft.com',
        flow: 'xtls-rprx-vision',
        publicKey: 'pbk',
        shortId: 'sid',
        fingerprint: 'chrome',
        alpn: ['h2', 'http/1.1'],
        grpcServiceName: 'grpc',
      );
      const b = VlessConfig(
        host: 'example.com',
        port: 443,
        name: 'Tokyo',
        uuid: _uuid,
        transport: 'tcp',
        security: 'reality',
        sni: 'www.microsoft.com',
        flow: 'xtls-rprx-vision',
        publicKey: 'pbk',
        shortId: 'sid',
        fingerprint: 'chrome',
        alpn: ['h2', 'http/1.1'],
        grpcServiceName: 'grpc',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('разный publicKey — не равны', () {
      const a = VlessConfig(
        host: 'example.com',
        port: 443,
        name: 'Tokyo',
        uuid: _uuid,
        transport: 'tcp',
        security: 'reality',
        publicKey: 'pbk-a',
      );
      const b = VlessConfig(
        host: 'example.com',
        port: 443,
        name: 'Tokyo',
        uuid: _uuid,
        transport: 'tcp',
        security: 'reality',
        publicKey: 'pbk-b',
      );

      expect(a, isNot(b));
    });

    test('разный alpn — не равны', () {
      const a = VlessConfig(
        host: 'h',
        port: 443,
        name: 'N',
        uuid: _uuid,
        transport: 'ws',
        security: 'tls',
        alpn: ['h2'],
      );
      const b = VlessConfig(
        host: 'h',
        port: 443,
        name: 'N',
        uuid: _uuid,
        transport: 'ws',
        security: 'tls',
        alpn: ['http/1.1'],
      );

      expect(a, isNot(b));
    });
  });

  group('VmessConfig', () {
    test('равные поля — равны', () {
      const a = VmessConfig(host: 'h', port: 443, name: 'N', uuid: _uuid);
      const b = VmessConfig(host: 'h', port: 443, name: 'N', uuid: _uuid);

      expect(a, b);
    });

    test('разный tls — не равны', () {
      const a = VmessConfig(host: 'h', port: 443, name: 'N', uuid: _uuid);
      const b = VmessConfig(
        host: 'h',
        port: 443,
        name: 'N',
        uuid: _uuid,
        tls: true,
      );

      expect(a, isNot(b));
    });
  });

  group('TrojanConfig', () {
    test('равные поля — равны', () {
      const a = TrojanConfig(host: 'h', port: 443, name: 'N', password: 'p');
      const b = TrojanConfig(host: 'h', port: 443, name: 'N', password: 'p');

      expect(a, b);
    });

    test('разный password — не равны', () {
      const a = TrojanConfig(host: 'h', port: 443, name: 'N', password: 'p1');
      const b = TrojanConfig(host: 'h', port: 443, name: 'N', password: 'p2');

      expect(a, isNot(b));
    });
  });

  group('ShadowsocksConfig', () {
    test('равные поля — равны', () {
      const a = ShadowsocksConfig(
        host: 'h',
        port: 443,
        name: 'N',
        method: 'aes-256-gcm',
        password: 'p',
      );
      const b = ShadowsocksConfig(
        host: 'h',
        port: 443,
        name: 'N',
        method: 'aes-256-gcm',
        password: 'p',
      );

      expect(a, b);
    });

    test('разный method — не равны', () {
      const a = ShadowsocksConfig(
        host: 'h',
        port: 443,
        name: 'N',
        method: 'aes-256-gcm',
        password: 'p',
      );
      const b = ShadowsocksConfig(
        host: 'h',
        port: 443,
        name: 'N',
        method: 'chacha20-ietf-poly1305',
        password: 'p',
      );

      expect(a, isNot(b));
    });
  });

  group('Hysteria2Config', () {
    test('равные поля — равны', () {
      const a = Hysteria2Config(host: 'h', port: 443, name: 'N', password: 'p');
      const b = Hysteria2Config(host: 'h', port: 443, name: 'N', password: 'p');

      expect(a, b);
    });

    test('разный obfsPassword — не равны', () {
      const a = Hysteria2Config(
        host: 'h',
        port: 443,
        name: 'N',
        password: 'p',
        obfs: 'salamander',
        obfsPassword: 'o1',
      );
      const b = Hysteria2Config(
        host: 'h',
        port: 443,
        name: 'N',
        password: 'p',
        obfs: 'salamander',
        obfsPassword: 'o2',
      );

      expect(a, isNot(b));
    });
  });
}
