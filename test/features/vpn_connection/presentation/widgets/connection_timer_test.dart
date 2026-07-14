import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/core/theme/oko_theme.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/connection_timer.dart';

void main() {
  testWidgets('timer text carries a single soft drop shadow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OkoTheme.dark,
        home: Scaffold(
          body: ConnectionTimer(
            connectedSince: DateTime.now().subtract(const Duration(minutes: 3)),
          ),
        ),
      ),
    );
    await tester.pump();

    final text = tester.widget<Text>(find.byType(Text));
    final shadows = text.style?.shadows;
    expect(shadows, isNotNull);
    expect(shadows, hasLength(1));

    final shadow = shadows!.single;
    expect(shadow.blurRadius, inInclusiveRange(8, 12));
    expect(shadow.offset.dx, 0);
    expect(shadow.offset.dy, closeTo(2, 0.01));
    expect(shadow.color.a, inInclusiveRange(0.25, 0.35));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
