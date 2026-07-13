import 'package:flutter/animation.dart';

class OkoMotion {
  const OkoMotion._();

  static const Duration enterScreen = Duration(milliseconds: 350);
  static const Curve enterScreenCurve = Curves.easeOutCubic;

  static const Duration staggerIris = Duration.zero;
  static const Duration staggerServerCard = Duration(milliseconds: 60);
  static const Duration staggerTrafficPanel = Duration(milliseconds: 120);
  static const Duration staggerConnectButton = Duration(milliseconds: 180);
  static const Duration staggerLogConsole = Duration(milliseconds: 240);

  static const Duration statusCrossfade = Duration(milliseconds: 300);
  static const Curve statusCrossfadeCurve = Curves.easeInOut;

  static const Duration pupilOpen = Duration(milliseconds: 600);
  static const Curve pupilOpenCurve = Curves.easeOutBack;

  static const Duration glowBreath = Duration(milliseconds: 4000);
  static const Curve glowBreathCurve = Curves.easeInOut;

  static const Duration segment = Duration(milliseconds: 1200);
  static const Curve segmentCurve = Curves.linear;

  static const Duration ringBreath = Duration(milliseconds: 1600);
  static const Curve ringBreathCurve = Curves.easeInOut;

  static const Duration shake = Duration(milliseconds: 250);

  static const Duration autoscroll = Duration(milliseconds: 200);
  static const Curve autoscrollCurve = Curves.easeOut;
}
