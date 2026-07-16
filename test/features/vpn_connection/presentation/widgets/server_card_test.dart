import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/theme/oko_theme.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/server_card.dart';

void main() {
  Widget host(Widget child, {required bool dark}) {
    return MaterialApp(
      theme: dark ? OkoTheme.dark : OkoTheme.light,
      home: Scaffold(
        body: Center(child: SizedBox(width: 340, child: child)),
      ),
    );
  }

  group('ServerCard', () {
    testWidgets('onTap задан: тап вызывает колбэк и показывает шеврон', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          ServerCard(
            serverName: 'Tokyo',
            host: 'tokyo.example',
            port: 443,
            onTap: () => taps++,
          ),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      await tester.tap(find.byType(ServerCard));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('onTap == null: шеврона нет и карточка не кликабельна', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const ServerCard(
            serverName: 'Tokyo',
            host: 'tokyo.example',
            port: 443,
          ),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('длинное имя обрезается в 2 строки без переполнения', (
      tester,
    ) async {
      final longName = 'Very Long Server Name ' * 6;
      await tester.pumpWidget(
        host(
          ServerCard(
            serverName: longName,
            host: 'tokyo.example',
            port: 443,
            onTap: () {},
          ),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final title = tester.widget<Text>(find.text(longName));
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
    });

    testWidgets('рендерится в обеих темах', (tester) async {
      for (final dark in [true, false]) {
        await tester.pumpWidget(
          host(
            ServerCard(
              serverName: 'Tokyo',
              host: 'tokyo.example',
              port: 443,
              onTap: () {},
            ),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ServerCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
