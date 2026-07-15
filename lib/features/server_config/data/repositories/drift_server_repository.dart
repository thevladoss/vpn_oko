import 'package:drift/drift.dart';
import 'package:vpn_oko/features/server_config/data/local/app_database.dart';
import 'package:vpn_oko/features/server_config/data/mappers/server_profile_mapper.dart';
import 'package:vpn_oko/features/server_config/domain/entities/add_server_outcome.dart';
import 'package:vpn_oko/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_oko/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_oko/features/server_config/domain/repositories/server_repository.dart';

class DriftServerRepository implements ServerRepository {
  const DriftServerRepository(this.db);

  final AppDatabase db;

  static const int _settingsId = 0;

  @override
  Stream<List<ServerProfile>> watchAll() => db
      .select(db.serverProfiles)
      .watch()
      .map((rows) => rows.map(rowToProfile).toList());

  @override
  Future<AddServerOutcome> add(ProxyConfig config, String rawUrl) async {
    final existing = await (db.select(
      db.serverProfiles,
    )..where((t) => t.rawUrl.equals(rawUrl))).getSingleOrNull();
    if (existing != null) {
      return ServerDuplicate(rowToProfile(existing));
    }
    final inserted = await db
        .into(db.serverProfiles)
        .insertReturning(profileToCompanion(config, rawUrl));
    if (await getActive() == null) {
      await setActive(inserted.id);
    }
    return ServerSaved(rowToProfile(inserted));
  }

  @override
  Future<void> setActive(int id) => db
      .into(db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(
          id: const Value(_settingsId),
          activeServerId: Value(id),
        ),
      );

  @override
  Stream<ServerProfile?> watchActive() =>
      _activeQuery().watch().map(_readActive);

  @override
  Future<ServerProfile?> getActive() async =>
      _readActive(await _activeQuery().get());

  @override
  Future<void> rename(int id, String label) =>
      (db.update(db.serverProfiles)..where((t) => t.id.equals(id))).write(
        ServerProfilesCompanion(label: Value(label)),
      );

  @override
  Future<void> delete(int id) =>
      (db.delete(db.serverProfiles)..where((t) => t.id.equals(id))).go();

  Selectable<TypedResult> _activeQuery() => db.select(db.appSettings).join([
    leftOuterJoin(
      db.serverProfiles,
      db.serverProfiles.id.equalsExp(db.appSettings.activeServerId),
    ),
  ])..where(db.appSettings.id.equals(_settingsId));

  ServerProfile? _readActive(List<TypedResult> rows) {
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first.readTableOrNull(db.serverProfiles);
    return row == null ? null : rowToProfile(row);
  }
}
