import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vpn_oko/core/widgets/top_alert.dart';

class TopAlertController extends ChangeNotifier {
  String? _message;
  TopAlertKind _kind = TopAlertKind.success;
  bool _visible = false;
  Timer? _timer;

  String? get message => _message;

  TopAlertKind get kind => _kind;

  bool get visible => _visible;

  void show(
    String message,
    TopAlertKind kind, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _timer?.cancel();
    _message = message;
    _kind = kind;
    _visible = true;
    notifyListeners();
    _timer = Timer(duration, hide);
  }

  void hide() {
    _visible = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
