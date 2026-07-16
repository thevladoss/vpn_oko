import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/theme/osin_theme.dart';
import 'package:vpn_osin/core/theme/osin_tones.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/cooldown_notice.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/demo_expired_overlay.dart';

const _title = 'Вы исчерпали 5 минут демо подключения';

Widget _host(DateTime until, ThemeData theme, {bool reduceMotion = false}) {
  final app = MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Stack(children: [DemoExpiredOverlay(cooldownUntil: until)]),
    ),
  );
  if (!reduceMotion) {
    return app;
  }
  return MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: app,
  );
}

Color? _timeColor(WidgetTester tester) =>
    tester.widget<Text>(find.textContaining(':')).style?.color;

void main() {
  testWidgets('заголовок истечения и пояснение о лимите', (tester) async {
    final until = DateTime.now().add(const Duration(minutes: 2));

    await tester.pumpWidget(_host(until, OsinTheme.dark));
    await tester.pump();

    expect(find.text(_title), findsOneWidget);
    expect(
      find.textContaining('Демо-сессия ограничена 5 минутами'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('кулдаун «Доступно через …» без активной кнопки Connect', (
    tester,
  ) async {
    final until = DateTime.now().add(
      const Duration(minutes: 1, seconds: 59, milliseconds: 800),
    );

    await tester.pumpWidget(_host(until, OsinTheme.dark));
    await tester.pump();

    expect(find.byType(CooldownNotice), findsOneWidget);
    expect(find.text('01:59'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('тон истечения — спокойный, не accentError (dark)', (
    tester,
  ) async {
    final until = DateTime.now().add(const Duration(minutes: 2));

    await tester.pumpWidget(_host(until, OsinTheme.dark));
    await tester.pump();

    final titleColor = tester.widget<Text>(find.text(_title)).style?.color;
    expect(titleColor, OsinTones.dark.textPrimary);
    expect(titleColor, isNot(OsinTones.dark.accentError));
    expect(_timeColor(tester), OsinTones.dark.accentTransitional);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('светлая тема — заголовок и кулдаун читаются', (tester) async {
    final until = DateTime.now().add(const Duration(minutes: 2));

    await tester.pumpWidget(_host(until, OsinTheme.light));
    await tester.pump();

    expect(find.text(_title), findsOneWidget);
    expect(_timeColor(tester), OsinTones.light.accentTransitional);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('reduce-motion — оверлей виден сразу', (tester) async {
    final until = DateTime.now().add(const Duration(minutes: 2));

    await tester.pumpWidget(_host(until, OsinTheme.dark, reduceMotion: true));
    await tester.pump();

    expect(find.byType(DemoExpiredOverlay), findsOneWidget);
    expect(find.text(_title), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
