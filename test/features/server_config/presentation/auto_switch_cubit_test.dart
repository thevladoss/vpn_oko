import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/settings_repository.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/auto_switch_cubit.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/auto_switch_state.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late MockSettingsRepository settings;
  late StreamController<bool> controller;

  setUp(() {
    settings = MockSettingsRepository();
    controller = StreamController<bool>.broadcast();
    when(settings.watchAutoSwitch).thenAnswer((_) => controller.stream);
    when(() => settings.setAutoSwitch(enabled: any(named: 'enabled')))
        .thenAnswer((_) async {});
  });

  tearDown(() async {
    await controller.close();
  });

  AutoSwitchCubit build() => AutoSwitchCubit(settings);

  group('watchAutoSwitch', () {
    blocTest<AutoSwitchCubit, AutoSwitchState>(
      'эмитит enabled из хранилища при старте',
      build: build,
      act: (_) => controller.add(true),
      expect: () => [const AutoSwitchState(enabled: true)],
    );

    blocTest<AutoSwitchCubit, AutoSwitchState>(
      'сохраняет available при обновлении enabled из потока',
      build: build,
      seed: () => const AutoSwitchState(available: true),
      act: (_) => controller.add(true),
      expect: () => [const AutoSwitchState(enabled: true, available: true)],
    );
  });

  group('setAvailable', () {
    blocTest<AutoSwitchCubit, AutoSwitchState>(
      'обновляет доступность тумблера',
      build: build,
      act: (cubit) => cubit.setAvailable(available: true),
      expect: () => [const AutoSwitchState(available: true)],
    );

    blocTest<AutoSwitchCubit, AutoSwitchState>(
      'повторный вызов с тем же значением — без нового состояния',
      build: build,
      seed: () => const AutoSwitchState(available: true),
      act: (cubit) => cubit.setAvailable(available: true),
      expect: () => <AutoSwitchState>[],
    );
  });

  group('toggle', () {
    blocTest<AutoSwitchCubit, AutoSwitchState>(
      'available=true: пишет setAutoSwitch и поток отражает включение',
      build: build,
      seed: () => const AutoSwitchState(available: true),
      act: (cubit) async {
        await cubit.toggle(enabled: true);
        controller.add(true);
      },
      expect: () => [const AutoSwitchState(enabled: true, available: true)],
      verify: (_) {
        verify(() => settings.setAutoSwitch(enabled: true)).called(1);
      },
    );

    blocTest<AutoSwitchCubit, AutoSwitchState>(
      'available=false: no-op, ничего не пишет в хранилище',
      build: build,
      act: (cubit) => cubit.toggle(enabled: true),
      expect: () => <AutoSwitchState>[],
      verify: (_) {
        verifyNever(
          () => settings.setAutoSwitch(enabled: any(named: 'enabled')),
        );
      },
    );
  });
}
