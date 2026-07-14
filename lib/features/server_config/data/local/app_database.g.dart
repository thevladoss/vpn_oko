// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ServerProfilesTable extends ServerProfiles
    with TableInfo<$ServerProfilesTable, ServerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServerProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawUrlMeta = const VerificationMeta('rawUrl');
  @override
  late final GeneratedColumn<String> rawUrl = GeneratedColumn<String>(
    'raw_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _protocolMeta = const VerificationMeta(
    'protocol',
  );
  @override
  late final GeneratedColumn<String> protocol = GeneratedColumn<String>(
    'protocol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    label,
    rawUrl,
    protocol,
    host,
    port,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'server_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('raw_url')) {
      context.handle(
        _rawUrlMeta,
        rawUrl.isAcceptableOrUnknown(data['raw_url']!, _rawUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_rawUrlMeta);
    }
    if (data.containsKey('protocol')) {
      context.handle(
        _protocolMeta,
        protocol.isAcceptableOrUnknown(data['protocol']!, _protocolMeta),
      );
    } else if (isInserting) {
      context.missing(_protocolMeta);
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('port')) {
      context.handle(
        _portMeta,
        port.isAcceptableOrUnknown(data['port']!, _portMeta),
      );
    } else if (isInserting) {
      context.missing(_portMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      rawUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_url'],
      )!,
      protocol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}protocol'],
      )!,
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      )!,
      port: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}port'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ServerProfilesTable createAlias(String alias) {
    return $ServerProfilesTable(attachedDatabase, alias);
  }
}

class ServerRow extends DataClass implements Insertable<ServerRow> {
  final int id;
  final String label;
  final String rawUrl;
  final String protocol;
  final String host;
  final int port;
  final DateTime createdAt;
  const ServerRow({
    required this.id,
    required this.label,
    required this.rawUrl,
    required this.protocol,
    required this.host,
    required this.port,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['label'] = Variable<String>(label);
    map['raw_url'] = Variable<String>(rawUrl);
    map['protocol'] = Variable<String>(protocol);
    map['host'] = Variable<String>(host);
    map['port'] = Variable<int>(port);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ServerProfilesCompanion toCompanion(bool nullToAbsent) {
    return ServerProfilesCompanion(
      id: Value(id),
      label: Value(label),
      rawUrl: Value(rawUrl),
      protocol: Value(protocol),
      host: Value(host),
      port: Value(port),
      createdAt: Value(createdAt),
    );
  }

  factory ServerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerRow(
      id: serializer.fromJson<int>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      rawUrl: serializer.fromJson<String>(json['rawUrl']),
      protocol: serializer.fromJson<String>(json['protocol']),
      host: serializer.fromJson<String>(json['host']),
      port: serializer.fromJson<int>(json['port']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'label': serializer.toJson<String>(label),
      'rawUrl': serializer.toJson<String>(rawUrl),
      'protocol': serializer.toJson<String>(protocol),
      'host': serializer.toJson<String>(host),
      'port': serializer.toJson<int>(port),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ServerRow copyWith({
    int? id,
    String? label,
    String? rawUrl,
    String? protocol,
    String? host,
    int? port,
    DateTime? createdAt,
  }) => ServerRow(
    id: id ?? this.id,
    label: label ?? this.label,
    rawUrl: rawUrl ?? this.rawUrl,
    protocol: protocol ?? this.protocol,
    host: host ?? this.host,
    port: port ?? this.port,
    createdAt: createdAt ?? this.createdAt,
  );
  ServerRow copyWithCompanion(ServerProfilesCompanion data) {
    return ServerRow(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      rawUrl: data.rawUrl.present ? data.rawUrl.value : this.rawUrl,
      protocol: data.protocol.present ? data.protocol.value : this.protocol,
      host: data.host.present ? data.host.value : this.host,
      port: data.port.present ? data.port.value : this.port,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerRow(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('rawUrl: $rawUrl, ')
          ..write('protocol: $protocol, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, label, rawUrl, protocol, host, port, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerRow &&
          other.id == this.id &&
          other.label == this.label &&
          other.rawUrl == this.rawUrl &&
          other.protocol == this.protocol &&
          other.host == this.host &&
          other.port == this.port &&
          other.createdAt == this.createdAt);
}

class ServerProfilesCompanion extends UpdateCompanion<ServerRow> {
  final Value<int> id;
  final Value<String> label;
  final Value<String> rawUrl;
  final Value<String> protocol;
  final Value<String> host;
  final Value<int> port;
  final Value<DateTime> createdAt;
  const ServerProfilesCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.rawUrl = const Value.absent(),
    this.protocol = const Value.absent(),
    this.host = const Value.absent(),
    this.port = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ServerProfilesCompanion.insert({
    this.id = const Value.absent(),
    required String label,
    required String rawUrl,
    required String protocol,
    required String host,
    required int port,
    required DateTime createdAt,
  }) : label = Value(label),
       rawUrl = Value(rawUrl),
       protocol = Value(protocol),
       host = Value(host),
       port = Value(port),
       createdAt = Value(createdAt);
  static Insertable<ServerRow> custom({
    Expression<int>? id,
    Expression<String>? label,
    Expression<String>? rawUrl,
    Expression<String>? protocol,
    Expression<String>? host,
    Expression<int>? port,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (rawUrl != null) 'raw_url': rawUrl,
      if (protocol != null) 'protocol': protocol,
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ServerProfilesCompanion copyWith({
    Value<int>? id,
    Value<String>? label,
    Value<String>? rawUrl,
    Value<String>? protocol,
    Value<String>? host,
    Value<int>? port,
    Value<DateTime>? createdAt,
  }) {
    return ServerProfilesCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      rawUrl: rawUrl ?? this.rawUrl,
      protocol: protocol ?? this.protocol,
      host: host ?? this.host,
      port: port ?? this.port,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (rawUrl.present) {
      map['raw_url'] = Variable<String>(rawUrl.value);
    }
    if (protocol.present) {
      map['protocol'] = Variable<String>(protocol.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerProfilesCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('rawUrl: $rawUrl, ')
          ..write('protocol: $protocol, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeServerIdMeta = const VerificationMeta(
    'activeServerId',
  );
  @override
  late final GeneratedColumn<int> activeServerId = GeneratedColumn<int>(
    'active_server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastExpiredAtMeta = const VerificationMeta(
    'lastExpiredAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastExpiredAt =
      GeneratedColumn<DateTime>(
        'last_expired_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [id, activeServerId, lastExpiredAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('active_server_id')) {
      context.handle(
        _activeServerIdMeta,
        activeServerId.isAcceptableOrUnknown(
          data['active_server_id']!,
          _activeServerIdMeta,
        ),
      );
    }
    if (data.containsKey('last_expired_at')) {
      context.handle(
        _lastExpiredAtMeta,
        lastExpiredAt.isAcceptableOrUnknown(
          data['last_expired_at']!,
          _lastExpiredAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      activeServerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active_server_id'],
      ),
      lastExpiredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_expired_at'],
      ),
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final int id;
  final int? activeServerId;
  final DateTime? lastExpiredAt;
  const AppSetting({required this.id, this.activeServerId, this.lastExpiredAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || activeServerId != null) {
      map['active_server_id'] = Variable<int>(activeServerId);
    }
    if (!nullToAbsent || lastExpiredAt != null) {
      map['last_expired_at'] = Variable<DateTime>(lastExpiredAt);
    }
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      activeServerId: activeServerId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeServerId),
      lastExpiredAt: lastExpiredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastExpiredAt),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      id: serializer.fromJson<int>(json['id']),
      activeServerId: serializer.fromJson<int?>(json['activeServerId']),
      lastExpiredAt: serializer.fromJson<DateTime?>(json['lastExpiredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'activeServerId': serializer.toJson<int?>(activeServerId),
      'lastExpiredAt': serializer.toJson<DateTime?>(lastExpiredAt),
    };
  }

  AppSetting copyWith({
    int? id,
    Value<int?> activeServerId = const Value.absent(),
    Value<DateTime?> lastExpiredAt = const Value.absent(),
  }) => AppSetting(
    id: id ?? this.id,
    activeServerId: activeServerId.present
        ? activeServerId.value
        : this.activeServerId,
    lastExpiredAt: lastExpiredAt.present
        ? lastExpiredAt.value
        : this.lastExpiredAt,
  );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      id: data.id.present ? data.id.value : this.id,
      activeServerId: data.activeServerId.present
          ? data.activeServerId.value
          : this.activeServerId,
      lastExpiredAt: data.lastExpiredAt.present
          ? data.lastExpiredAt.value
          : this.lastExpiredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('id: $id, ')
          ..write('activeServerId: $activeServerId, ')
          ..write('lastExpiredAt: $lastExpiredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, activeServerId, lastExpiredAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.id == this.id &&
          other.activeServerId == this.activeServerId &&
          other.lastExpiredAt == this.lastExpiredAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<int> id;
  final Value<int?> activeServerId;
  final Value<DateTime?> lastExpiredAt;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.activeServerId = const Value.absent(),
    this.lastExpiredAt = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.activeServerId = const Value.absent(),
    this.lastExpiredAt = const Value.absent(),
  });
  static Insertable<AppSetting> custom({
    Expression<int>? id,
    Expression<int>? activeServerId,
    Expression<DateTime>? lastExpiredAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activeServerId != null) 'active_server_id': activeServerId,
      if (lastExpiredAt != null) 'last_expired_at': lastExpiredAt,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<int?>? activeServerId,
    Value<DateTime?>? lastExpiredAt,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      activeServerId: activeServerId ?? this.activeServerId,
      lastExpiredAt: lastExpiredAt ?? this.lastExpiredAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (activeServerId.present) {
      map['active_server_id'] = Variable<int>(activeServerId.value);
    }
    if (lastExpiredAt.present) {
      map['last_expired_at'] = Variable<DateTime>(lastExpiredAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('activeServerId: $activeServerId, ')
          ..write('lastExpiredAt: $lastExpiredAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ServerProfilesTable serverProfiles = $ServerProfilesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    serverProfiles,
    appSettings,
  ];
}

typedef $$ServerProfilesTableCreateCompanionBuilder =
    ServerProfilesCompanion Function({
      Value<int> id,
      required String label,
      required String rawUrl,
      required String protocol,
      required String host,
      required int port,
      required DateTime createdAt,
    });
typedef $$ServerProfilesTableUpdateCompanionBuilder =
    ServerProfilesCompanion Function({
      Value<int> id,
      Value<String> label,
      Value<String> rawUrl,
      Value<String> protocol,
      Value<String> host,
      Value<int> port,
      Value<DateTime> createdAt,
    });

class $$ServerProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ServerProfilesTable> {
  $$ServerProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawUrl => $composableBuilder(
    column: $table.rawUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get protocol => $composableBuilder(
    column: $table.protocol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ServerProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ServerProfilesTable> {
  $$ServerProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawUrl => $composableBuilder(
    column: $table.rawUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get protocol => $composableBuilder(
    column: $table.protocol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServerProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServerProfilesTable> {
  $$ServerProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get rawUrl =>
      $composableBuilder(column: $table.rawUrl, builder: (column) => column);

  GeneratedColumn<String> get protocol =>
      $composableBuilder(column: $table.protocol, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ServerProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServerProfilesTable,
          ServerRow,
          $$ServerProfilesTableFilterComposer,
          $$ServerProfilesTableOrderingComposer,
          $$ServerProfilesTableAnnotationComposer,
          $$ServerProfilesTableCreateCompanionBuilder,
          $$ServerProfilesTableUpdateCompanionBuilder,
          (
            ServerRow,
            BaseReferences<_$AppDatabase, $ServerProfilesTable, ServerRow>,
          ),
          ServerRow,
          PrefetchHooks Function()
        > {
  $$ServerProfilesTableTableManager(
    _$AppDatabase db,
    $ServerProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServerProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServerProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServerProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> rawUrl = const Value.absent(),
                Value<String> protocol = const Value.absent(),
                Value<String> host = const Value.absent(),
                Value<int> port = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ServerProfilesCompanion(
                id: id,
                label: label,
                rawUrl: rawUrl,
                protocol: protocol,
                host: host,
                port: port,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String label,
                required String rawUrl,
                required String protocol,
                required String host,
                required int port,
                required DateTime createdAt,
              }) => ServerProfilesCompanion.insert(
                id: id,
                label: label,
                rawUrl: rawUrl,
                protocol: protocol,
                host: host,
                port: port,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ServerProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServerProfilesTable,
      ServerRow,
      $$ServerProfilesTableFilterComposer,
      $$ServerProfilesTableOrderingComposer,
      $$ServerProfilesTableAnnotationComposer,
      $$ServerProfilesTableCreateCompanionBuilder,
      $$ServerProfilesTableUpdateCompanionBuilder,
      (
        ServerRow,
        BaseReferences<_$AppDatabase, $ServerProfilesTable, ServerRow>,
      ),
      ServerRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<int?> activeServerId,
      Value<DateTime?> lastExpiredAt,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<int?> activeServerId,
      Value<DateTime?> lastExpiredAt,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activeServerId => $composableBuilder(
    column: $table.activeServerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastExpiredAt => $composableBuilder(
    column: $table.lastExpiredAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activeServerId => $composableBuilder(
    column: $table.activeServerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastExpiredAt => $composableBuilder(
    column: $table.lastExpiredAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get activeServerId => $composableBuilder(
    column: $table.activeServerId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastExpiredAt => $composableBuilder(
    column: $table.lastExpiredAt,
    builder: (column) => column,
  );
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> activeServerId = const Value.absent(),
                Value<DateTime?> lastExpiredAt = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                activeServerId: activeServerId,
                lastExpiredAt: lastExpiredAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> activeServerId = const Value.absent(),
                Value<DateTime?> lastExpiredAt = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                id: id,
                activeServerId: activeServerId,
                lastExpiredAt: lastExpiredAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ServerProfilesTableTableManager get serverProfiles =>
      $$ServerProfilesTableTableManager(_db, _db.serverProfiles);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
