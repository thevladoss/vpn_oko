import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/theme/oko_theme.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/empty_server_paste_field.dart';

void main() {
  Widget host(Widget child, {required bool dark}) {
    return MaterialApp(
      theme: dark ? OkoTheme.dark : OkoTheme.light,
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    );
  }

  group('EmptyServerPasteField', () {
    testWidgets('тап зовёт onPaste', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(EmptyServerPasteField(onPaste: () => taps++), dark: true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(EmptyServerPasteField));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('показывает заголовок и подсказку про буфер', (tester) async {
      await tester.pumpWidget(
        host(EmptyServerPasteField(onPaste: () {}), dark: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Добавьте свой первый сервер'), findsOneWidget);
      expect(find.textContaining('вставить'), findsOneWidget);
    });

    testWidgets('не содержит кнопки «Добавить сервер»', (tester) async {
      await tester.pumpWidget(
        host(EmptyServerPasteField(onPaste: () {}), dark: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Добавить сервер'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('рендерится в обеих темах', (tester) async {
      for (final dark in [true, false]) {
        await tester.pumpWidget(
          host(EmptyServerPasteField(onPaste: () {}), dark: dark),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(EmptyServerPasteField), findsOneWidget);
      }
    });

    testWidgets('пунктир рисуется поверх клипающего контента (обе темы)', (
      tester,
    ) async {
      final dashed = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.foregroundPainter.runtimeType.toString() ==
                '_DashedBorderPainter',
      );
      final clippedContent = find.byWidgetPredicate(
        (widget) => widget is Material && widget.clipBehavior == Clip.antiAlias,
      );

      for (final dark in [true, false]) {
        await tester.pumpWidget(
          host(EmptyServerPasteField(onPaste: () {}), dark: dark),
        );
        await tester.pumpAndSettle();

        expect(dashed, findsOneWidget);
        expect(
          find.descendant(of: dashed, matching: clippedContent),
          findsWidgets,
        );
        expect(find.text('Добавьте свой первый сервер'), findsOneWidget);
      }
    });
  });
}
