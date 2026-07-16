import 'package:drift/drift.dart';
import 'package:vpn_osin/features/server_config/data/local/app_database.dart';
import 'package:vpn_osin/features/server_config/data/mappers/server_profile_mapper.dart';
import 'package:vpn_osin/features/server_config/data/mappers/subscription_mapper.dart';
import 'package:vpn_osin/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription_import.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription_userinfo.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/subscription_repository.dart';
import 'package:vpn_osin/features/server_config/domain/services/proxy_serializer.dart';

class DriftSubscriptionRepository implements SubscriptionRepository {
  const DriftSubscriptionRepository(this.db);

  final AppDatabase db;

  static const int _settingsId = 0;

  @override
  Stream<List<Subscription>> watchAll() => db
      .select(db.subscriptions)
      .watch()
      .map((rows) => rows.map(subscriptionRowToEntity).toList());

  @override
  Future<Subscription> add(
    Subscription draft,
    List<ImportedProxy> servers,
  ) => db.transaction(() async {
    final row = await db
        .into(db.subscriptions)
        .insertReturning(subscriptionToCompanion(draft));
    final seen = <String>{};
    var order = 0;
    for (final server in servers) {
      final url = proxyConfigToUrl(server.config);
      if (!seen.add(url)) {
        continue;
      }
      await db
          .into(db.serverProfiles)
          .insert(
            profileToCompanion(
              server.config,
              url,
              subscriptionId: row.id,
              sortOrder: order,
            ),
          );
      order++;
    }
    return subscriptionRowToEntity(row);
  });

  @override
  Future<List<ServerProfile>> serversFor(int id) async {
    final rows = await (db.select(
      db.serverProfiles,
    )..where((t) => t.subscriptionId.equals(id))).get();
    return rows.map(rowToProfile).toList();
  }

  @override
  Future<void> updateMeta(
    int id,
    SubscriptionUserInfo info,
    DateTime lastUpdatedAt,
  ) => (db.update(db.subscriptions)..where((t) => t.id.equals(id))).write(
    SubscriptionsCompanion(
      upload: Value(info.upload),
      download: Value(info.download),
      total: Value(info.total),
      expiresAt: Value(info.expiresAt),
      updateIntervalHours: Value(info.updateIntervalHours),
      lastUpdatedAt: Value(lastUpdatedAt),
    ),
  );

  @override
  Future<void> applyDiff(
    int subscriptionId,
    List<ImportedProxy> freshServers,
  ) => db.transaction(() async {
    final existing = await (db.select(
      db.serverProfiles,
    )..where((t) => t.subscriptionId.equals(subscriptionId))).get();
    final existingUrls = existing.map((r) => r.rawUrl).toSet();

    final freshByUrl = <String, ImportedProxy>{};
    for (final server in freshServers) {
      freshByUrl.putIfAbsent(proxyConfigToUrl(server.config), () => server);
    }

    final removeIds = <int>[
      for (final r in existing)
        if (!freshByUrl.containsKey(r.rawUrl)) r.id,
    ];
    if (removeIds.isNotEmpty) {
      await (db.delete(
        db.serverProfiles,
      )..where((t) => t.id.isIn(removeIds))).go();
      await _clearActiveIfRemoved(removeIds);
    }

    var order = existing.length;
    for (final entry in freshByUrl.entries) {
      if (existingUrls.contains(entry.key)) {
        continue;
      }
      await db
          .into(db.serverProfiles)
          .insert(
            profileToCompanion(
              entry.value.config,
              entry.key,
              subscriptionId: subscriptionId,
              sortOrder: order,
            ),
          );
      order++;
    }
  });

  @override
  Future<void> remove(int id) => db.transaction(() async {
    final servers = await (db.select(
      db.serverProfiles,
    )..where((t) => t.subscriptionId.equals(id))).get();
    final ids = servers.map((r) => r.id).toList();
    if (ids.isNotEmpty) {
      await (db.delete(db.serverProfiles)..where((t) => t.id.isIn(ids))).go();
      await _clearActiveIfRemoved(ids);
    }
    await (db.delete(db.subscriptions)..where((t) => t.id.equals(id))).go();
  });

  Future<void> _clearActiveIfRemoved(List<int> removedIds) async {
    final settings = await (db.select(
      db.appSettings,
    )..where((t) => t.id.equals(_settingsId))).getSingleOrNull();
    final active = settings?.activeServerId;
    if (active != null && removedIds.contains(active)) {
      await (db.update(db.appSettings)..where((t) => t.id.equals(_settingsId)))
          .write(const AppSettingsCompanion(activeServerId: Value(null)));
    }
  }
}
