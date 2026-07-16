import 'package:flutter/material.dart';
import 'package:vpn_oko/core/widgets/top_alert.dart';
import 'package:vpn_oko/core/widgets/top_alert_controller.dart';

class TopAlertOverlay extends StatelessWidget {
  const TopAlertOverlay({required this.controller, super.key});

  final TopAlertController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      top: 8,
      child: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => TopAlert(
            message: controller.message,
            kind: controller.kind,
            visible: controller.visible,
          ),
        ),
      ),
    );
  }
}
