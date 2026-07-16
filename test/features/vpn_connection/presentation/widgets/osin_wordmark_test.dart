import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/theme/osin_theme.dart';
import 'package:vpn_osin/core/theme/osin_tones.dart';
import 'package:vpn_osin/core/theme/vpn_status.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/osin_wordmark.dart';

Widget _harness(VpnStatus status) => MaterialApp(
      theme: OsinTheme.dark,
      home: Scaffold(body: Center(child: OsinWordmark(status: status))),
    );

BoxDecoration _dot(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byType(OsinWordmark),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  testWidgets('рисует osin с бесточечной i (dotless ı)', (tester) async {
    await tester.pumpWidget(_harness(VpnStatus.connected));
    expect(find.text('osın'), findsOneWidget);
    expect(find.text('osin'), findsNothing);
  });

  testWidgets('акцентная точка круглая и зелёная в Connected', (tester) async {
    await tester.pumpWidget(_harness(VpnStatus.connected));
    await tester.pumpAndSettle();
    final decoration = _dot(tester);
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, OsinTones.dark.accentConnected);
  });

  testWidgets('точка красная в Error', (tester) async {
    await tester.pumpWidget(_harness(VpnStatus.error));
    await tester.pumpAndSettle();
    expect(_dot(tester).color, OsinTones.dark.accentError);
  });

  testWidgets('точка серая в Disconnected', (tester) async {
    await tester.pumpWidget(_harness(VpnStatus.disconnected));
    await tester.pumpAndSettle();
    expect(_dot(tester).color, OsinTones.dark.accentIdle);
  });
}
