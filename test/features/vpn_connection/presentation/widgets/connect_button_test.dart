import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/core/theme/oko_theme.dart';
import 'package:vpn_oko/core/theme/vpn_status.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/connect_button.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      theme: OkoTheme.dark,
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  group('ConnectButton', () {
    testWidgets('disconnected shows Connect and fires onConnect on tap',
        (tester) async {
      var connectTaps = 0;
      await tester.pumpWidget(
        host(
          ConnectButton(
            status: VpnStatus.disconnected,
            onConnect: () => connectTaps++,
            onDisconnect: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Connect'), findsOneWidget);
      await tester.tap(find.byType(ConnectButton));
      await tester.pump();
      expect(connectTaps, 1);
    });

    testWidgets('connected shows Disconnect and fires onDisconnect on tap',
        (tester) async {
      var disconnectTaps = 0;
      await tester.pumpWidget(
        host(
          ConnectButton(
            status: VpnStatus.connected,
            onConnect: () {},
            onDisconnect: () => disconnectTaps++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Disconnect'), findsOneWidget);
      await tester.tap(find.byType(ConnectButton));
      await tester.pump();
      expect(disconnectTaps, 1);
    });

    testWidgets('error shows Retry and fires onConnect on tap', (tester) async {
      var connectTaps = 0;
      await tester.pumpWidget(
        host(
          ConnectButton(
            status: VpnStatus.error,
            onConnect: () => connectTaps++,
            onDisconnect: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.byType(ConnectButton));
      await tester.pump();
      expect(connectTaps, 1);
    });

    testWidgets('connecting is disabled and ignores taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          ConnectButton(
            status: VpnStatus.connecting,
            onConnect: () => taps++,
            onDisconnect: () => taps++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ConnectButton), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('disconnecting is disabled and ignores taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          ConnectButton(
            status: VpnStatus.disconnecting,
            onConnect: () => taps++,
            onDisconnect: () => taps++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ConnectButton), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
    });
  });
}
