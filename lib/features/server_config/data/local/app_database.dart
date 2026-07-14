import 'package:drift/drift.dart';
import 'package:vpn_oko/features/server_config/data/local/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [ServerProfiles, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
