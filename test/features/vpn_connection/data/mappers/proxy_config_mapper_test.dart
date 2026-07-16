import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_osin/features/vpn_connection/data/mappers/proxy_config_mapper.dart';

void main() {
  const proxy = VlessConfig(
    host: 'real.server',
    port: 8443,
    name: 'Tokyo',
    uuid: 'b831381d-6324-4d53-ad4f-8cda48b30811',
    transport: 'tcp',
    security: 'reality',
    sni: 'www.microsoft.com',
    publicKey: 'pub-key',
    shortId: 'sid',
  );

  test('переносит host/port/name и очищает userId', () {
    final result = proxyConfigToVpnConfig(proxy);

    expect(result.host, 'real.server');
    expect(result.port, 8443);
    expect(result.serverName, 'Tokyo');
    expect(result.userId, '');
  });

  test(
    'заполняет singboxConfigJson готовым конфигом ядра из toSingboxJson',
    () {
      final result = proxyConfigToVpnConfig(proxy);

      expect(result.singboxConfigJson, isNotEmpty);

      final decoded =
          jsonDecode(result.singboxConfigJson) as Map<String, Object?>;
      final outbounds = decoded['outbounds']! as List<Object?>;
      final proxyOutbound = outbounds.first! as Map<String, Object?>;

      expect(proxyOutbound['type'], 'vless');
      expect(proxyOutbound['server'], 'real.server');
      expect(proxyOutbound['uuid'], 'b831381d-6324-4d53-ad4f-8cda48b30811');
    },
  );
}
