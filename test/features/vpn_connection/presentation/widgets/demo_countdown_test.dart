import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/core/theme/oko_theme.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/demo_countdown.dart';

Widget _host(DateTime deadline) => MaterialApp(
  theme: OkoTheme.dark,
  home: Scaffold(body: Center(child: DemoCountdown(deadline: deadline))),
);

void main() {
  testWidgets('показывает остаток mm:ss до дедлайна', (tester) async {
    final deadline = DateTime.now().add(
      const Duration(seconds: 3, milliseconds: 800),
    );

    await tester.pumpWidget(_host(deadline));
    await tester.pump();

    expect(find.text('00:03'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('за дедлайном показывает 00:00, не уходит в минус', (
    tester,
  ) async {
    final past = DateTime.now().subtract(const Duration(seconds: 5));

    await tester.pumpWidget(_host(past));
    await tester.pump();

    expect(find.text('00:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('00:00'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('reduce-motion: без таймера, статичный остаток', (tester) async {
    final deadline = DateTime.now().add(
      const Duration(seconds: 3, milliseconds: 800),
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _host(deadline),
      ),
    );
    await tester.pump();

    expect(find.text('00:03'), findsOneWidget);
  });
}
