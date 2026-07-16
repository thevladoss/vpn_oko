import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/features/server_config/domain/entities/add_server_outcome.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_osin/features/server_config/domain/entities/server_profile.dart';

void main() {
  const config = VlessConfig(
    host: 'example.com',
    port: 443,
    name: 'test',
    uuid: '00000000-0000-0000-0000-000000000000',
    transport: 'tcp',
    security: 'reality',
  );

  final createdAt = DateTime.utc(2026);

  ServerProfile profile({
    int id = 1,
    String label = 'Server',
    String rawUrl = 'vless://fake',
  }) => ServerProfile(
    id: id,
    label: label,
    config: config,
    rawUrl: rawUrl,
    createdAt: createdAt,
  );

  group('ServerProfile', () {
    test('равны при равных полях', () {
      expect(profile(), profile());
    });

    test('не равны при разном label', () {
      expect(profile(label: 'A'), isNot(profile(label: 'B')));
    });

    test('не равны при разном rawUrl', () {
      expect(profile(rawUrl: 'vless://a'), isNot(profile(rawUrl: 'vless://b')));
    });
  });

  group('AddServerOutcome', () {
    test('ServerSaved равны при равном profile', () {
      expect(ServerSaved(profile()), ServerSaved(profile()));
    });

    test('ServerSaved != ServerDuplicate при равном profile', () {
      expect(ServerSaved(profile()), isNot(ServerDuplicate(profile())));
    });

    test('ServerDuplicate равны при равном existing', () {
      expect(ServerDuplicate(profile()), ServerDuplicate(profile()));
    });
  });
}
