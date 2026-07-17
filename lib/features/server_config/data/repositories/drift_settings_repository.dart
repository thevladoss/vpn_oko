import 'package:drift/drift.dart';
import 'package:vpn_osin/features/server_config/data/local/app_database.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/settings_repository.dart';

class DriftSettingsRepository implements SettingsRepository {
  const DriftSettingsRepository(this.db);

  final AppDatabase db;

  static const int _settingsId = 0;

  @override
  Stream<bool> watchAutoSwitch() =>
      (db.select(db.appSettings)..where((t) => t.id.equals(_settingsId)))
          .watchSingleOrNull()
          .map((row) => row?.autoSwitchEnabled ?? false);

  @override
  Future<bool> autoSwitchEnabled() async {
    final row = await (db.select(
      db.appSettings,
    )..where((t) => t.id.equals(_settingsId))).getSingleOrNull();
    return row?.autoSwitchEnabled ?? false;
  }

  @override
  Future<void> setAutoSwitch({required bool enabled}) => db
      .into(db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(
          id: const Value(_settingsId),
          autoSwitchEnabled: Value(enabled),
        ),
      );
}
