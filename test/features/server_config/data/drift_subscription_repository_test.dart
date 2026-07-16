import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/features/server_config/data/local/app_database.dart';
import 'package:vpn_osin/features/server_config/data/repositories/drift_server_repository.dart';
import 'package:vpn_osin/features/server_config/data/repositories/drift_subscription_repository.dart';
import 'package:vpn_osin/features/server_config/domain/entities/add_server_outcome.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription_import.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription_userinfo.dart';

const _uuid = 'b831381d-6324-4d53-ad4f-8cda48b30811';

Subscription _draft() => Subscription(
  id: 0,
  name: 'My Sub',
  url: 'https://panel.example/sub',
  updateIntervalHours: 12,
  upload: 0,
  download: 0,
  total: 0,
  expiresAt: null,
  lastUpdatedAt: null,
  createdAt: DateTime(2026, 7, 16),
);

ImportedProxy _proxy(String host) => ImportedProxy(
  config: VlessConfig(
    host: host,
    port: 443,
    name: host,
    uuid: _uuid,
    transport: 'tcp',
    security: 'none',
  ),
  rawUrl: 'vless://ignored-by-repo',
);

Future<int?> _activeId(AppDatabase db) async {
  final row = await (db.select(
    db.appSettings,
  )..where((t) => t.id.equals(0))).getSingleOrNull();
  return row?.activeServerId;
}

void main() {
  late AppDatabase db;
  late DriftSubscriptionRepository repo;
  late DriftServerRepository serverRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftSubscriptionRepository(db);
    serverRepo = DriftServerRepository(db);
  });

  tearDown(() => db.close());

  group('DriftSubscriptionRepository add/watchAll/serversFor', () {
    test('add вставляет подписку и её серверы под subscriptionId', () async {
      final saved = await repo.add(_draft(), [_proxy('a'), _proxy('b')]);

      expect(saved.id, greaterThan(0));
      expect(saved.name, 'My Sub');

      final all = await repo.watchAll().first;
      expect(all, hasLength(1));
      expect(all.single.id, saved.id);

      final servers = await repo.serversFor(saved.id);
      expect(servers, hasLength(2));
      expect(servers.every((s) => s.subscriptionId == saved.id), isTrue);
    });

    test('add дедуплицирует одинаковые серверы', () async {
      final saved = await repo.add(_draft(), [_proxy('a'), _proxy('a')]);

      final servers = await repo.serversFor(saved.id);
      expect(servers, hasLength(1));
    });

    test('watchAll реактивно эмитит после add', () async {
      final expectation = expectLater(
        repo.watchAll(),
        emitsInOrder(<Matcher>[isEmpty, hasLength(1)]),
      );

      await pumpEventQueue();
      await repo.add(_draft(), [_proxy('a')]);
      await expectation;
    });

    test('serversFor возвращает серверы только своей подписки', () async {
      final first = await repo.add(_draft(), [_proxy('a')]);
      final second = await repo.add(_draft(), [_proxy('b'), _proxy('c')]);

      expect(await repo.serversFor(first.id), hasLength(1));
      expect(await repo.serversFor(second.id), hasLength(2));
    });
  });

  group('DriftSubscriptionRepository applyDiff', () {
    test('новый добавлен, исчезнувший удалён, уцелевший с тем же id', () async {
      final sub = await repo.add(_draft(), [_proxy('a'), _proxy('b')]);
      final before = await repo.serversFor(sub.id);
      final bId = before.firstWhere((s) => s.config.host == 'b').id;

      await repo.applyDiff(sub.id, [_proxy('b'), _proxy('c')]);

      final after = await repo.serversFor(sub.id);
      expect(after.map((s) => s.config.host), unorderedEquals(['b', 'c']));
      expect(after.firstWhere((s) => s.config.host == 'b').id, bId);
    });

    test('обнуляет активный, если он попал в удаляемые', () async {
      final sub = await repo.add(_draft(), [_proxy('a'), _proxy('b')]);
      final servers = await repo.serversFor(sub.id);
      final aId = servers.firstWhere((s) => s.config.host == 'a').id;
      await serverRepo.setActive(aId);

      await repo.applyDiff(sub.id, [_proxy('b')]);

      expect(await _activeId(db), isNull);
    });

    test('сохраняет активный, если он уцелел', () async {
      final sub = await repo.add(_draft(), [_proxy('a'), _proxy('b')]);
      final servers = await repo.serversFor(sub.id);
      final bId = servers.firstWhere((s) => s.config.host == 'b').id;
      await serverRepo.setActive(bId);

      await repo.applyDiff(sub.id, [_proxy('b'), _proxy('c')]);

      expect(await _activeId(db), bId);
    });

    test('не трогает ручные серверы вне подписки', () async {
      final manual =
          (await serverRepo.add(
                const VlessConfig(
                  host: 'manual.example',
                  port: 443,
                  name: 'Manual',
                  uuid: _uuid,
                  transport: 'tcp',
                  security: 'none',
                ),
                'vless://$_uuid@manual.example:443'
                '?type=tcp&security=none#Manual',
              )
              as ServerSaved)
          .profile;
      final sub = await repo.add(_draft(), [_proxy('a')]);

      await repo.applyDiff(sub.id, [_proxy('c')]);

      final all = await serverRepo.watchAll().first;
      expect(all.any((s) => s.id == manual.id), isTrue);
    });
  });

  group('DriftSubscriptionRepository updateMeta/remove', () {
    test('updateMeta обновляет трафик, срок и интервал', () async {
      final sub = await repo.add(_draft(), [_proxy('a')]);
      final expiresAt = DateTime(2027);
      final lastUpdatedAt = DateTime(2026, 7, 16, 10);

      await repo.updateMeta(
        sub.id,
        SubscriptionUserInfo(
          upload: 10,
          download: 20,
          total: 500,
          expiresAt: expiresAt,
          updateIntervalHours: 6,
        ),
        lastUpdatedAt,
      );

      final updated = (await repo.watchAll().first).single;
      expect(updated.upload, 10);
      expect(updated.download, 20);
      expect(updated.total, 500);
      expect(updated.expiresAt, expiresAt);
      expect(updated.updateIntervalHours, 6);
      expect(updated.lastUpdatedAt, lastUpdatedAt);
    });

    test('remove удаляет подписку и её серверы, ручные целы', () async {
      final manual =
          (await serverRepo.add(
                const VlessConfig(
                  host: 'manual.example',
                  port: 443,
                  name: 'Manual',
                  uuid: _uuid,
                  transport: 'tcp',
                  security: 'none',
                ),
                'vless://$_uuid@manual.example:443'
                '?type=tcp&security=none#Manual',
              )
              as ServerSaved)
          .profile;
      final sub = await repo.add(_draft(), [_proxy('a'), _proxy('b')]);

      await repo.remove(sub.id);

      expect(await repo.watchAll().first, isEmpty);
      expect(await repo.serversFor(sub.id), isEmpty);
      final all = await serverRepo.watchAll().first;
      expect(all.map((s) => s.id), contains(manual.id));
    });

    test('remove обнуляет активный, если он был сервером подписки', () async {
      final sub = await repo.add(_draft(), [_proxy('a')]);
      final aId = (await repo.serversFor(sub.id)).single.id;
      await serverRepo.setActive(aId);

      await repo.remove(sub.id);

      expect(await _activeId(db), isNull);
    });
  });
}
