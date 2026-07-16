import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/features/server_config/data/local/app_database.dart';
import 'package:vpn_osin/features/server_config/data/mappers/server_profile_mapper.dart';
import 'package:vpn_osin/features/server_config/data/repositories/drift_server_repository.dart';
import 'package:vpn_osin/features/server_config/domain/entities/add_server_outcome.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';

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

const _trojanUrl = 'trojan://secret@node.example:8443#Osaka';

const _trojanConfig = TrojanConfig(
  host: 'node.example',
  port: 8443,
  name: 'Osaka',
  password: 'secret',
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

  group('DriftServerRepository', () {
    late AppDatabase db;
    late DriftServerRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = DriftServerRepository(db);
    });

    tearDown(() => db.close());

    test('add нового сервера возвращает ServerSaved с ненулевым id', () async {
      final outcome = await repository.add(_vlessConfig, _vlessUrl);

      expect(outcome, isA<ServerSaved>());
      final saved = (outcome as ServerSaved).profile;
      expect(saved.id, greaterThan(0));
      expect(saved.rawUrl, _vlessUrl);
      expect(saved.config, _vlessConfig);

      final all = await repository.watchAll().first;
      expect(all, hasLength(1));
      expect(all.single.id, saved.id);
    });

    test(
      'повторный add того же rawUrl → ServerDuplicate, один сервер',
      () async {
        final first = await repository.add(_vlessConfig, _vlessUrl);
        final second = await repository.add(_vlessConfig, _vlessUrl);

        expect(first, isA<ServerSaved>());
        expect(second, isA<ServerDuplicate>());
        expect(
          (second as ServerDuplicate).existing.id,
          (first as ServerSaved).profile.id,
        );

        final all = await repository.watchAll().first;
        expect(all, hasLength(1));
      },
    );

    test('add другого rawUrl создаёт второй сервер', () async {
      await repository.add(_vlessConfig, _vlessUrl);
      await repository.add(_trojanConfig, _trojanUrl);

      final all = await repository.watchAll().first;
      expect(all, hasLength(2));
      expect(
        all.map((p) => p.rawUrl),
        containsAll(<String>[_vlessUrl, _trojanUrl]),
      );
    });

    test('add в пустую базу делает сервер активным', () async {
      final saved =
          (await repository.add(_vlessConfig, _vlessUrl) as ServerSaved)
              .profile;

      final active = await repository.watchActive().first;
      expect(active?.id, saved.id);
      final snapshot = await repository.getActive();
      expect(snapshot?.id, saved.id);
    });

    test('add второго при активном первом не меняет активного', () async {
      final a = (await repository.add(_vlessConfig, _vlessUrl) as ServerSaved)
          .profile;
      await repository.add(_trojanConfig, _trojanUrl);

      final active = await repository.getActive();
      expect(active?.id, a.id);
    });

    test('дубликат не меняет активного', () async {
      final a = (await repository.add(_vlessConfig, _vlessUrl) as ServerSaved)
          .profile;
      final duplicate = await repository.add(_vlessConfig, _vlessUrl);

      expect(duplicate, isA<ServerDuplicate>());
      final active = await repository.getActive();
      expect(active?.id, a.id);
    });

    test('setActive отражается в watchActive и getActive', () async {
      final saved =
          (await repository.add(_vlessConfig, _vlessUrl) as ServerSaved)
              .profile;

      await repository.setActive(saved.id);

      final active = await repository.watchActive().first;
      expect(active?.id, saved.id);
      final snapshot = await repository.getActive();
      expect(snapshot?.id, saved.id);
    });

    test(
      'setActive переключает активного, AppSettings остаётся singleton',
      () async {
        final a = (await repository.add(_vlessConfig, _vlessUrl) as ServerSaved)
            .profile;
        final b =
            (await repository.add(_trojanConfig, _trojanUrl) as ServerSaved)
                .profile;

        await repository.setActive(a.id);
        await repository.setActive(b.id);

        final active = await repository.getActive();
        expect(active?.id, b.id);

        final settingsRows = await db.select(db.appSettings).get();
        expect(settingsRows, hasLength(1));
      },
    );

    test('rename меняет label в watchAll', () async {
      final saved =
          (await repository.add(_vlessConfig, _vlessUrl) as ServerSaved)
              .profile;

      await repository.rename(saved.id, 'Renamed');

      final all = await repository.watchAll().first;
      expect(all.single.label, 'Renamed');
    });

    test('delete активного убирает его и обнуляет watchActive', () async {
      final saved =
          (await repository.add(_vlessConfig, _vlessUrl) as ServerSaved)
              .profile;
      await repository.setActive(saved.id);

      await repository.delete(saved.id);

      final all = await repository.watchAll().first;
      expect(all, isEmpty);
      final active = await repository.watchActive().first;
      expect(active, isNull);
    });

    test('watchAll реактивно эмитит после вставки', () async {
      final expectation = expectLater(
        repository.watchAll(),
        emitsInOrder(<Matcher>[isEmpty, hasLength(1)]),
      );

      await pumpEventQueue();
      await repository.add(_vlessConfig, _vlessUrl);
      await expectation;
    });
  });
}
