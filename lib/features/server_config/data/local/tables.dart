import 'package:drift/drift.dart';

@DataClassName('ServerRow')
class ServerProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get label => text()();

  TextColumn get rawUrl => text()();

  TextColumn get protocol => text()();

  TextColumn get host => text()();

  IntColumn get port => integer()();

  DateTimeColumn get createdAt => dateTime()();
}

class AppSettings extends Table {
  IntColumn get id => integer()();

  IntColumn get activeServerId => integer().nullable()();

  DateTimeColumn get lastExpiredAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
