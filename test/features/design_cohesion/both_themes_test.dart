import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/theme/osin_theme.dart';
import 'package:vpn_osin/features/server_config/domain/entities/latency_result.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/empty_server_paste_field.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/latency_pill.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/protocol_badge.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/server_list_tile.dart';

Widget host(Widget child, ThemeData theme) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: Center(child: child)),
  );
}

ThemeData themeOf(String name) =>
    name == 'dark' ? OsinTheme.dark : OsinTheme.light;

ServerListTile _tile({required bool active}) {
  return ServerListTile(
    dismissKey: ValueKey(active ? 'active' : 'inactive'),
    name: active ? 'Tokyo' : 'Paris',
    host: 'node.example',
    port: 443,
    protocol: 'vless',
    latency: active ? const LatencyMeasured(Duration(milliseconds: 56)) : null,
    active: active,
    onSelect: () {},
    onRename: () {},
    onDelete: () {},
  );
}

class _Case {
  const _Case(this.name, this.builder, this.finder);

  final String name;
  final Widget Function() builder;
  final Finder Function() finder;
}

void main() {
  final cases = <_Case>[
    _Case(
      'ProtocolBadge',
      () => const ProtocolBadge(protocol: 'vless'),
      () => find.text('VLESS'),
    ),
    _Case(
      'LatencyPill измерена',
      () => const LatencyPill(
        latency: LatencyMeasured(Duration(milliseconds: 56)),
      ),
      () => find.text('56 ms'),
    ),
    _Case(
      'LatencyPill скелетон',
      () => const LatencyPill(latency: null),
      () => find.text('…'),
    ),
    _Case(
      'LatencyPill недоступен',
      () => const LatencyPill(latency: LatencyUnreachable()),
      () => find.text('недоступен'),
    ),
    _Case(
      'ServerListTile active',
      () => SizedBox(width: 360, child: _tile(active: true)),
      () => find.text('Tokyo'),
    ),
    _Case(
      'ServerListTile inactive',
      () => SizedBox(width: 360, child: _tile(active: false)),
      () => find.text('Paris'),
    ),
    _Case(
      'EmptyServerPasteField',
      () => EmptyServerPasteField(onPaste: () {}),
      () => find.text('Добавьте свой первый сервер'),
    ),
  ];

  for (final c in cases) {
    testWidgets('${c.name} рендерится в OsinTheme.dark и OsinTheme.light', (
      tester,
    ) async {
      for (final name in ['dark', 'light']) {
        await tester.pumpWidget(host(c.builder(), themeOf(name)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull, reason: '${c.name} @ $name');
        expect(c.finder(), findsWidgets, reason: '${c.name} @ $name');

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
    });
  }
}
