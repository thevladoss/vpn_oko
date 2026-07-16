import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/theme/oko_theme.dart';
import 'package:vpn_osin/core/theme/vpn_status.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/status_badge.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      theme: OkoTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );
  }

  const words = <VpnStatus, String>{
    VpnStatus.disconnected: 'Disconnected',
    VpnStatus.connecting: 'Connecting',
    VpnStatus.connected: 'Connected',
    VpnStatus.disconnecting: 'Disconnecting',
    VpnStatus.error: 'Error',
  };

  group('StatusBadge', () {
    for (final entry in words.entries) {
      testWidgets('shows ${entry.value} for ${entry.key.name}',
          (tester) async {
        await tester.pumpWidget(host(StatusBadge(status: entry.key)));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
      });
    }
  });
}
