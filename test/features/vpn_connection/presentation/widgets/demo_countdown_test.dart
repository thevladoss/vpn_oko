import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/theme/oko_theme.dart';
import 'package:vpn_osin/core/theme/oko_tones.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/demo_countdown.dart';

Widget _host(
  DateTime deadline,
  ThemeData theme, {
  TextStyle? style,
  TextStyle? warnStyle,
}) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: Center(
      child: DemoCountdown(
        deadline: deadline,
        style: style,
        warnStyle: warnStyle,
      ),
    ),
  ),
);

Color? _timeColor(WidgetTester tester) =>
    tester.widget<Text>(find.textContaining(':')).style?.color;

void main() {
  testWidgets('показывает остаток mm:ss до дедлайна', (tester) async {
    final deadline = DateTime.now().add(
      const Duration(minutes: 4, seconds: 59, milliseconds: 800),
    );

    await tester.pumpWidget(_host(deadline, OkoTheme.dark));
    await tester.pump();

    expect(find.text('04:59'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('выше минуты — спокойный основной стиль', (tester) async {
    final deadline = DateTime.now().add(
      const Duration(minutes: 2, milliseconds: 800),
    );

    await tester.pumpWidget(
      _host(
        deadline,
        OkoTheme.dark,
        style: TextStyle(color: OkoTones.dark.textSecondary),
        warnStyle: TextStyle(color: OkoTones.dark.accentTransitional),
      ),
    );
    await tester.pump();

    expect(_timeColor(tester), OkoTones.dark.textSecondary);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('под минуту — мягкий accentTransitional, не ошибка', (
    tester,
  ) async {
    final deadline = DateTime.now().add(
      const Duration(seconds: 45, milliseconds: 800),
    );

    await tester.pumpWidget(
      _host(
        deadline,
        OkoTheme.dark,
        style: TextStyle(color: OkoTones.dark.textSecondary),
        warnStyle: TextStyle(color: OkoTones.dark.accentTransitional),
      ),
    );
    await tester.pump();

    expect(_timeColor(tester), OkoTones.dark.accentTransitional);
    expect(_timeColor(tester), isNot(OkoTones.dark.accentError));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('дедлайн в прошлом — 00:00 без исключений', (tester) async {
    final past = DateTime.now().subtract(const Duration(seconds: 5));

    await tester.pumpWidget(_host(past, OkoTheme.dark));
    await tester.pump();

    expect(find.text('00:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('00:00'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('светлая тема — спокойный основной стиль', (tester) async {
    final deadline = DateTime.now().add(
      const Duration(minutes: 2, milliseconds: 800),
    );

    await tester.pumpWidget(
      _host(
        deadline,
        OkoTheme.light,
        style: TextStyle(color: OkoTones.light.textSecondary),
        warnStyle: TextStyle(color: OkoTones.light.accentTransitional),
      ),
    );
    await tester.pump();

    expect(_timeColor(tester), OkoTones.light.textSecondary);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('reduce-motion — статичный остаток без таймера', (tester) async {
    final deadline = DateTime.now().add(
      const Duration(minutes: 4, seconds: 59, milliseconds: 800),
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _host(deadline, OkoTheme.dark),
      ),
    );
    await tester.pump();

    expect(find.text('04:59'), findsOneWidget);
  });
}
