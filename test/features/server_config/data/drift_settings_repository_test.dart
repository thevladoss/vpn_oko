import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/features/server_config/data/local/app_database.dart';
import 'package:vpn_osin/features/server_config/data/repositories/drift_server_repository.dart';
import 'package:vpn_osin/features/server_config/data/repositories/drift_settings_repository.dart';
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

void main() {
  group('DriftSettingsRepository', () {
    late AppDatabase db;
    late DriftSettingsRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = DriftSettingsRepository(db);
    });

    tearDown(() => db.close());

    test('autoSwitchEnabled в пустой базе → false', () async {
      expect(await repository.autoSwitchEnabled(), isFalse);
    });

    test('setAutoSwitch(enabled: true) переключает флаг в true', () async {
      await repository.setAutoSwitch(enabled: true);

      expect(await repository.autoSwitchEnabled(), isTrue);
    });

    test(
      'setAutoSwitch(enabled: false) после true возвращает флаг в false',
      () async {
        await repository.setAutoSwitch(enabled: true);
        await repository.setAutoSwitch(enabled: false);

        expect(await repository.autoSwitchEnabled(), isFalse);
      },
    );

    test('watchAutoSwitch отдаёт false для пустой строки id=0', () async {
      expect(await repository.watchAutoSwitch().first, isFalse);
    });

    test('watchAutoSwitch эмитит true после setAutoSwitch', () async {
      final expectation = expectLater(
        repository.watchAutoSwitch(),
        emitsInOrder(<Matcher>[isFalse, isTrue]),
      );

      await pumpEventQueue();
      await repository.setAutoSwitch(enabled: true);
      await expectation;
    });

    test('setAutoSwitch не затирает activeServerId', () async {
      final servers = DriftServerRepository(db);
      final saved =
          (await servers.add(_vlessConfig, _vlessUrl) as ServerSaved).profile;
      await servers.setActive(saved.id);

      await repository.setAutoSwitch(enabled: true);

      expect(await repository.autoSwitchEnabled(), isTrue);
      final active = await servers.getActive();
      expect(active?.id, saved.id);
    });

    test('setActive не затирает autoSwitchEnabled', () async {
      final servers = DriftServerRepository(db);
      final saved =
          (await servers.add(_vlessConfig, _vlessUrl) as ServerSaved).profile;

      await repository.setAutoSwitch(enabled: true);
      await servers.setActive(saved.id);

      expect(await repository.autoSwitchEnabled(), isTrue);
      final active = await servers.getActive();
      expect(active?.id, saved.id);
      final settingsRows = await db.select(db.appSettings).get();
      expect(settingsRows, hasLength(1));
    });
  });
}
