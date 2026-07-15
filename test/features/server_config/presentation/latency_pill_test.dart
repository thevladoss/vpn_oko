import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/core/theme/oko_theme.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/features/server_config/domain/entities/latency_result.dart';
import 'package:vpn_oko/features/server_config/presentation/widgets/latency_pill.dart';

void main() {
  Widget host(Widget child, {required bool dark}) {
    return MaterialApp(
      theme: dark ? OkoTheme.dark : OkoTheme.light,
      home: Scaffold(body: Center(child: child)),
    );
  }

  Color colorOf(WidgetTester tester, String text) {
    return tester.widget<Text>(find.text(text)).style!.color!;
  }

  group('LatencyPill', () {
    testWidgets('56 ms → accentConnected', (tester) async {
      await tester.pumpWidget(
        host(
          const LatencyPill(
            latency: LatencyMeasured(Duration(milliseconds: 56)),
          ),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('56 ms'), findsOneWidget);
      expect(colorOf(tester, '56 ms'), OkoTones.dark.accentConnected);
    });

    testWidgets('180 ms → accentTransitional', (tester) async {
      await tester.pumpWidget(
        host(
          const LatencyPill(
            latency: LatencyMeasured(Duration(milliseconds: 180)),
          ),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('180 ms'), findsOneWidget);
      expect(colorOf(tester, '180 ms'), OkoTones.dark.accentTransitional);
    });

    testWidgets('420 ms → accentError', (tester) async {
      await tester.pumpWidget(
        host(
          const LatencyPill(
            latency: LatencyMeasured(Duration(milliseconds: 420)),
          ),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('420 ms'), findsOneWidget);
      expect(colorOf(tester, '420 ms'), OkoTones.dark.accentError);
    });

    testWidgets('unreachable → «недоступен» accentError', (tester) async {
      await tester.pumpWidget(
        host(const LatencyPill(latency: LatencyUnreachable()), dark: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('недоступен'), findsOneWidget);
      expect(colorOf(tester, 'недоступен'), OkoTones.dark.accentError);
    });

    testWidgets('null → «…» textSecondary как скелетон', (tester) async {
      await tester.pumpWidget(
        host(const LatencyPill(latency: null), dark: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('…'), findsOneWidget);
      expect(colorOf(tester, '…'), OkoTones.dark.textSecondary);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('рендерится в light-теме без исключений', (tester) async {
      await tester.pumpWidget(
        host(
          const LatencyPill(
            latency: LatencyMeasured(Duration(milliseconds: 56)),
          ),
          dark: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LatencyPill), findsOneWidget);
      expect(colorOf(tester, '56 ms'), OkoTones.light.accentConnected);
    });
  });
}
