import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/core/theme/oko_theme.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/cooldown_notice.dart';

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

    await tester.pumpWidget(_host(until, OkoTheme.dark));
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

    await tester.pumpWidget(_host(until, OkoTheme.dark));
    await tester.pump();

    expect(_timeColor(tester), OkoTones.dark.accentTransitional);
    expect(_timeColor(tester), isNot(OkoTones.dark.accentError));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('тон кулдауна — accentTransitional (light)', (tester) async {
    final until = DateTime.now().add(const Duration(minutes: 1));

    await tester.pumpWidget(_host(until, OkoTheme.light));
    await tester.pump();

    expect(_timeColor(tester), OkoTones.light.accentTransitional);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
