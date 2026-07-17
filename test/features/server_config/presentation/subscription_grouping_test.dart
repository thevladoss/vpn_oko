import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_osin/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription.dart';
import 'package:vpn_osin/features/server_config/presentation/subscription_grouping.dart';

const _config = VlessConfig(
  uuid: 'deadbeef-1111-2222-3333-444455556666',
  host: 'node.example',
  port: 443,
  transport: 'tcp',
  security: 'reality',
  name: 'Node',
);

ServerProfile _server(int id, {int? subscriptionId}) => ServerProfile(
  id: id,
  label: 'Server $id',
  config: _config,
  rawUrl: 'vless://node',
  createdAt: DateTime(2026, 7, 17),
  subscriptionId: subscriptionId,
);

Subscription _sub(int id, {String name = 'Sub'}) => Subscription(
  id: id,
  name: '$name $id',
  url: 'https://example.com/$id',
  updateIntervalHours: 12,
  upload: 0,
  download: 0,
  total: 0,
  expiresAt: null,
  lastUpdatedAt: DateTime(2026, 7, 17),
  createdAt: DateTime(2026, 7, 17),
);

void main() {
  group('groupServersBySubscription', () {
    test('только ручные серверы → одна группа «без подписки» в конце', () {
      final groups = groupServersBySubscription(
        [_server(1), _server(2)],
        const [],
      );

      expect(groups, hasLength(1));
      expect(groups.single.subscription, isNull);
      expect(groups.single.servers.map((s) => s.id), [1, 2]);
    });

    test('серверы подписки идут группой в порядке подписок, ручные — в конце',
        () {
      final subA = _sub(10, name: 'A');
      final subB = _sub(20, name: 'B');
      final groups = groupServersBySubscription(
        [
          _server(1, subscriptionId: 20),
          _server(2),
          _server(3, subscriptionId: 10),
          _server(4, subscriptionId: 20),
        ],
        [subA, subB],
      );

      expect(groups, hasLength(3));
      expect(groups[0].subscription, subA);
      expect(groups[0].servers.map((s) => s.id), [3]);
      expect(groups[1].subscription, subB);
      expect(groups[1].servers.map((s) => s.id), [1, 4]);
      expect(groups[2].subscription, isNull);
      expect(groups[2].servers.map((s) => s.id), [2]);
    });

    test('подписка без серверов даёт группу с пустым списком', () {
      final sub = _sub(10);
      final groups = groupServersBySubscription(const [], [sub]);

      expect(groups, hasLength(1));
      expect(groups.single.subscription, sub);
      expect(groups.single.servers, isEmpty);
    });

    test('сервер с сиротской subscriptionId падает в «без подписки»', () {
      final sub = _sub(10);
      final groups = groupServersBySubscription(
        [_server(1, subscriptionId: 999)],
        [sub],
      );

      expect(groups, hasLength(2));
      expect(groups[0].subscription, sub);
      expect(groups[0].servers, isEmpty);
      expect(groups[1].subscription, isNull);
      expect(groups[1].servers.map((s) => s.id), [1]);
    });

    test('без ручных серверов и сирот группы «без подписки» нет', () {
      final sub = _sub(10);
      final groups = groupServersBySubscription(
        [_server(1, subscriptionId: 10)],
        [sub],
      );

      expect(groups, hasLength(1));
      expect(groups.single.subscription, sub);
      expect(groups.single.servers.map((s) => s.id), [1]);
    });

    test('ServerGroup поддерживает value-равенство', () {
      final sub = _sub(10);
      final a = ServerGroup(subscription: sub, servers: [_server(1)]);
      final b = ServerGroup(subscription: sub, servers: [_server(1)]);

      expect(a, b);
    });
  });
}
