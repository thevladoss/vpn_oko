import 'dart:async';

import 'package:vpn_oko/core/bridge/vpn_api.g.dart';

class VpnBridge {
  VpnBridge({
    required this._hostApi,
    required Stream<VpnEventMessage> events,
  }) {
    _sub = events.listen(_dispatch);
  }

  final VpnHostApi _hostApi;
  late final StreamSubscription<VpnEventMessage> _sub;
  final StreamController<StatusChangedMessage> _status =
      StreamController<StatusChangedMessage>.broadcast();
  final StreamController<LogMessage> _logs =
      StreamController<LogMessage>.broadcast();
  final StreamController<TrafficChangedMessage> _traffic =
      StreamController<TrafficChangedMessage>.broadcast();
  final StreamController<ErrorMessage> _errors =
      StreamController<ErrorMessage>.broadcast();

  Stream<StatusChangedMessage> get statusEvents => _status.stream;
  Stream<LogMessage> get logEvents => _logs.stream;
  Stream<TrafficChangedMessage> get trafficEvents => _traffic.stream;
  Stream<ErrorMessage> get errorEvents => _errors.stream;

  Future<void> startVpn(VpnConfigMessage config) => _hostApi.startVpn(config);

  Future<void> stopVpn() => _hostApi.stopVpn();

  Future<VpnStatusSnapshotMessage> getStatus() => _hostApi.getStatus();

  void _dispatch(VpnEventMessage event) {
    switch (event) {
      case StatusChangedMessage():
        _status.add(event);
      case LogMessage():
        _logs.add(event);
      case TrafficChangedMessage():
        _traffic.add(event);
      case ErrorMessage():
        _errors.add(event);
    }
  }

  Future<void> dispose() async {
    await _sub.cancel();
    await _status.close();
    await _logs.close();
    await _traffic.close();
    await _errors.close();
  }
}
