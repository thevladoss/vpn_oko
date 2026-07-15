import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/core/theme/oko_theme.dart';
import 'package:vpn_oko/features/server_config/domain/entities/latency_result.dart';
import 'package:vpn_oko/features/server_config/presentation/widgets/server_list_tile.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/cooldown_notice.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/demo_countdown.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/demo_expired_overlay.dart';

Widget host(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: MaterialApp(
      theme: OkoTheme.dark,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  final now = DateTime.now();
  final soon = now.add(const Duration(seconds: 90));

  final builders = <String, Widget Function()>{
    'DemoCountdown': () => DemoCountdown(deadline: soon),
    'CooldownNotice': () => CooldownNotice(cooldownUntil: soon),
    'DemoExpiredOverlay': () => SizedBox(
      width: 360,
      height: 720,
      child: Stack(children: [DemoExpiredOverlay(cooldownUntil: soon)]),
    ),
    'ServerListTile': () => SizedBox(
      width: 360,
      child: ServerListTile(
        dismissKey: const ValueKey('reduce-motion'),
        name: 'Tokyo',
        host: 'node.example',
        port: 443,
        protocol: 'vless',
        latency: const LatencyMeasured(Duration(milliseconds: 56)),
        active: true,
        onSelect: () {},
        onRename: () {},
        onDelete: () {},
      ),
    ),
  };

  for (final entry in builders.entries) {
    testWidgets(
      '${entry.key} при disableAnimations рендерится без вечных таймеров',
      (tester) async {
        await tester.pumpWidget(host(entry.value()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: entry.key);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
