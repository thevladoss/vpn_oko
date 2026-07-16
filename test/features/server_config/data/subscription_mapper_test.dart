import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/features/server_config/data/local/app_database.dart';
import 'package:vpn_osin/features/server_config/data/mappers/subscription_mapper.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription.dart';

void main() {
  group('subscription_mapper', () {
    final createdAt = DateTime(2026, 7, 10, 8);
    final expiresAt = DateTime(2026, 12, 31);
    final lastUpdatedAt = DateTime(2026, 7, 16, 9, 30);

    test('row → entity переносит все поля', () {
      final row = SubscriptionRow(
        id: 42,
        name: 'Home',
        url: 'https://panel.example/sub',
        updateIntervalHours: 12,
        upload: 100,
        download: 200,
        total: 1000,
        expiresAt: expiresAt,
        lastUpdatedAt: lastUpdatedAt,
        createdAt: createdAt,
      );

      final entity = subscriptionRowToEntity(row);

      expect(entity.id, 42);
      expect(entity.name, 'Home');
      expect(entity.url, 'https://panel.example/sub');
      expect(entity.updateIntervalHours, 12);
      expect(entity.upload, 100);
      expect(entity.download, 200);
      expect(entity.total, 1000);
      expect(entity.expiresAt, expiresAt);
      expect(entity.lastUpdatedAt, lastUpdatedAt);
      expect(entity.createdAt, createdAt);
    });

    test('row → entity → companion roundtrip сохраняет значения', () {
      final row = SubscriptionRow(
        id: 42,
        name: 'Home',
        url: 'https://panel.example/sub',
        updateIntervalHours: 12,
        upload: 100,
        download: 200,
        total: 1000,
        expiresAt: expiresAt,
        lastUpdatedAt: lastUpdatedAt,
        createdAt: createdAt,
      );

      final companion = subscriptionToCompanion(subscriptionRowToEntity(row));

      expect(companion.name.value, 'Home');
      expect(companion.url.value, 'https://panel.example/sub');
      expect(companion.updateIntervalHours.value, 12);
      expect(companion.upload.value, 100);
      expect(companion.download.value, 200);
      expect(companion.total.value, 1000);
      expect(companion.expiresAt.value, expiresAt);
      expect(companion.lastUpdatedAt.value, lastUpdatedAt);
      expect(companion.createdAt.value, createdAt);
      expect(companion.id.present, isFalse);
    });

    test('null updateIntervalHours → 0, null даты → null', () {
      final row = SubscriptionRow(
        id: 1,
        name: 'Bare',
        url: 'https://x/sub',
        upload: 0,
        download: 0,
        total: 0,
        createdAt: createdAt,
      );

      final entity = subscriptionRowToEntity(row);

      expect(entity.updateIntervalHours, 0);
      expect(entity.expiresAt, isNull);
      expect(entity.lastUpdatedAt, isNull);
    });
  });
}
