import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vpn_osin/features/server_config/data/local/app_database.dart';
import 'package:vpn_osin/features/server_config/data/mappers/server_profile_mapper.dart';

const _vlessUrl =
    'vless://b831381d-6324-4d53-ad4f-8cda48b30811@example.com:443'
    '?type=tcp&security=reality&sni=www.microsoft.com#Tokyo';

const _trojanUrl = 'trojan://secret@node.example:8443#Osaka';

void _createV1Schema(Database raw) {
  raw
    ..execute('''
CREATE TABLE server_profiles (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  label TEXT NOT NULL,
  raw_url TEXT NOT NULL,
  protocol TEXT NOT NULL,
  host TEXT NOT NULL,
  port INTEGER NOT NULL,
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

void main() {
  group('миграция схемы v1 → v2', () {
    late Database raw;
    late AppDatabase db;

    setUp(() {
      raw = sqlite3.openInMemory();
      _createV1Schema(raw);
      raw
        ..execute(
          'INSERT INTO server_profiles '
          '(label, raw_url, protocol, host, port, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          <Object?>[
            'Tokyo',
            _vlessUrl,
            'vless',
            'example.com',
            443,
            1700000000,
          ],
        )
        ..execute('PRAGMA user_version = 1');
      db = AppDatabase(NativeDatabase.opened(raw));
    });

    tearDown(() => db.close());

    test('существующий сервер целен после миграции', () async {
      final servers = await db.select(db.serverProfiles).get();

      expect(servers, hasLength(1));
      final server = servers.single;
      expect(server.label, 'Tokyo');
      expect(server.rawUrl, _vlessUrl);
      expect(server.host, 'example.com');
      expect(server.port, 443);
    });

    test('мигрированный сервер имеет subscriptionId = null', () async {
      final server = (await db.select(db.serverProfiles).get()).single;

      expect(server.subscriptionId, isNull);
      expect(server.sortOrder, isNull);
    });

    test('таблица subscriptions появилась', () async {
      final tables = await db
          .customSelect(
            'SELECT name FROM sqlite_master '
            "WHERE type = 'table' AND name = 'subscriptions'",
          )
          .get();

      expect(tables, hasLength(1));
    });

    test('user_version стал 2', () async {
      final row = await db.customSelect('PRAGMA user_version').getSingle();

      expect(row.read<int>('user_version'), 2);
    });
  });

  group('roundtrip subscriptionId в маппере', () {
    ServerRow rowWith({int? subscriptionId}) => ServerRow(
      id: 1,
      label: 'Osaka',
      rawUrl: _trojanUrl,
      protocol: 'trojan',
      host: 'node.example',
      port: 8443,
      createdAt: DateTime(2026, 7, 16),
      subscriptionId: subscriptionId,
    );

    test('rowToProfile переносит непустой subscriptionId', () {
      expect(rowToProfile(rowWith(subscriptionId: 5)).subscriptionId, 5);
    });

    test('rowToProfile отдаёт null для ручного сервера', () {
      expect(rowToProfile(rowWith()).subscriptionId, isNull);
    });
  });
}
