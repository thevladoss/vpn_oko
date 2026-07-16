// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SubscriptionsTable extends Subscriptions
    with TableInfo<$SubscriptionsTable, SubscriptionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubscriptionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updateIntervalHoursMeta =
      const VerificationMeta('updateIntervalHours');
  @override
  late final GeneratedColumn<int> updateIntervalHours = GeneratedColumn<int>(
    'update_interval_hours',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadMeta = const VerificationMeta('upload');
  @override
  late final GeneratedColumn<int> upload = GeneratedColumn<int>(
    'upload',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _downloadMeta = const VerificationMeta(
    'download',
  );
  @override
  late final GeneratedColumn<int> download = GeneratedColumn<int>(
    'download',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastUpdatedAtMeta = const VerificationMeta(
    'lastUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdatedAt =
      GeneratedColumn<DateTime>(
        'last_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
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
    name,
    url,
    updateIntervalHours,
    upload,
    download,
    total,
    expiresAt,
    lastUpdatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subscriptions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubscriptionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('update_interval_hours')) {
      context.handle(
        _updateIntervalHoursMeta,
        updateIntervalHours.isAcceptableOrUnknown(
          data['update_interval_hours']!,
          _updateIntervalHoursMeta,
        ),
      );
    }
    if (data.containsKey('upload')) {
      context.handle(
        _uploadMeta,
        upload.isAcceptableOrUnknown(data['upload']!, _uploadMeta),
      );
    }
    if (data.containsKey('download')) {
      context.handle(
        _downloadMeta,
        download.isAcceptableOrUnknown(data['download']!, _downloadMeta),
      );
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('last_updated_at')) {
      context.handle(
        _lastUpdatedAtMeta,
        lastUpdatedAt.isAcceptableOrUnknown(
          data['last_updated_at']!,
          _lastUpdatedAtMeta,
        ),
      );
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
  SubscriptionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubscriptionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      updateIntervalHours: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}update_interval_hours'],
      ),
      upload: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}upload'],
      )!,
      download: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}download'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      ),
      lastUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SubscriptionsTable createAlias(String alias) {
    return $SubscriptionsTable(attachedDatabase, alias);
  }
}

class SubscriptionRow extends DataClass implements Insertable<SubscriptionRow> {
  final int id;
  final String name;
  final String url;
  final int? updateIntervalHours;
  final int upload;
  final int download;
  final int total;
  final DateTime? expiresAt;
  final DateTime? lastUpdatedAt;
  final DateTime createdAt;
  const SubscriptionRow({
    required this.id,
    required this.name,
    required this.url,
    this.updateIntervalHours,
    required this.upload,
    required this.download,
    required this.total,
    this.expiresAt,
    this.lastUpdatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || updateIntervalHours != null) {
      map['update_interval_hours'] = Variable<int>(updateIntervalHours);
    }
    map['upload'] = Variable<int>(upload);
    map['download'] = Variable<int>(download);
    map['total'] = Variable<int>(total);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    if (!nullToAbsent || lastUpdatedAt != null) {
      map['last_updated_at'] = Variable<DateTime>(lastUpdatedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SubscriptionsCompanion toCompanion(bool nullToAbsent) {
    return SubscriptionsCompanion(
      id: Value(id),
      name: Value(name),
      url: Value(url),
      updateIntervalHours: updateIntervalHours == null && nullToAbsent
          ? const Value.absent()
          : Value(updateIntervalHours),
      upload: Value(upload),
      download: Value(download),
      total: Value(total),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      lastUpdatedAt: lastUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUpdatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory SubscriptionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubscriptionRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      url: serializer.fromJson<String>(json['url']),
      updateIntervalHours: serializer.fromJson<int?>(
        json['updateIntervalHours'],
      ),
      upload: serializer.fromJson<int>(json['upload']),
      download: serializer.fromJson<int>(json['download']),
      total: serializer.fromJson<int>(json['total']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
      lastUpdatedAt: serializer.fromJson<DateTime?>(json['lastUpdatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'url': serializer.toJson<String>(url),
      'updateIntervalHours': serializer.toJson<int?>(updateIntervalHours),
      'upload': serializer.toJson<int>(upload),
      'download': serializer.toJson<int>(download),
      'total': serializer.toJson<int>(total),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
      'lastUpdatedAt': serializer.toJson<DateTime?>(lastUpdatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SubscriptionRow copyWith({
    int? id,
    String? name,
    String? url,
    Value<int?> updateIntervalHours = const Value.absent(),
    int? upload,
    int? download,
    int? total,
    Value<DateTime?> expiresAt = const Value.absent(),
    Value<DateTime?> lastUpdatedAt = const Value.absent(),
    DateTime? createdAt,
  }) => SubscriptionRow(
    id: id ?? this.id,
    name: name ?? this.name,
    url: url ?? this.url,
    updateIntervalHours: updateIntervalHours.present
        ? updateIntervalHours.value
        : this.updateIntervalHours,
    upload: upload ?? this.upload,
    download: download ?? this.download,
    total: total ?? this.total,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    lastUpdatedAt: lastUpdatedAt.present
        ? lastUpdatedAt.value
        : this.lastUpdatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  SubscriptionRow copyWithCompanion(SubscriptionsCompanion data) {
    return SubscriptionRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      url: data.url.present ? data.url.value : this.url,
      updateIntervalHours: data.updateIntervalHours.present
          ? data.updateIntervalHours.value
          : this.updateIntervalHours,
      upload: data.upload.present ? data.upload.value : this.upload,
      download: data.download.present ? data.download.value : this.download,
      total: data.total.present ? data.total.value : this.total,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      lastUpdatedAt: data.lastUpdatedAt.present
          ? data.lastUpdatedAt.value
          : this.lastUpdatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubscriptionRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('updateIntervalHours: $updateIntervalHours, ')
          ..write('upload: $upload, ')
          ..write('download: $download, ')
          ..write('total: $total, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('lastUpdatedAt: $lastUpdatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    url,
    updateIntervalHours,
    upload,
    download,
    total,
    expiresAt,
    lastUpdatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubscriptionRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.url == this.url &&
          other.updateIntervalHours == this.updateIntervalHours &&
          other.upload == this.upload &&
          other.download == this.download &&
          other.total == this.total &&
          other.expiresAt == this.expiresAt &&
          other.lastUpdatedAt == this.lastUpdatedAt &&
          other.createdAt == this.createdAt);
}

class SubscriptionsCompanion extends UpdateCompanion<SubscriptionRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> url;
  final Value<int?> updateIntervalHours;
  final Value<int> upload;
  final Value<int> download;
  final Value<int> total;
  final Value<DateTime?> expiresAt;
  final Value<DateTime?> lastUpdatedAt;
  final Value<DateTime> createdAt;
  const SubscriptionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.url = const Value.absent(),
    this.updateIntervalHours = const Value.absent(),
    this.upload = const Value.absent(),
    this.download = const Value.absent(),
    this.total = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.lastUpdatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SubscriptionsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String url,
    this.updateIntervalHours = const Value.absent(),
    this.upload = const Value.absent(),
    this.download = const Value.absent(),
    this.total = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.lastUpdatedAt = const Value.absent(),
    required DateTime createdAt,
  }) : name = Value(name),
       url = Value(url),
       createdAt = Value(createdAt);
  static Insertable<SubscriptionRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? url,
    Expression<int>? updateIntervalHours,
    Expression<int>? upload,
    Expression<int>? download,
    Expression<int>? total,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? lastUpdatedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (url != null) 'url': url,
      if (updateIntervalHours != null)
        'update_interval_hours': updateIntervalHours,
      if (upload != null) 'upload': upload,
      if (download != null) 'download': download,
      if (total != null) 'total': total,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (lastUpdatedAt != null) 'last_updated_at': lastUpdatedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SubscriptionsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? url,
    Value<int?>? updateIntervalHours,
    Value<int>? upload,
    Value<int>? download,
    Value<int>? total,
    Value<DateTime?>? expiresAt,
    Value<DateTime?>? lastUpdatedAt,
    Value<DateTime>? createdAt,
  }) {
    return SubscriptionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      updateIntervalHours: updateIntervalHours ?? this.updateIntervalHours,
      upload: upload ?? this.upload,
      download: download ?? this.download,
      total: total ?? this.total,
      expiresAt: expiresAt ?? this.expiresAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (updateIntervalHours.present) {
      map['update_interval_hours'] = Variable<int>(updateIntervalHours.value);
    }
    if (upload.present) {
      map['upload'] = Variable<int>(upload.value);
    }
    if (download.present) {
      map['download'] = Variable<int>(download.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (lastUpdatedAt.present) {
      map['last_updated_at'] = Variable<DateTime>(lastUpdatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubscriptionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('updateIntervalHours: $updateIntervalHours, ')
          ..write('upload: $upload, ')
          ..write('download: $download, ')
          ..write('total: $total, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('lastUpdatedAt: $lastUpdatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

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
  static const VerificationMeta _subscriptionIdMeta = const VerificationMeta(
    'subscriptionId',
  );
  @override
  late final GeneratedColumn<int> subscriptionId = GeneratedColumn<int>(
    'subscription_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES subscriptions (id)',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
    subscriptionId,
    sortOrder,
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
    if (data.containsKey('subscription_id')) {
      context.handle(
        _subscriptionIdMeta,
        subscriptionId.isAcceptableOrUnknown(
          data['subscription_id']!,
          _subscriptionIdMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
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
      subscriptionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subscription_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      ),
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
  final int? subscriptionId;
  final int? sortOrder;
  const ServerRow({
    required this.id,
    required this.label,
    required this.rawUrl,
    required this.protocol,
    required this.host,
    required this.port,
    required this.createdAt,
    this.subscriptionId,
    this.sortOrder,
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
    if (!nullToAbsent || subscriptionId != null) {
      map['subscription_id'] = Variable<int>(subscriptionId);
    }
    if (!nullToAbsent || sortOrder != null) {
      map['sort_order'] = Variable<int>(sortOrder);
    }
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
      subscriptionId: subscriptionId == null && nullToAbsent
          ? const Value.absent()
          : Value(subscriptionId),
      sortOrder: sortOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(sortOrder),
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
      subscriptionId: serializer.fromJson<int?>(json['subscriptionId']),
      sortOrder: serializer.fromJson<int?>(json['sortOrder']),
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
      'subscriptionId': serializer.toJson<int?>(subscriptionId),
      'sortOrder': serializer.toJson<int?>(sortOrder),
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
    Value<int?> subscriptionId = const Value.absent(),
    Value<int?> sortOrder = const Value.absent(),
  }) => ServerRow(
    id: id ?? this.id,
    label: label ?? this.label,
    rawUrl: rawUrl ?? this.rawUrl,
    protocol: protocol ?? this.protocol,
    host: host ?? this.host,
    port: port ?? this.port,
    createdAt: createdAt ?? this.createdAt,
    subscriptionId: subscriptionId.present
        ? subscriptionId.value
        : this.subscriptionId,
    sortOrder: sortOrder.present ? sortOrder.value : this.sortOrder,
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
      subscriptionId: data.subscriptionId.present
          ? data.subscriptionId.value
          : this.subscriptionId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
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
          ..write('createdAt: $createdAt, ')
          ..write('subscriptionId: $subscriptionId, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    rawUrl,
    protocol,
    host,
    port,
    createdAt,
    subscriptionId,
    sortOrder,
  );
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
          other.createdAt == this.createdAt &&
          other.subscriptionId == this.subscriptionId &&
          other.sortOrder == this.sortOrder);
}

class ServerProfilesCompanion extends UpdateCompanion<ServerRow> {
  final Value<int> id;
  final Value<String> label;
  final Value<String> rawUrl;
  final Value<String> protocol;
  final Value<String> host;
  final Value<int> port;
  final Value<DateTime> createdAt;
  final Value<int?> subscriptionId;
  final Value<int?> sortOrder;
  const ServerProfilesCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.rawUrl = const Value.absent(),
    this.protocol = const Value.absent(),
    this.host = const Value.absent(),
    this.port = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.subscriptionId = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  ServerProfilesCompanion.insert({
    this.id = const Value.absent(),
    required String label,
    required String rawUrl,
    required String protocol,
    required String host,
    required int port,
    required DateTime createdAt,
    this.subscriptionId = const Value.absent(),
    this.sortOrder = const Value.absent(),
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
    Expression<int>? subscriptionId,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (rawUrl != null) 'raw_url': rawUrl,
      if (protocol != null) 'protocol': protocol,
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      if (createdAt != null) 'created_at': createdAt,
      if (subscriptionId != null) 'subscription_id': subscriptionId,
      if (sortOrder != null) 'sort_order': sortOrder,
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
    Value<int?>? subscriptionId,
    Value<int?>? sortOrder,
  }) {
    return ServerProfilesCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      rawUrl: rawUrl ?? this.rawUrl,
      protocol: protocol ?? this.protocol,
      host: host ?? this.host,
      port: port ?? this.port,
      createdAt: createdAt ?? this.createdAt,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (subscriptionId.present) {
      map['subscription_id'] = Variable<int>(subscriptionId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
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
          ..write('createdAt: $createdAt, ')
          ..write('subscriptionId: $subscriptionId, ')
          ..write('sortOrder: $sortOrder')
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
  late final $SubscriptionsTable subscriptions = $SubscriptionsTable(this);
  late final $ServerProfilesTable serverProfiles = $ServerProfilesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    subscriptions,
    serverProfiles,
    appSettings,
  ];
}

typedef $$SubscriptionsTableCreateCompanionBuilder =
    SubscriptionsCompanion Function({
      Value<int> id,
      required String name,
      required String url,
      Value<int?> updateIntervalHours,
      Value<int> upload,
      Value<int> download,
      Value<int> total,
      Value<DateTime?> expiresAt,
      Value<DateTime?> lastUpdatedAt,
      required DateTime createdAt,
    });
typedef $$SubscriptionsTableUpdateCompanionBuilder =
    SubscriptionsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> url,
      Value<int?> updateIntervalHours,
      Value<int> upload,
      Value<int> download,
      Value<int> total,
      Value<DateTime?> expiresAt,
      Value<DateTime?> lastUpdatedAt,
      Value<DateTime> createdAt,
    });

final class $$SubscriptionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $SubscriptionsTable, SubscriptionRow> {
  $$SubscriptionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ServerProfilesTable, List<ServerRow>>
  _serverProfilesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.serverProfiles,
    aliasName: 'subscriptions__id__server_profiles__subscription_id',
  );

  $$ServerProfilesTableProcessedTableManager get serverProfilesRefs {
    final manager = $$ServerProfilesTableTableManager(
      $_db,
      $_db.serverProfiles,
    ).filter((f) => f.subscriptionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_serverProfilesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SubscriptionsTableFilterComposer
    extends Composer<_$AppDatabase, $SubscriptionsTable> {
  $$SubscriptionsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updateIntervalHours => $composableBuilder(
    column: $table.updateIntervalHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get upload => $composableBuilder(
    column: $table.upload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get download => $composableBuilder(
    column: $table.download,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdatedAt => $composableBuilder(
    column: $table.lastUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> serverProfilesRefs(
    Expression<bool> Function($$ServerProfilesTableFilterComposer f) f,
  ) {
    final $$ServerProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.serverProfiles,
      getReferencedColumn: (t) => t.subscriptionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServerProfilesTableFilterComposer(
            $db: $db,
            $table: $db.serverProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SubscriptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SubscriptionsTable> {
  $$SubscriptionsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updateIntervalHours => $composableBuilder(
    column: $table.updateIntervalHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get upload => $composableBuilder(
    column: $table.upload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get download => $composableBuilder(
    column: $table.download,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdatedAt => $composableBuilder(
    column: $table.lastUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubscriptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubscriptionsTable> {
  $$SubscriptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<int> get updateIntervalHours => $composableBuilder(
    column: $table.updateIntervalHours,
    builder: (column) => column,
  );

  GeneratedColumn<int> get upload =>
      $composableBuilder(column: $table.upload, builder: (column) => column);

  GeneratedColumn<int> get download =>
      $composableBuilder(column: $table.download, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdatedAt => $composableBuilder(
    column: $table.lastUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> serverProfilesRefs<T extends Object>(
    Expression<T> Function($$ServerProfilesTableAnnotationComposer a) f,
  ) {
    final $$ServerProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.serverProfiles,
      getReferencedColumn: (t) => t.subscriptionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServerProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.serverProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SubscriptionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubscriptionsTable,
          SubscriptionRow,
          $$SubscriptionsTableFilterComposer,
          $$SubscriptionsTableOrderingComposer,
          $$SubscriptionsTableAnnotationComposer,
          $$SubscriptionsTableCreateCompanionBuilder,
          $$SubscriptionsTableUpdateCompanionBuilder,
          (SubscriptionRow, $$SubscriptionsTableReferences),
          SubscriptionRow,
          PrefetchHooks Function({bool serverProfilesRefs})
        > {
  $$SubscriptionsTableTableManager(_$AppDatabase db, $SubscriptionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubscriptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubscriptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubscriptionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<int?> updateIntervalHours = const Value.absent(),
                Value<int> upload = const Value.absent(),
                Value<int> download = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<DateTime?> lastUpdatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SubscriptionsCompanion(
                id: id,
                name: name,
                url: url,
                updateIntervalHours: updateIntervalHours,
                upload: upload,
                download: download,
                total: total,
                expiresAt: expiresAt,
                lastUpdatedAt: lastUpdatedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String url,
                Value<int?> updateIntervalHours = const Value.absent(),
                Value<int> upload = const Value.absent(),
                Value<int> download = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<DateTime?> lastUpdatedAt = const Value.absent(),
                required DateTime createdAt,
              }) => SubscriptionsCompanion.insert(
                id: id,
                name: name,
                url: url,
                updateIntervalHours: updateIntervalHours,
                upload: upload,
                download: download,
                total: total,
                expiresAt: expiresAt,
                lastUpdatedAt: lastUpdatedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SubscriptionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({serverProfilesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (serverProfilesRefs) db.serverProfiles,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (serverProfilesRefs)
                    await $_getPrefetchedData<
                      SubscriptionRow,
                      $SubscriptionsTable,
                      ServerRow
                    >(
                      currentTable: table,
                      referencedTable: $$SubscriptionsTableReferences
                          ._serverProfilesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SubscriptionsTableReferences(
                            db,
                            table,
                            p0,
                          ).serverProfilesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.subscriptionId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SubscriptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubscriptionsTable,
      SubscriptionRow,
      $$SubscriptionsTableFilterComposer,
      $$SubscriptionsTableOrderingComposer,
      $$SubscriptionsTableAnnotationComposer,
      $$SubscriptionsTableCreateCompanionBuilder,
      $$SubscriptionsTableUpdateCompanionBuilder,
      (SubscriptionRow, $$SubscriptionsTableReferences),
      SubscriptionRow,
      PrefetchHooks Function({bool serverProfilesRefs})
    >;
typedef $$ServerProfilesTableCreateCompanionBuilder =
    ServerProfilesCompanion Function({
      Value<int> id,
      required String label,
      required String rawUrl,
      required String protocol,
      required String host,
      required int port,
      required DateTime createdAt,
      Value<int?> subscriptionId,
      Value<int?> sortOrder,
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
      Value<int?> subscriptionId,
      Value<int?> sortOrder,
    });

final class $$ServerProfilesTableReferences
    extends BaseReferences<_$AppDatabase, $ServerProfilesTable, ServerRow> {
  $$ServerProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SubscriptionsTable _subscriptionIdTable(_$AppDatabase db) => db
      .subscriptions
      .createAlias('server_profiles__subscription_id__subscriptions__id');

  $$SubscriptionsTableProcessedTableManager? get subscriptionId {
    final $_column = $_itemColumn<int>('subscription_id');
    if ($_column == null) return null;
    final manager = $$SubscriptionsTableTableManager(
      $_db,
      $_db.subscriptions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subscriptionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$SubscriptionsTableFilterComposer get subscriptionId {
    final $$SubscriptionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subscriptionId,
      referencedTable: $db.subscriptions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubscriptionsTableFilterComposer(
            $db: $db,
            $table: $db.subscriptions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$SubscriptionsTableOrderingComposer get subscriptionId {
    final $$SubscriptionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subscriptionId,
      referencedTable: $db.subscriptions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubscriptionsTableOrderingComposer(
            $db: $db,
            $table: $db.subscriptions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$SubscriptionsTableAnnotationComposer get subscriptionId {
    final $$SubscriptionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subscriptionId,
      referencedTable: $db.subscriptions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubscriptionsTableAnnotationComposer(
            $db: $db,
            $table: $db.subscriptions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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
          (ServerRow, $$ServerProfilesTableReferences),
          ServerRow,
          PrefetchHooks Function({bool subscriptionId})
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
                Value<int?> subscriptionId = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
              }) => ServerProfilesCompanion(
                id: id,
                label: label,
                rawUrl: rawUrl,
                protocol: protocol,
                host: host,
                port: port,
                createdAt: createdAt,
                subscriptionId: subscriptionId,
                sortOrder: sortOrder,
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
                Value<int?> subscriptionId = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
              }) => ServerProfilesCompanion.insert(
                id: id,
                label: label,
                rawUrl: rawUrl,
                protocol: protocol,
                host: host,
                port: port,
                createdAt: createdAt,
                subscriptionId: subscriptionId,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ServerProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({subscriptionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (subscriptionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.subscriptionId,
                                referencedTable: $$ServerProfilesTableReferences
                                    ._subscriptionIdTable(db),
                                referencedColumn:
                                    $$ServerProfilesTableReferences
                                        ._subscriptionIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
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
      (ServerRow, $$ServerProfilesTableReferences),
      ServerRow,
      PrefetchHooks Function({bool subscriptionId})
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
  $$SubscriptionsTableTableManager get subscriptions =>
      $$SubscriptionsTableTableManager(_db, _db.subscriptions);
  $$ServerProfilesTableTableManager get serverProfiles =>
      $$ServerProfilesTableTableManager(_db, _db.serverProfiles);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
