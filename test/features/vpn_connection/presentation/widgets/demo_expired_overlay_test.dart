import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/core/theme/oko_theme.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/demo_countdown.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/demo_expired_overlay.dart';

void main() {
  testWidgets('оверлей несёт заголовок истечения и вложенный отсчёт', (
    tester,
  ) async {
    final cooldownUntil = DateTime.now().add(const Duration(minutes: 2));

    await tester.pumpWidget(
      MaterialApp(
        theme: OkoTheme.dark,
        home: Scaffold(
          body: Stack(
            children: [DemoExpiredOverlay(cooldownUntil: cooldownUntil)],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Вы исчерпали 5 минут демо подключения'),
      findsOneWidget,
    );
    expect(find.byType(DemoCountdown), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
