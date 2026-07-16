import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/widgets/top_alert.dart';
import 'package:vpn_osin/core/widgets/top_alert_controller.dart';

void main() {
  testWidgets('show показывает алерт и авто-скрывает через 2s', (tester) async {
    var notifications = 0;
    final controller = TopAlertController()
      ..addListener(() => notifications++);
    addTearDown(controller.dispose);

    controller.show('Сервер сохранён', TopAlertKind.success);
    expect(controller.visible, isTrue);
    expect(controller.message, 'Сервер сохранён');
    expect(controller.kind, TopAlertKind.success);
    expect(notifications, 1);

    await tester.pump(const Duration(seconds: 2));
    expect(controller.visible, isFalse);
    expect(notifications, 2);
  });

  testWidgets('повторный show отменяет прежний таймер', (tester) async {
    final controller = TopAlertController();
    addTearDown(controller.dispose);

    controller.show('Первый', TopAlertKind.warning);
    await tester.pump(const Duration(seconds: 1));
    expect(controller.visible, isTrue);

    controller.show('Второй', TopAlertKind.error);
    await tester.pump(const Duration(seconds: 1));
    expect(controller.visible, isTrue);
    expect(controller.message, 'Второй');
    expect(controller.kind, TopAlertKind.error);

    await tester.pump(const Duration(seconds: 1));
    expect(controller.visible, isFalse);
  });

  testWidgets('dispose отменяет активный таймер', (tester) async {
    TopAlertController()
      ..show('Сообщение', TopAlertKind.success)
      ..dispose();
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
