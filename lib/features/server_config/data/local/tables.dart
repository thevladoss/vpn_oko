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

  IntColumn get subscriptionId =>
      integer().nullable().references(Subscriptions, #id)();

  IntColumn get sortOrder => integer().nullable()();
}

@DataClassName('SubscriptionRow')
class Subscriptions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get url => text()();

  IntColumn get updateIntervalHours => integer().nullable()();

  IntColumn get upload => integer().withDefault(const Constant(0))();

  IntColumn get download => integer().withDefault(const Constant(0))();

  IntColumn get total => integer().withDefault(const Constant(0))();

  DateTimeColumn get expiresAt => dateTime().nullable()();

  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}

class AppSettings extends Table {
  IntColumn get id => integer()();

  IntColumn get activeServerId => integer().nullable()();

  DateTimeColumn get lastExpiredAt => dateTime().nullable()();

  BoolColumn get autoSwitchEnabled =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
