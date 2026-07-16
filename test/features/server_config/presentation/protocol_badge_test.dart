import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/theme/oko_theme.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/protocol_badge.dart';

void main() {
  Widget host(Widget child, {required bool dark}) {
    return MaterialApp(
      theme: dark ? OkoTheme.dark : OkoTheme.light,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('ProtocolBadge', () {
    const cases = {
      'vless': 'VLESS',
      'vmess': 'VMESS',
      'trojan': 'TROJAN',
      'ss': 'SS',
      'hysteria2': 'HYSTERIA2',
    };

    for (final entry in cases.entries) {
      testWidgets('${entry.key} рендерит ${entry.value} в пилюле', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(ProtocolBadge(protocol: entry.key), dark: true),
        );
        await tester.pumpAndSettle();

        expect(find.text(entry.value), findsOneWidget);
      });
    }

    testWidgets('рендерится в обеих темах без исключений', (tester) async {
      await tester.pumpWidget(
        host(const ProtocolBadge(protocol: 'vless'), dark: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProtocolBadge), findsOneWidget);
      expect(find.text('VLESS'), findsOneWidget);

      await tester.pumpWidget(
        host(const ProtocolBadge(protocol: 'vless'), dark: false),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProtocolBadge), findsOneWidget);
      expect(find.text('VLESS'), findsOneWidget);
    });
  });
}
