import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/theme/oko_theme.dart';
import 'package:vpn_osin/core/theme/oko_tones.dart';
import 'package:vpn_osin/features/server_config/domain/entities/latency_result.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/latency_pill.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/protocol_badge.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/server_list_tile.dart';

void main() {
  Widget host(Widget child, {required bool dark}) {
    return MaterialApp(
      theme: dark ? OkoTheme.dark : OkoTheme.light,
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    );
  }

  bool hasAccentBorder(WidgetTester tester, Color accent) {
    for (final container in tester.widgetList<Container>(
      find.byType(Container),
    )) {
      final decoration = container.decoration;
      if (decoration is BoxDecoration && decoration.border is Border) {
        final border = decoration.border! as Border;
        if (border.top.color == accent && border.top.width == 1.5) {
          return true;
        }
      }
    }
    return false;
  }

  bool hasAccentForegroundBorder(WidgetTester tester, Color accent) {
    for (final container in tester.widgetList<Container>(
      find.byType(Container),
    )) {
      final decoration = container.foregroundDecoration;
      if (decoration is BoxDecoration && decoration.border is Border) {
        final border = decoration.border! as Border;
        if (border.top.color == accent && border.top.width == 1.5) {
          return true;
        }
      }
    }
    return false;
  }

  ServerListTile buildTile({
    required bool active,
    VoidCallback? onSelect,
    VoidCallback? onRename,
    VoidCallback? onDelete,
    LatencyResult? latency,
  }) {
    return ServerListTile(
      dismissKey: const ValueKey('tokyo'),
      name: 'Tokyo',
      host: 'tokyo.example',
      port: 443,
      protocol: 'vless',
      latency: latency,
      active: active,
      onSelect: onSelect ?? () {},
      onRename: onRename ?? () {},
      onDelete: onDelete ?? () {},
    );
  }

  group('ServerListTile', () {
    testWidgets('рендерит имя, host:port, протокол и задержку', (tester) async {
      await tester.pumpWidget(
        host(
          buildTile(
            active: false,
            latency: const LatencyMeasured(Duration(milliseconds: 56)),
          ),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tokyo'), findsOneWidget);
      expect(find.textContaining('tokyo.example:443'), findsOneWidget);
      expect(find.byType(ProtocolBadge), findsOneWidget);
      expect(find.byType(LatencyPill), findsOneWidget);
      expect(find.text('VLESS'), findsOneWidget);
      expect(find.text('56 ms'), findsOneWidget);
    });

    testWidgets('active=true даёт акцентную рамку и Semantics selected', (
      tester,
    ) async {
      await tester.pumpWidget(host(buildTile(active: true), dark: true));
      await tester.pumpAndSettle();

      expect(
        hasAccentForegroundBorder(tester, OkoTones.dark.accentConnected),
        isTrue,
      );
      expect(hasAccentBorder(tester, OkoTones.dark.accentConnected), isFalse);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Tokyo')),
        isSemantics(isSelected: true),
      );
    });

    testWidgets('active=false: без рамки и selected=false', (tester) async {
      await tester.pumpWidget(host(buildTile(active: false), dark: true));
      await tester.pumpAndSettle();

      expect(hasAccentBorder(tester, OkoTones.dark.accentConnected), isFalse);
      expect(
        hasAccentForegroundBorder(tester, OkoTones.dark.accentConnected),
        isFalse,
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(
        tester.getSemantics(find.text('Tokyo')),
        isSemantics(isSelected: false),
      );
    });

    testWidgets('тап по закрытому тайлу вызывает onSelect', (tester) async {
      var selected = false;
      await tester.pumpWidget(
        host(
          buildTile(active: false, onSelect: () => selected = true),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tokyo'));
      await tester.pumpAndSettle();

      expect(selected, isTrue);
    });

    testWidgets('свайп влево открывает панель «Переименовать»/«Удалить»', (
      tester,
    ) async {
      await tester.pumpWidget(host(buildTile(active: false), dark: true));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ServerListTile), const Offset(-260, 0));
      await tester.pumpAndSettle();

      expect(find.text('Переименовать'), findsOneWidget);
      expect(find.text('Удалить'), findsOneWidget);
    });

    testWidgets('тап по «Удалить» открытой панели вызывает onDelete', (
      tester,
    ) async {
      var deleted = false;
      await tester.pumpWidget(
        host(
          buildTile(active: false, onDelete: () => deleted = true),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ServerListTile), const Offset(-260, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });

    testWidgets('тап по «Переименовать» открытой панели вызывает onRename', (
      tester,
    ) async {
      var renamed = false;
      await tester.pumpWidget(
        host(
          buildTile(active: false, onRename: () => renamed = true),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ServerListTile), const Offset(-260, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Переименовать'));
      await tester.pumpAndSettle();

      expect(renamed, isTrue);
    });

    testWidgets('в тайле нет троеточия-меню', (tester) async {
      await tester.pumpWidget(host(buildTile(active: false), dark: true));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
      expect(find.byType(Dismissible), findsNothing);
    });

    testWidgets('рендерится в обеих темах', (tester) async {
      await tester.pumpWidget(host(buildTile(active: true), dark: true));
      await tester.pumpAndSettle();
      expect(find.byType(ServerListTile), findsOneWidget);
      expect(
        hasAccentForegroundBorder(tester, OkoTones.dark.accentConnected),
        isTrue,
      );

      await tester.pumpWidget(host(buildTile(active: true), dark: false));
      await tester.pumpAndSettle();
      expect(find.byType(ServerListTile), findsOneWidget);
      expect(
        hasAccentForegroundBorder(tester, OkoTones.light.accentConnected),
        isTrue,
      );
    });
  });
}
