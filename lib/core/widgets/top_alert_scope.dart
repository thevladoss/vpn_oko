import 'package:flutter/widgets.dart';
import 'package:vpn_osin/core/widgets/top_alert_controller.dart';

class TopAlertScope extends InheritedWidget {
  const TopAlertScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final TopAlertController controller;

  static TopAlertController of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<TopAlertScope>();
    assert(
      scope != null,
      'TopAlertScope.of() requires a TopAlertScope ancestor',
    );
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(TopAlertScope oldWidget) => false;
}
