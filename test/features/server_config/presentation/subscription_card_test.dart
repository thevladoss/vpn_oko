import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/theme/osin_theme.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription.dart';
import 'package:vpn_osin/features/server_config/presentation/widgets/subscription_card.dart';

Subscription _sub({
  int upload = 0,
  int download = 0,
  int total = 0,
  DateTime? expiresAt,
}) => Subscription(
  id: 1,
  name: 'Мой провайдер',
  url: 'https://example.com/sub',
  updateIntervalHours: 12,
  upload: upload,
  download: download,
  total: total,
  expiresAt: expiresAt,
  lastUpdatedAt: DateTime(2026, 7, 17),
  createdAt: DateTime(2026, 7, 17),
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: OsinTheme.dark,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('formatDataSize', () {
    test('форматирует байты в человекочитаемые единицы', () {
      expect(formatDataSize(0), '0 Б');
      expect(formatDataSize(512), '512 Б');
      expect(formatDataSize(1024), '1 КБ');
      expect(formatDataSize(1536), '1.5 КБ');
      expect(formatDataSize(1024 * 1024), '1 МБ');
      expect(formatDataSize(5 * 1024 * 1024 * 1024), '5 ГБ');
    });
  });

  group('SubscriptionCard', () {
    testWidgets('показывает имя, остаток трафика и дату истечения', (
      tester,
    ) async {
      await _pump(
        tester,
        SubscriptionCard(
          subscription: _sub(
            upload: 1 * 1024 * 1024 * 1024,
            download: 1 * 1024 * 1024 * 1024,
            total: 10 * 1024 * 1024 * 1024,
            expiresAt: DateTime(2026, 8, 24),
          ),
          busy: false,
          onRefresh: () {},
          onDelete: () {},
        ),
      );

      expect(find.text('Мой провайдер'), findsOneWidget);
      expect(find.textContaining('Осталось 8 ГБ из 10 ГБ'), findsOneWidget);
      expect(find.textContaining('24.08.2026'), findsOneWidget);
    });

    testWidgets('total==0 показывает безлимит и скрывает дату при null', (
      tester,
    ) async {
      await _pump(
        tester,
        SubscriptionCard(
          subscription: _sub(),
          busy: false,
          onRefresh: () {},
          onDelete: () {},
        ),
      );

      expect(find.textContaining('безлимит'), findsOneWidget);
      expect(find.textContaining('До '), findsNothing);
    });

    testWidgets('кнопки refresh и delete вызывают колбэки', (tester) async {
      var refreshed = 0;
      var deleted = 0;
      await _pump(
        tester,
        SubscriptionCard(
          subscription: _sub(),
          busy: false,
          onRefresh: () => refreshed++,
          onDelete: () => deleted++,
        ),
      );

      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pump();

      expect(refreshed, 1);
      expect(deleted, 1);
    });

    testWidgets('busy показывает индикатор вместо кнопки refresh', (
      tester,
    ) async {
      await _pump(
        tester,
        SubscriptionCard(
          subscription: _sub(),
          busy: true,
          onRefresh: () {},
          onDelete: () {},
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    });
  });

}
