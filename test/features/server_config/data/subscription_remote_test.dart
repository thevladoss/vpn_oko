import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vpn_osin/features/server_config/data/datasources/subscription_remote.dart';

void main() {
  group('SubscriptionRemote.fetch', () {
    test('200 с телом и заголовками → body + разобранный userInfo', () async {
      final client = MockClient((request) async {
        return http.Response(
          'vless://uuid@host:443#Tokyo',
          200,
          headers: {
            'subscription-userinfo':
                'upload=100; download=200; total=1000; expire=1893456000',
            'profile-title': 'My Sub',
            'profile-update-interval': '12',
          },
        );
      });
      final remote = SubscriptionRemote(client);

      final result = await remote.fetch('https://example.com/sub');

      expect(result.body, 'vless://uuid@host:443#Tokyo');
      expect(result.userInfo.upload, 100);
      expect(result.userInfo.download, 200);
      expect(result.userInfo.total, 1000);
      expect(result.userInfo.profileTitle, 'My Sub');
      expect(result.userInfo.updateIntervalHours, 12);
      expect(
        result.userInfo.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1893456000 * 1000),
      );
    });

    test('200 без заголовков → нулевой userInfo, не бросает', () async {
      final client = MockClient((request) async {
        return http.Response('ss://abc@host:8388#Node', 200);
      });
      final remote = SubscriptionRemote(client);

      final result = await remote.fetch('https://example.com/sub');

      expect(result.body, 'ss://abc@host:8388#Node');
      expect(result.userInfo.upload, 0);
      expect(result.userInfo.download, 0);
      expect(result.userInfo.total, 0);
      expect(result.userInfo.expiresAt, isNull);
      expect(result.userInfo.profileTitle, isNull);
      expect(result.userInfo.updateIntervalHours, isNull);
    });

    test('404 → SubscriptionFetchException с кодом', () async {
      final client = MockClient((request) async {
        return http.Response('not found', 404);
      });
      final remote = SubscriptionRemote(client);

      await expectLater(
        () => remote.fetch('https://example.com/missing'),
        throwsA(
          isA<SubscriptionFetchException>().having(
            (e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });

    test('тело больше лимита → SubscriptionFetchException', () async {
      final oversized = 'a' * (600 * 1024);
      final client = MockClient((request) async {
        return http.Response(oversized, 200);
      });
      final remote = SubscriptionRemote(client, maxBodyBytes: 512 * 1024);

      await expectLater(
        () => remote.fetch('https://example.com/big'),
        throwsA(isA<SubscriptionFetchException>()),
      );
    });

    test('таймаут запроса → SubscriptionFetchException', () async {
      final client = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return http.Response('late', 200);
      });
      final remote = SubscriptionRemote(
        client,
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        () => remote.fetch('https://example.com/slow'),
        throwsA(isA<SubscriptionFetchException>()),
      );
    });

    test('исключение не несёт полный URL (не логируем секреты)', () async {
      const url = 'https://panel.example.com/sub?token=SECRET123';
      final client = MockClient((request) async {
        return http.Response('nope', 403);
      });
      final remote = SubscriptionRemote(client);

      try {
        await remote.fetch(url);
        fail('ожидалось исключение');
      } on SubscriptionFetchException catch (e) {
        expect(e.message.contains('SECRET123'), isFalse);
        expect(e.toString().contains('SECRET123'), isFalse);
      }
    });
  });
}
