import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vpn_osin/features/server_config/data/local/app_database.dart';

const _vlessUrl =
    'vless://b831381d-6324-4d53-ad4f-8cda48b30811@example.com:443'
    '?type=tcp&security=reality&sni=www.microsoft.com#Tokyo';

const _subscriptionUrl = 'https://sub.example/link';

void _createV2Schema(Database raw) {
  raw
    ..execute('''
CREATE TABLE server_profiles (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  label TEXT NOT NULL,
  raw_url TEXT NOT NULL,
  protocol TEXT NOT NULL,
  host TEXT NOT NULL,
  port INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  subscription_id INTEGER REFERENCES subscriptions (id),
  sort_order INTEGER
);
''')
    ..execute('''
CREATE TABLE subscriptions (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  url TEXT NOT NULL,
  update_interval_hours INTEGER,
  upload INTEGER NOT NULL DEFAULT 0,
  download INTEGER NOT NULL DEFAULT 0,
  total INTEGER NOT NULL DEFAULT 0,
  expires_at INTEGER,
  last_updated_at INTEGER,
  created_at INTEGER NOT NULL
);
''')
    ..execute('''
CREATE TABLE app_settings (
  id INTEGER NOT NULL PRIMARY KEY,
  active_server_id INTEGER,
  last_expired_at INTEGER
);
''');
}

void _seedV2Data(Database raw) {
  raw
    ..execute(
      'INSERT INTO subscriptions '
      '(id, name, url, update_interval_hours, upload, download, total, '
      'created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[1, 'My Sub', _subscriptionUrl, 12, 111, 222, 333, 1700000000],
    )
    ..execute(
      'INSERT INTO server_profiles '
      '(id, label, raw_url, protocol, host, port, created_at, '
      'subscription_id, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[1, 'Tokyo', _vlessUrl, 'vless', 'example.com', 443, 1700000000,
        1, 0],
    )
    ..execute(
      'INSERT INTO app_settings (id, active_server_id, last_expired_at) '
      'VALUES (?, ?, ?)',
      <Object?>[0, 1, null],
    )
    ..execute('PRAGMA user_version = 2');
}

void main() {
  group('миграция схемы v2 → v3', () {
    late Database raw;
    late AppDatabase db;

    setUp(() {
      raw = sqlite3.openInMemory();
      _createV2Schema(raw);
      _seedV2Data(raw);
      db = AppDatabase(NativeDatabase.opened(raw));
    });

    tearDown(() => db.close());

    test('существующий сервер целен после миграции', () async {
      final server = (await db.select(db.serverProfiles).get()).single;

      expect(server.label, 'Tokyo');
      expect(server.rawUrl, _vlessUrl);
      expect(server.host, 'example.com');
      expect(server.port, 443);
      expect(server.subscriptionId, 1);
    });

    test('существующая подписка цела после миграции', () async {
      final subscription = (await db.select(db.subscriptions).get()).single;

      expect(subscription.name, 'My Sub');
      expect(subscription.url, _subscriptionUrl);
      expect(subscription.upload, 111);
      expect(subscription.download, 222);
      expect(subscription.total, 333);
    });

    test('колонка autoSwitchEnabled = false для существующей строки', () async {
      final settings = (await db.select(db.appSettings).get()).single;

      expect(settings.autoSwitchEnabled, isFalse);
      expect(settings.activeServerId, 1);
    });

    test('user_version стал 3', () async {
      final row = await db.customSelect('PRAGMA user_version').getSingle();

      expect(row.read<int>('user_version'), 3);
    });
  });
}
