import 'package:drift/drift.dart';
import 'package:vpn_osin/features/server_config/data/local/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [ServerProfiles, AppSettings, Subscriptions])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(subscriptions);
        await m.addColumn(serverProfiles, serverProfiles.subscriptionId);
        await m.addColumn(serverProfiles, serverProfiles.sortOrder);
      }
    },
  );
}
