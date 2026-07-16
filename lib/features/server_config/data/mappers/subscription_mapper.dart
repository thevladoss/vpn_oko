import 'package:drift/drift.dart';
import 'package:vpn_osin/features/server_config/data/local/app_database.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription.dart';

Subscription subscriptionRowToEntity(SubscriptionRow row) => Subscription(
  id: row.id,
  name: row.name,
  url: row.url,
  updateIntervalHours: row.updateIntervalHours ?? 0,
  upload: row.upload,
  download: row.download,
  total: row.total,
  expiresAt: row.expiresAt,
  lastUpdatedAt: row.lastUpdatedAt,
  createdAt: row.createdAt,
);

SubscriptionsCompanion subscriptionToCompanion(Subscription subscription) =>
    SubscriptionsCompanion.insert(
      name: subscription.name,
      url: subscription.url,
      updateIntervalHours: Value(subscription.updateIntervalHours),
      upload: Value(subscription.upload),
      download: Value(subscription.download),
      total: Value(subscription.total),
      expiresAt: Value(subscription.expiresAt),
      lastUpdatedAt: Value(subscription.lastUpdatedAt),
      createdAt: subscription.createdAt,
    );
