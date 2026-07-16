import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription_userinfo.dart';

void main() {
  group('parseSubscriptionUserInfo', () {
    test('полный заголовок → все поля разобраны', () {
      final info = parseSubscriptionUserInfo(
        'upload=0; download=100000; total=2000000; expire=1749954800',
        profileTitle: 'Мой профиль',
        profileUpdateInterval: '12',
      );

      expect(info.upload, 0);
      expect(info.download, 100000);
      expect(info.total, 2000000);
      expect(
        info.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1749954800 * 1000),
      );
      expect(info.updateIntervalHours, 12);
      expect(info.profileTitle, 'Мой профиль');
    });

    test('отсутствующие поля → 0 и null, без исключения', () {
      final info = parseSubscriptionUserInfo('upload=500');

      expect(info.upload, 500);
      expect(info.download, 0);
      expect(info.total, 0);
      expect(info.expiresAt, isNull);
      expect(info.updateIntervalHours, isNull);
      expect(info.profileTitle, isNull);
    });

    test('пустой заголовок → нулевой SubscriptionUserInfo', () {
      final info = parseSubscriptionUserInfo('');

      expect(info.upload, 0);
      expect(info.download, 0);
      expect(info.total, 0);
      expect(info.expiresAt, isNull);
    });

    test('null-заголовок → нулевой SubscriptionUserInfo', () {
      final info = parseSubscriptionUserInfo(null);

      expect(info, const SubscriptionUserInfo());
    });

    test('мусорный expire → expiresAt = null, счётчики целы', () {
      final info = parseSubscriptionUserInfo(
        'upload=1; download=2; total=3; expire=notanumber',
      );

      expect(info.upload, 1);
      expect(info.download, 2);
      expect(info.total, 3);
      expect(info.expiresAt, isNull);
    });

    test('нечисловой profile-update-interval → null', () {
      final info = parseSubscriptionUserInfo(
        'upload=1',
        profileUpdateInterval: 'weekly',
      );

      expect(info.updateIntervalHours, isNull);
    });

    test('лишние пробелы и регистр ключей допускаются', () {
      final info = parseSubscriptionUserInfo(
        '  Upload = 10 ;  DOWNLOAD=20 ; Total=30 ',
      );

      expect(info.upload, 10);
      expect(info.download, 20);
      expect(info.total, 30);
    });

    test('пустой profileTitle → null', () {
      final info = parseSubscriptionUserInfo('upload=1', profileTitle: '');

      expect(info.profileTitle, isNull);
    });
  });
}
