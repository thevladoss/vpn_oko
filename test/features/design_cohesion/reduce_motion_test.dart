import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/theme/osin_theme.dart';
import 'package:vpn_osin/features/server_config/domain/entities/latency_result.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/server_list_tile.dart';

Widget host(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: MaterialApp(
      theme: OsinTheme.dark,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  final builders = <String, Widget Function()>{
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
