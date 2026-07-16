import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/theme/oko_theme.dart';
import 'package:vpn_osin/core/theme/oko_tones.dart';
import 'package:vpn_osin/core/widgets/top_alert.dart';

Widget _host(
  Widget child,
  ThemeData theme, {
  bool disableAnimations = false,
}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: Center(child: child),
          );
        },
      ),
    ),
  );
}

void main() {
  group('TopAlert', () {
    testWidgets('success красит в accentConnected и рисует check_circle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const TopAlert(message: 'Готово', visible: true),
          OkoTheme.dark,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Готово'), findsOneWidget);
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.check_circle_rounded),
      );
      expect(icon.color, OkoTones.dark.accentConnected);
    });

    testWidgets('error красит в accentError и рисует error_rounded', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const TopAlert(
            message: 'Дубликат',
            kind: TopAlertKind.error,
            visible: true,
          ),
          OkoTheme.dark,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final icon = tester.widget<Icon>(find.byIcon(Icons.error_rounded));
      expect(icon.color, OkoTones.dark.accentError);
    });

    testWidgets('warning красит в accentTransitional и рисует info_rounded', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const TopAlert(
            message: 'Внимание',
            kind: TopAlertKind.warning,
            visible: true,
          ),
          OkoTheme.dark,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final icon = tester.widget<Icon>(find.byIcon(Icons.info_rounded));
      expect(icon.color, OkoTones.dark.accentTransitional);
    });

    testWidgets('message == null → SizedBox.shrink, без иконки и текста', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const TopAlert(message: null, visible: true),
          OkoTheme.dark,
        ),
      );
      await tester.pump();

      expect(find.byType(Icon), findsNothing);
      expect(find.byType(TopAlert), findsOneWidget);
    });

    testWidgets('рендерится в обеих темах без исключений', (tester) async {
      for (final theme in [OkoTheme.dark, OkoTheme.light]) {
        await tester.pumpWidget(
          _host(
            const TopAlert(
              message: 'Тема',
              kind: TopAlertKind.error,
              visible: true,
            ),
            theme,
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull);
        expect(find.text('Тема'), findsOneWidget);
        expect(find.byIcon(Icons.error_rounded), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
    });

    testWidgets('reduce-motion строит виджет с нулевой длительностью', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const TopAlert(message: 'Без анимаций', visible: true),
          OkoTheme.dark,
          disableAnimations: true,
        ),
      );
      await tester.pump();

      expect(find.text('Без анимаций'), findsOneWidget);
      final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      expect(slide.duration, Duration.zero);
    });
  });
}
