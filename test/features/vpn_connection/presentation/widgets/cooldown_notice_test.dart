import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/theme/osin_theme.dart';
import 'package:vpn_osin/core/theme/osin_tones.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/cooldown_notice.dart';

Widget _host(DateTime until, ThemeData theme) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: CooldownNotice(cooldownUntil: until))),
);

Color? _timeColor(WidgetTester tester) =>
    tester.widget<Text>(find.textContaining(':')).style?.color;

void main() {
  testWidgets('пилюля «Доступно через M:SS» с живым отсчётом', (tester) async {
    final until = DateTime.now().add(
      const Duration(minutes: 1, seconds: 30, milliseconds: 800),
    );

    await tester.pumpWidget(_host(until, OsinTheme.dark));
    await tester.pump();

    expect(find.textContaining('Доступно через'), findsOneWidget);
    expect(find.text('01:30'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('тон кулдауна — accentTransitional, не ошибка (dark)', (
    tester,
  ) async {
    final until = DateTime.now().add(const Duration(minutes: 1));

    await tester.pumpWidget(_host(until, OsinTheme.dark));
    await tester.pump();

    expect(_timeColor(tester), OsinTones.dark.accentTransitional);
    expect(_timeColor(tester), isNot(OsinTones.dark.accentError));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('тон кулдауна — accentTransitional (light)', (tester) async {
    final until = DateTime.now().add(const Duration(minutes: 1));

    await tester.pumpWidget(_host(until, OsinTheme.light));
    await tester.pump();

    expect(_timeColor(tester), OsinTones.light.accentTransitional);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
