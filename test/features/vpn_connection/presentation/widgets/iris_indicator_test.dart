import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/core/theme/oko_theme.dart';
import 'package:vpn_oko/core/theme/vpn_status.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/connection_timer.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/iris_indicator.dart';

void main() {
  Widget host(Widget child, {bool disableAnimations = false}) {
    return MaterialApp(
      theme: OkoTheme.dark,
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: disableAnimations,
            ),
            child: Center(
              child: SizedBox(width: 320, height: 320, child: child),
            ),
          ),
        ),
      ),
    );
  }

  group('IrisIndicator', () {
    testWidgets('renders every status without throwing', (tester) async {
      for (final status in VpnStatus.values) {
        await tester.pumpWidget(
          host(
            IrisIndicator(
              status: status,
              connectedSince:
                  status == VpnStatus.connected ? DateTime.now() : null,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(IrisIndicator), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('builds a static frame under disableAnimations',
        (tester) async {
      await tester.pumpWidget(
        host(
          const IrisIndicator(status: VpnStatus.connecting),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(IrisIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ConnectionTimer', () {
    testWidgets('renders SizedBox.shrink when connectedSince is null',
        (tester) async {
      await tester.pumpWidget(
        host(const ConnectionTimer(connectedSince: null)),
      );
      await tester.pumpAndSettle();
      final box = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(ConnectionTimer),
          matching: find.byType(SizedBox),
        ),
      );
      expect(box.width, 0);
      expect(box.height, 0);
    });
  });
}
