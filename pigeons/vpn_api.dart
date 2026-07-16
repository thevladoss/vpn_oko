import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/bridge/vpn_api.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/com/example/vpn_osin/bridge/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.example.vpn_osin.bridge'),
    swiftOut: 'ios/Runner/Bridge/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'vpn_osin',
  ),
)
enum VpnStatusMessage { disconnected, connecting, connected, disconnecting, error }

class VpnConfigMessage {
  VpnConfigMessage({
    required this.host,
    required this.port,
    required this.userId,
    required this.serverName,
    required this.singboxConfigJson,
  });

  String host;
  int port;
  String userId;
  String serverName;
  String singboxConfigJson;
}

class VpnStatusSnapshotMessage {
  VpnStatusSnapshotMessage({
    required this.status,
    this.connectedSinceEpochMs,
    required this.rxBytes,
    required this.txBytes,
  });

  VpnStatusMessage status;
  int? connectedSinceEpochMs;
  int rxBytes;
  int txBytes;
  int? sessionEndsAtEpochMs;
  int? cooldownUntilEpochMs;
}

sealed class VpnEventMessage {}

class StatusChangedMessage extends VpnEventMessage {
  StatusChangedMessage({required this.status, this.connectedSinceEpochMs});

  VpnStatusMessage status;
  int? connectedSinceEpochMs;
}

class LogMessage extends VpnEventMessage {
  LogMessage({
    required this.text,
    required this.timestampMillis,
    required this.level,
  });

  String text;
  int timestampMillis;
  String level;
}

class TrafficChangedMessage extends VpnEventMessage {
  TrafficChangedMessage({required this.rxBytes, required this.txBytes});

  int rxBytes;
  int txBytes;
}

class ErrorMessage extends VpnEventMessage {
  ErrorMessage({required this.code, required this.message});

  String code;
  String message;
}

class DemoExpiredMessage extends VpnEventMessage {
  DemoExpiredMessage({required this.cooldownUntilEpochMs});

  int cooldownUntilEpochMs;
}

@HostApi()
abstract class VpnHostApi {
  @async
  void startVpn(VpnConfigMessage config);

  @async
  void stopVpn();

  VpnStatusSnapshotMessage getStatus();
}

@EventChannelApi()
abstract class VpnEventsApi {
  VpnEventMessage vpnEvents();
}
