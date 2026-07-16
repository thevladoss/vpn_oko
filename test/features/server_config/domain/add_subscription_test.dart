import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vpn_osin/core/error/failures.dart';
import 'package:vpn_osin/features/server_config/data/datasources/subscription_remote.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription_import.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription_userinfo.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/subscription_repository.dart';
import 'package:vpn_osin/features/server_config/domain/services/proxy_serializer.dart';
import 'package:vpn_osin/features/server_config/domain/usecases/add_subscription.dart';
import 'package:vpn_osin/features/server_config/domain/usecases/remove_subscription.dart';

class MockSubscriptionRemote extends Mock implements SubscriptionRemote {}

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepository {}

const _uuidA = 'b831381d-6324-4d53-ad4f-8cda48b30811';
const _uuidB = 'a1b2c3d4-e5f6-7890-abcd-ef0123456789';

VlessConfig _cfg(String host, String uuid) => VlessConfig(
  host: host,
  port: 443,
  name: host,
  uuid: uuid,
  transport: 'tcp',
  security: 'none',
);

Subscription _persisted(Subscription draft, int id) => draft.copyWith(id: id);

final _fallbackSubscription = Subscription(
  id: 0,
  name: 'fallback',
  url: 'https://fallback.example',
  updateIntervalHours: 0,
  upload: 0,
  download: 0,
  total: 0,
  expiresAt: null,
  lastUpdatedAt: null,
  createdAt: DateTime(2026),
);

void main() {
  setUpAll(() {
    registerFallbackValue(_fallbackSubscription);
    registerFallbackValue(<ImportedProxy>[]);
  });

  late MockSubscriptionRemote remote;
  late MockSubscriptionRepository repository;
  final now = DateTime(2026, 7, 16, 10, 30);

  AddSubscription buildAdd() =>
      AddSubscription(remote, repository, now: () => now);

  setUp(() {
    remote = MockSubscriptionRemote();
    repository = MockSubscriptionRepository();
    when(() => repository.add(any(), any())).thenAnswer(
      (inv) async =>
          _persisted(inv.positionalArguments[0] as Subscription, 7),
    );
    when(() => repository.remove(any())).thenAnswer((_) async {});
  });

  group('AddSubscription', () {
    test(
      'fetch → parse → add скопом; imported/skipped и name из profileTitle',
      () async {
        const url = 'https://panel.example/sub';
        final cfgA = _cfg('a.example', _uuidA);
        final cfgB = _cfg('b.example', _uuidB);
        final body =
            '${proxyConfigToUrl(cfgA)}\n'
            '${proxyConfigToUrl(cfgB)}\n'
            'this-is-not-a-link';
        final info = SubscriptionUserInfo(
          upload: 100,
          download: 200,
          total: 1000,
          expiresAt: DateTime(2026, 12, 31),
          profileTitle: 'Premium',
          updateIntervalHours: 24,
        );
        when(
          () => remote.fetch(url),
        ).thenAnswer((_) async => SubscriptionFetch(body, info));

        final result = await buildAdd().call(url);

        expect(result.imported, 2);
        expect(result.skipped, 1);
        expect(result.format, SubscriptionFormat.uriList);
        expect(result.subscription.id, 7);

        final captured = verify(
          () => repository.add(captureAny(), captureAny()),
        ).captured;
        final draft = captured[0] as Subscription;
        final servers = captured[1] as List<ImportedProxy>;

        expect(draft.name, 'Premium');
        expect(draft.url, url);
        expect(draft.updateIntervalHours, 24);
        expect(draft.upload, 100);
        expect(draft.download, 200);
        expect(draft.total, 1000);
        expect(draft.expiresAt, DateTime(2026, 12, 31));
        expect(draft.createdAt, now);
        expect(draft.lastUpdatedAt, now);
        expect(servers.length, 2);
        verify(() => remote.fetch(url)).called(1);
      },
    );

    test('name падает на host(url), когда profileTitle пуст', () async {
      const url = 'https://panel.example:8080/sub?token=secret';
      final body = proxyConfigToUrl(_cfg('a.example', _uuidA));
      when(() => remote.fetch(url)).thenAnswer(
        (_) async => SubscriptionFetch(body, const SubscriptionUserInfo()),
      );

      await buildAdd().call(url);

      final draft =
          verify(() => repository.add(captureAny(), any())).captured.single
              as Subscription;
      expect(draft.name, 'panel.example');
      expect(draft.updateIntervalHours, 0);
    });

    test(
      'пустой профиль: imported=0, skipped прокинут, подписка создаётся',
      () async {
        const url = 'https://panel.example/sub';
        when(() => remote.fetch(url)).thenAnswer(
          (_) async => const SubscriptionFetch(
            'vless://broken\nalso-not-a-link',
            SubscriptionUserInfo(),
          ),
        );

        final result = await buildAdd().call(url);

        expect(result.imported, 0);
        expect(result.skipped, 2);
        verify(() => repository.add(any(), any())).called(1);
      },
    );

    test('clash YAML: imported=0, формат в result', () async {
      const url = 'https://panel.example/sub';
      when(() => remote.fetch(url)).thenAnswer(
        (_) async => const SubscriptionFetch(
          'proxies:\n  - name: node\n    server: x.example',
          SubscriptionUserInfo(),
        ),
      );

      final result = await buildAdd().call(url);

      expect(result.imported, 0);
      expect(result.format, SubscriptionFormat.clashYaml);
      verify(() => repository.add(any(), any())).called(1);
    });

    test('ошибка fetch → SubscriptionFailure, репозиторий цел', () async {
      const url = 'https://panel.example/sub';
      when(
        () => remote.fetch(url),
      ).thenThrow(const SubscriptionFetchException('unexpected status', 404));

      await expectLater(
        buildAdd().call(url),
        throwsA(isA<SubscriptionFailure>()),
      );
      verifyNever(() => repository.add(any(), any()));
    });
  });

  group('RemoveSubscription', () {
    test('делегирует repository.remove', () async {
      await RemoveSubscription(repository).call(5);
      verify(() => repository.remove(5)).called(1);
    });
  });
}
