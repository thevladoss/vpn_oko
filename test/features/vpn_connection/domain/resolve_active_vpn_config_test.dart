import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_osin/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/settings_repository.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/subscription_repository.dart';
import 'package:vpn_osin/features/server_config/domain/services/singbox_config_builder.dart';
import 'package:vpn_osin/features/vpn_connection/data/mappers/proxy_config_mapper.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/resolve_active_vpn_config.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepository {}

VlessConfig _cfg(String host) => VlessConfig(
  host: host,
  port: 443,
  name: host,
  uuid: 'deadbeef-1111-2222-3333-444455556666',
  transport: 'tcp',
  security: 'none',
);

ServerProfile _profile({
  required int id,
  required ProxyConfig config,
  int? subscriptionId,
}) => ServerProfile(
  id: id,
  label: config.name,
  config: config,
  rawUrl: 'vless://x@${config.host}:443',
  createdAt: DateTime(2026, 7, 17),
  subscriptionId: subscriptionId,
);

void main() {
  late MockSettingsRepository settings;
  late MockSubscriptionRepository subscriptions;

  ResolveActiveVpnConfig buildResolve() =>
      ResolveActiveVpnConfig(settings, subscriptions);

  setUp(() {
    settings = MockSettingsRepository();
    subscriptions = MockSubscriptionRepository();
  });

  group('ResolveActiveVpnConfig', () {
    test('active=null → null, репозитории не трогаются', () async {
      final result = await buildResolve().call(null);

      expect(result, isNull);
      verifyNever(() => settings.autoSwitchEnabled());
      verifyNever(() => subscriptions.serversFor(any()));
    });

    test(
      'ON + subscriptionId + ≥2 сервера → групповой конфиг всех серверов',
      () async {
        final tokyo = _profile(
          id: 1,
          config: _cfg('tokyo.example'),
          subscriptionId: 5,
        );
        final osaka = _profile(
          id: 2,
          config: _cfg('osaka.example'),
          subscriptionId: 5,
        );
        when(() => settings.autoSwitchEnabled()).thenAnswer((_) async => true);
        when(
          () => subscriptions.serversFor(5),
        ).thenAnswer((_) async => [tokyo, osaka]);

        final result = await buildResolve().call(tokyo);

        expect(result, isNotNull);
        expect(
          result!.singboxConfigJson,
          toAutoSwitchJson([tokyo.config, osaka.config]),
        );
        expect(result.singboxConfigJson, contains('urltest'));
        expect(result.singboxConfigJson, contains('proxy-0'));
        expect(result.host, 'tokyo.example');
        expect(result.port, 443);
        expect(result.serverName, 'tokyo.example');
        verify(() => subscriptions.serversFor(5)).called(1);
      },
    );

    test('ON + subscriptionId + 1 сервер → одиночный конфиг', () async {
      final tokyo = _profile(
        id: 1,
        config: _cfg('tokyo.example'),
        subscriptionId: 5,
      );
      when(() => settings.autoSwitchEnabled()).thenAnswer((_) async => true);
      when(
        () => subscriptions.serversFor(5),
      ).thenAnswer((_) async => [tokyo]);

      final result = await buildResolve().call(tokyo);

      expect(result, proxyConfigToVpnConfig(tokyo.config));
      expect(result!.singboxConfigJson, isNot(contains('urltest')));
    });

    test('ON + ручной сервер (subscriptionId=null) → одиночный', () async {
      final manual = _profile(id: 9, config: _cfg('manual.example'));
      when(() => settings.autoSwitchEnabled()).thenAnswer((_) async => true);

      final result = await buildResolve().call(manual);

      expect(result, proxyConfigToVpnConfig(manual.config));
      verifyNever(() => subscriptions.serversFor(any()));
    });

    test('OFF + сервер из подписки → одиночный', () async {
      final tokyo = _profile(
        id: 1,
        config: _cfg('tokyo.example'),
        subscriptionId: 5,
      );
      when(() => settings.autoSwitchEnabled()).thenAnswer((_) async => false);

      final result = await buildResolve().call(tokyo);

      expect(result, proxyConfigToVpnConfig(tokyo.config));
      verifyNever(() => subscriptions.serversFor(any()));
    });
  });
}
