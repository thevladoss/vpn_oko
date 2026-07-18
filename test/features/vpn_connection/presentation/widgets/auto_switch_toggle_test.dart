import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vpn_osin/core/theme/osin_theme.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/auto_switch_cubit.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/auto_switch_state.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/auto_switch_toggle.dart';

class MockAutoSwitchCubit extends MockCubit<AutoSwitchState>
    implements AutoSwitchCubit {}

void main() {
  late MockAutoSwitchCubit cubit;

  setUp(() {
    cubit = MockAutoSwitchCubit();
    when(() => cubit.toggle(enabled: any(named: 'enabled')))
        .thenAnswer((_) async {});
  });

  Widget host(AutoSwitchState state, {bool dark = true}) {
    when(() => cubit.state).thenReturn(state);
    return MaterialApp(
      theme: dark ? OsinTheme.dark : OsinTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 340,
            child: BlocProvider<AutoSwitchCubit>.value(
              value: cubit,
              child: const AutoSwitchToggle(),
            ),
          ),
        ),
      ),
    );
  }

  group('AutoSwitchToggle', () {
    testWidgets('available=false: Switch недоступен и приглушённая подпись', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AutoSwitchState()));
      await tester.pumpAndSettle();

      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.onChanged, isNull);
      expect(find.text('Доступно для серверов из подписки'), findsOneWidget);
    });

    testWidgets('available=true, enabled=false: Switch выкл, режим одиночный', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const AutoSwitchState(available: true)),
      );
      await tester.pumpAndSettle();

      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isFalse);
      expect(toggle.onChanged, isNotNull);
      expect(find.text('Одиночный сервер'), findsOneWidget);
    });

    testWidgets('available=true, enabled=true: Switch вкл, режим авто', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const AutoSwitchState(available: true, enabled: true)),
      );
      await tester.pumpAndSettle();

      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isTrue);
      expect(find.text('Автопереключение'), findsOneWidget);
    });

    testWidgets('тап по доступному тумблеру вызывает cubit.toggle', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const AutoSwitchState(available: true)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pump();

      verify(() => cubit.toggle(enabled: true)).called(1);
    });

    testWidgets('available=false: тап по тумблеру ничего не вызывает', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AutoSwitchState()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch), warnIfMissed: false);
      await tester.pump();

      verifyNever(() => cubit.toggle(enabled: any(named: 'enabled')));
    });

    testWidgets('рендерится в обеих темах', (tester) async {
      for (final dark in [true, false]) {
        await tester.pumpWidget(
          host(const AutoSwitchState(available: true), dark: dark),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AutoSwitchToggle), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
