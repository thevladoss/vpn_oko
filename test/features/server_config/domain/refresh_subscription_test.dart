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
import 'package:vpn_osin/features/server_config/domain/usecases/refresh_subscription.dart';

class MockSubscriptionRemote extends Mock implements SubscriptionRemote {}

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepository {}

VlessConfig _cfg(String host) => VlessConfig(
  host: host,
  port: 443,
  name: host,
  uuid: 'b831381d-6324-4d53-ad4f-8cda48b30811',
  transport: 'tcp',
  security: 'none',
);

void main() {
  setUpAll(() {
    registerFallbackValue(<ImportedProxy>[]);
    registerFallbackValue(const SubscriptionUserInfo());
    registerFallbackValue(DateTime(2026));
  });

  late MockSubscriptionRemote remote;
  late MockSubscriptionRepository repository;
  final now = DateTime(2026, 7, 16, 12);
  final subscription = Subscription(
    id: 7,
    name: 'Sub',
    url: 'https://panel.example/sub',
    updateIntervalHours: 24,
    upload: 0,
    download: 0,
    total: 0,
    expiresAt: null,
    lastUpdatedAt: null,
    createdAt: DateTime(2026),
  );

  RefreshSubscription build() =>
      RefreshSubscription(remote, repository, now: () => now);

  setUp(() {
    remote = MockSubscriptionRemote();
    repository = MockSubscriptionRepository();
    when(() => repository.applyDiff(any(), any())).thenAnswer((_) async {});
    when(
      () => repository.updateMeta(any(), any(), any()),
    ).thenAnswer((_) async {});
  });

  test('fetch → applyDiff свежих серверов + updateMeta', () async {
    final body = proxyConfigToUrl(_cfg('a.example'));
    const info = SubscriptionUserInfo(upload: 5, download: 6, total: 100);
    when(
      () => remote.fetch(subscription.url),
    ).thenAnswer((_) async => SubscriptionFetch(body, info));

    final result = await build().call(subscription);

    expect(result.imported, 1);
    expect(result.skipped, 0);
    final captured =
        verify(() => repository.applyDiff(7, captureAny())).captured.single
            as List<ImportedProxy>;
    expect(captured.length, 1);
    verify(() => repository.updateMeta(7, info, now)).called(1);
  });

  test('ошибка fetch → SubscriptionFailure, репозиторий не тронут', () async {
    when(() => remote.fetch(subscription.url)).thenThrow(
      const SubscriptionFetchException('boom', 500),
    );

    await expectLater(
      build().call(subscription),
      throwsA(isA<SubscriptionFailure>()),
    );
    verifyNever(() => repository.applyDiff(any(), any()));
    verifyNever(() => repository.updateMeta(any(), any(), any()));
  });
}
