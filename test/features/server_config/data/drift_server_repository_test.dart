import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/features/server_config/data/local/app_database.dart';
import 'package:vpn_oko/features/server_config/data/mappers/server_profile_mapper.dart';
import 'package:vpn_oko/features/server_config/domain/entities/proxy_config.dart';

const _vlessUrl =
    'vless://b831381d-6324-4d53-ad4f-8cda48b30811@example.com:443'
    '?type=tcp&security=reality&sni=www.microsoft.com#Tokyo';

const _vlessConfig = VlessConfig(
  uuid: 'b831381d-6324-4d53-ad4f-8cda48b30811',
  host: 'example.com',
  port: 443,
  transport: 'tcp',
  security: 'reality',
  sni: 'www.microsoft.com',
  name: 'Tokyo',
);

void main() {
  group('server_profile_mapper', () {
    test('protocolOf покрывает все пять подтипов', () {
      expect(protocolOf(_vlessConfig), 'vless');
      expect(
        protocolOf(const VmessConfig(host: 'h', port: 1, name: 'n', uuid: 'u')),
        'vmess',
      );
      expect(
        protocolOf(
          const TrojanConfig(host: 'h', port: 1, name: 'n', password: 'p'),
        ),
        'trojan',
      );
      expect(
        protocolOf(
          const ShadowsocksConfig(
            host: 'h',
            port: 1,
            name: 'n',
            method: 'aes-256-gcm',
            password: 'p',
          ),
        ),
        'shadowsocks',
      );
      expect(
        protocolOf(
          const Hysteria2Config(host: 'h', port: 1, name: 'n', password: 'p'),
        ),
        'hysteria2',
      );
    });

    test('rowToProfile восстанавливает config из rawUrl (roundtrip)', () {
      final row = ServerRow(
        id: 7,
        label: 'Tokyo',
        rawUrl: _vlessUrl,
        protocol: 'vless',
        host: 'example.com',
        port: 443,
        createdAt: DateTime(2026, 7, 14),
      );

      final profile = rowToProfile(row);

      expect(profile.id, 7);
      expect(profile.label, 'Tokyo');
      expect(profile.rawUrl, _vlessUrl);
      expect(profile.config, _vlessConfig);
    });
  });
}
