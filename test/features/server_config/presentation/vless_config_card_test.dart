import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/core/theme/oko_theme.dart';
import 'package:vpn_oko/features/server_config/domain/entities/latency_result.dart';
import 'package:vpn_oko/features/server_config/domain/entities/vless_config.dart';
import 'package:vpn_oko/features/server_config/domain/entities/vless_parse_result.dart';
import 'package:vpn_oko/features/server_config/presentation/widgets/vless_config_card.dart';
import 'package:vpn_oko/features/server_config/presentation/widgets/vless_error_text.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      theme: OkoTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );
  }

  const config = VlessConfig(
    uuid: 'b831381d-6324-4d53-ad4f-8cda48b30811',
    host: 'example.com',
    port: 443,
    transport: 'tcp',
    security: 'reality',
    sni: 'www.microsoft.com',
    name: 'Tokyo',
  );

  group('VlessConfigCard', () {
    testWidgets('рендерит имя, адрес, transport и security', (tester) async {
      await tester.pumpWidget(host(const VlessConfigCard(config: config)));
      await tester.pumpAndSettle();

      expect(find.text('Tokyo'), findsOneWidget);
      expect(find.textContaining('example.com:443'), findsOneWidget);
      expect(find.textContaining('tcp'), findsOneWidget);
      expect(find.textContaining('reality'), findsOneWidget);
    });

    testWidgets('маскирует uuid: полная строка отсутствует, маска видна', (
      tester,
    ) async {
      await tester.pumpWidget(host(const VlessConfigCard(config: config)));
      await tester.pumpAndSettle();

      expect(find.textContaining('b831381d'), findsNothing);
      expect(find.textContaining('ad4f-8cda48b30811'), findsNothing);
      expect(find.textContaining('••••0811'), findsOneWidget);
    });

    testWidgets('показывает задержку при LatencyMeasured', (tester) async {
      await tester.pumpWidget(
        host(
          const VlessConfigCard(
            config: config,
            latency: LatencyMeasured(Duration(milliseconds: 56)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('56 ms'), findsOneWidget);
    });

    testWidgets('показывает «недоступен» при LatencyUnreachable', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const VlessConfigCard(
            config: config,
            latency: LatencyUnreachable(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('недоступен'), findsOneWidget);
    });

    testWidgets('без задержки строка задержки не рендерится', (tester) async {
      await tester.pumpWidget(host(const VlessConfigCard(config: config)));
      await tester.pumpAndSettle();

      expect(find.textContaining('ms'), findsNothing);
      expect(find.textContaining('недоступен'), findsNothing);
    });

    testWidgets('оборачивает IPv6-хост в скобки', (tester) async {
      const ipv6 = VlessConfig(
        uuid: 'b831381d-6324-4d53-ad4f-8cda48b30811',
        host: '2606:4700:4700::1111',
        port: 8443,
        transport: 'tcp',
        security: 'reality',
        name: 'Cloudflare',
      );
      await tester.pumpWidget(host(const VlessConfigCard(config: ipv6)));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('[2606:4700:4700::1111]:8443'),
        findsOneWidget,
      );
    });
  });

  group('describeVlessError', () {
    for (final error in VlessError.values) {
      test('${error.name} → непустой русский текст', () {
        expect(describeVlessError(error), isNotEmpty);
      });
    }
  });
}
