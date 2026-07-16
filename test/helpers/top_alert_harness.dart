import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/core/widgets/top_alert_controller.dart';
import 'package:vpn_oko/core/widgets/top_alert_overlay.dart';
import 'package:vpn_oko/core/widgets/top_alert_scope.dart';

Widget wrapWithTopAlert({
  required Widget home,
  ThemeData? theme,
  TopAlertController? controller,
}) {
  final effectiveController = controller ?? TopAlertController();
  if (controller == null) {
    addTearDown(effectiveController.dispose);
  }
  return TopAlertScope(
    controller: effectiveController,
    child: MaterialApp(
      theme: theme,
      builder: (context, child) => Stack(
        children: [
          ?child,
          TopAlertOverlay(controller: effectiveController),
        ],
      ),
      home: home,
    ),
  );
}
