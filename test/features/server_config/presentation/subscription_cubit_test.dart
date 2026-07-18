import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vpn_osin/core/error/failures.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription_import.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/subscription_repository.dart';
import 'package:vpn_osin/features/server_config/domain/usecases/add_subscription.dart';
import 'package:vpn_osin/features/server_config/domain/usecases/refresh_subscription.dart';
import 'package:vpn_osin/features/server_config/domain/usecases/remove_subscription.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/subscription_cubit.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/subscription_state.dart';

import '../../../helpers/fake_clipboard_source.dart';

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepository {}

class MockAddSubscription extends Mock implements AddSubscription {}

class MockRefreshSubscription extends Mock implements RefreshSubscription {}

class MockRemoveSubscription extends Mock implements RemoveSubscription {}

final _now = DateTime(2026, 7, 17, 12);

Subscription _sub({
  required int id,
  int updateIntervalHours = 0,
  DateTime? lastUpdatedAt,
}) {
  return Subscription(
    id: id,
    name: 'Sub $id',
    url: 'https://example.com/$id',
    updateIntervalHours: updateIntervalHours,
    upload: 0,
    download: 0,
    total: 0,
    expiresAt: null,
    lastUpdatedAt: lastUpdatedAt,
    createdAt: _now,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_sub(id: 0));
  });

  late MockSubscriptionRepository repository;
  late MockAddSubscription addSubscription;
  late MockRefreshSubscription refreshSubscription;
  late MockRemoveSubscription removeSubscription;
  late FakeClipboardSource clipboard;
  late StreamController<List<Subscription>> controller;

  setUp(() {
    repository = MockSubscriptionRepository();
    addSubscription = MockAddSubscription();
    refreshSubscription = MockRefreshSubscription();
    removeSubscription = MockRemoveSubscription();
    clipboard = FakeClipboardSource();
    controller = StreamController<List<Subscription>>.broadcast();
    when(repository.watchAll).thenAnswer((_) => controller.stream);
  });

  tearDown(() async {
    await controller.close();
  });

  SubscriptionCubit build() => SubscriptionCubit(
        repository: repository,
        addSubscription: addSubscription,
        refreshSubscription: refreshSubscription,
        removeSubscription: removeSubscription,
        clipboard: clipboard,
        now: () => _now,
      );

  group('watchAll', () {
    blocTest<SubscriptionCubit, SubscriptionState>(
      'отражает список подписок из репозитория',
      build: build,
      act: (_) => controller.add([_sub(id: 1), _sub(id: 2)]),
      expect: () => [
        SubscriptionState(subscriptions: [_sub(id: 1), _sub(id: 2)]),
      ],
    );
  });

  group('addFromClipboard', () {
    test('читает буфер и зовёт add', () async {
      clipboard.textToReturn = 'https://sub.example/link';
      when(() => addSubscription('https://sub.example/link')).thenAnswer(
        (_) async => AddSubscriptionResult(
          subscription: _sub(id: 1),
          imported: 1,
          skipped: 0,
          format: SubscriptionFormat.uriList,
        ),
      );
      final cubit = build();

      await cubit.addFromClipboard();

      verify(() => addSubscription('https://sub.example/link')).called(1);
      await cubit.close();
    });

    test('пустой буфер → SubError, add не зовётся', () async {
      clipboard.textToReturn = '   ';
      final cubit = build();

      await cubit.addFromClipboard();

      expect(cubit.state.notice, const SubError('Буфер обмена пуст'));
      verifyNever(() => addSubscription(any()));
      await cubit.close();
    });
  });

  group('add', () {
    blocTest<SubscriptionCubit, SubscriptionState>(
      'успех → SubImported(imported, skipped)',
      setUp: () {
        when(() => addSubscription(any())).thenAnswer(
          (_) async => AddSubscriptionResult(
            subscription: _sub(id: 1),
            imported: 3,
            skipped: 1,
            format: SubscriptionFormat.uriList,
          ),
        );
      },
      build: build,
      act: (cubit) => cubit.add('https://example.com/1'),
      expect: () => [
        const SubscriptionState(adding: true),
        const SubscriptionState(adding: true, notice: SubImported(3, 1)),
        const SubscriptionState(notice: SubImported(3, 1)),
      ],
    );

    blocTest<SubscriptionCubit, SubscriptionState>(
      'clashYaml → SubUnsupportedFormat',
      setUp: () {
        when(() => addSubscription(any())).thenAnswer(
          (_) async => AddSubscriptionResult(
            subscription: _sub(id: 1),
            imported: 0,
            skipped: 0,
            format: SubscriptionFormat.clashYaml,
          ),
        );
      },
      build: build,
      act: (cubit) => cubit.add('https://example.com/1'),
      expect: () => [
        const SubscriptionState(adding: true),
        const SubscriptionState(
          adding: true,
          notice: SubUnsupportedFormat(),
        ),
        const SubscriptionState(notice: SubUnsupportedFormat()),
      ],
    );

    blocTest<SubscriptionCubit, SubscriptionState>(
      'ошибка usecase → SubError, cubit жив',
      setUp: () {
        when(() => addSubscription(any())).thenThrow(
          const SubscriptionFailure('boom', statusCode: 500),
        );
      },
      build: build,
      act: (cubit) => cubit.add('https://example.com/1'),
      expect: () => [
        const SubscriptionState(adding: true),
        const SubscriptionState(adding: true, notice: SubError('boom')),
        const SubscriptionState(notice: SubError('boom')),
      ],
    );
  });

  group('refresh', () {
    blocTest<SubscriptionCubit, SubscriptionState>(
      'успех → busyIds → SubRefreshed',
      setUp: () {
        when(() => refreshSubscription(any())).thenAnswer(
          (_) async => const RefreshSubscriptionResult(
            imported: 5,
            skipped: 2,
            format: SubscriptionFormat.uriList,
          ),
        );
      },
      build: build,
      seed: () => SubscriptionState(subscriptions: [_sub(id: 1)]),
      act: (cubit) => cubit.refresh(1),
      expect: () => [
        SubscriptionState(subscriptions: [_sub(id: 1)], busyIds: const {1}),
        SubscriptionState(
          subscriptions: [_sub(id: 1)],
          busyIds: const {1},
          notice: const SubRefreshed(5, 2),
        ),
        SubscriptionState(
          subscriptions: [_sub(id: 1)],
          notice: const SubRefreshed(5, 2),
        ),
      ],
    );

    blocTest<SubscriptionCubit, SubscriptionState>(
      'ошибка → SubError',
      setUp: () {
        when(() => refreshSubscription(any())).thenThrow(
          const SubscriptionFailure('net down'),
        );
      },
      build: build,
      seed: () => SubscriptionState(subscriptions: [_sub(id: 1)]),
      act: (cubit) => cubit.refresh(1),
      expect: () => [
        SubscriptionState(subscriptions: [_sub(id: 1)], busyIds: const {1}),
        SubscriptionState(
          subscriptions: [_sub(id: 1)],
          busyIds: const {1},
          notice: const SubError('net down'),
        ),
        SubscriptionState(
          subscriptions: [_sub(id: 1)],
          notice: const SubError('net down'),
        ),
      ],
    );
  });

  group('remove', () {
    blocTest<SubscriptionCubit, SubscriptionState>(
      'успех → SubRemoved',
      setUp: () {
        when(() => removeSubscription(any())).thenAnswer((_) async {});
      },
      build: build,
      act: (cubit) => cubit.remove(7),
      expect: () => [
        const SubscriptionState(notice: SubRemoved()),
      ],
      verify: (_) {
        verify(() => removeSubscription(7)).called(1);
      },
    );

    blocTest<SubscriptionCubit, SubscriptionState>(
      'ошибка → SubError',
      setUp: () {
        when(() => removeSubscription(any()))
            .thenThrow(const SubscriptionFailure('cannot delete'));
      },
      build: build,
      act: (cubit) => cubit.remove(7),
      expect: () => [
        const SubscriptionState(notice: SubError('cannot delete')),
      ],
    );
  });

  group('refreshStaleOnOpen', () {
    test('рефрешит только устаревшие подписки', () async {
      when(() => refreshSubscription(any())).thenAnswer(
        (_) async => const RefreshSubscriptionResult(
          imported: 1,
          skipped: 0,
          format: SubscriptionFormat.uriList,
        ),
      );
      final stale = _sub(
        id: 1,
        updateIntervalHours: 12,
        lastUpdatedAt: _now.subtract(const Duration(hours: 24)),
      );
      final fresh = _sub(
        id: 2,
        updateIntervalHours: 12,
        lastUpdatedAt: _now.subtract(const Duration(hours: 1)),
      );
      final neverUpdated = _sub(id: 3);

      final cubit = build();
      controller.add([stale, fresh, neverUpdated]);
      await cubit.refreshStaleOnOpen();

      verify(() => refreshSubscription(stale)).called(1);
      verify(() => refreshSubscription(neverUpdated)).called(1);
      verifyNever(() => refreshSubscription(fresh));

      await cubit.close();
    });
  });
}
