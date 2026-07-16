import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/theme/osin_theme.dart';
import 'package:vpn_osin/features/server_config/domain/entities/latency_result.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/empty_server_paste_field.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/latency_pill.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/protocol_badge.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/server_list_tile.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/cooldown_notice.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/demo_countdown.dart';
import 'package:vpn_osin/features/vpn_connection/presentation/widgets/demo_expired_overlay.dart';

Widget host(Widget child, ThemeData theme) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: Center(child: child)),
  );
}

ThemeData themeOf(String name) =>
    name == 'dark' ? OsinTheme.dark : OsinTheme.light;

const _expiredTitle = 'Вы исчерпали 5 минут демо подключения';

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

Widget _overlay(DateTime cooldownUntil) {
  return SizedBox(
    width: 360,
    height: 720,
    child: Stack(children: [DemoExpiredOverlay(cooldownUntil: cooldownUntil)]),
  );
}

class _Case {
  const _Case(this.name, this.builder, this.finder);

  final String name;
  final Widget Function() builder;
  final Finder Function() finder;
}

void main() {
  final now = DateTime.now();
  final soon = now.add(const Duration(seconds: 90));
  final past = now.subtract(const Duration(seconds: 1));

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
    _Case(
      'DemoCountdown выше минуты',
      () => DemoCountdown(deadline: soon),
      () => find.byType(DemoCountdown),
    ),
    _Case(
      'DemoCountdown под минуту',
      () => DemoCountdown(
        deadline: now.add(const Duration(seconds: 30)),
        warnStyle: const TextStyle(),
      ),
      () => find.byType(DemoCountdown),
    ),
    _Case(
      'DemoExpiredOverlay кулдаун активен',
      () => _overlay(soon),
      () => find.text(_expiredTitle),
    ),
    _Case(
      'DemoExpiredOverlay кулдаун истёк',
      () => _overlay(past),
      () => find.text(_expiredTitle),
    ),
    _Case(
      'CooldownNotice',
      () => CooldownNotice(cooldownUntil: soon),
      () => find.textContaining('Доступно через'),
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
