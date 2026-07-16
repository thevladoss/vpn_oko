import 'package:equatable/equatable.dart';
import 'package:vpn_oko/core/theme/vpn_status.dart';

class VpnConnectionState extends Equatable {
  const VpnConnectionState({
    required this.status,
    this.connectedSince,
    this.rxBytes = 0,
    this.txBytes = 0,
    this.errorMessage,
    this.sessionEndsAt,
    this.cooldownUntil,
    this.demoExpired = false,
    this.noServerNudge = 0,
  });

  final VpnStatus status;
  final DateTime? connectedSince;
  final int rxBytes;
  final int txBytes;
  final String? errorMessage;
  final DateTime? sessionEndsAt;
  final DateTime? cooldownUntil;
  final bool demoExpired;
  final int noServerNudge;

  bool get isBusy =>
      status == VpnStatus.connecting || status == VpnStatus.disconnecting;

  bool get cooldownActive => cooldownUntil != null;

  VpnConnectionState copyWith({
    VpnStatus? status,
    DateTime? connectedSince,
    bool clearConnectedSince = false,
    int? rxBytes,
    int? txBytes,
    String? errorMessage,
    bool clearError = false,
    DateTime? sessionEndsAt,
    bool clearSessionEndsAt = false,
    DateTime? cooldownUntil,
    bool clearCooldown = false,
    bool? demoExpired,
    int? noServerNudge,
  }) {
    return VpnConnectionState(
      status: status ?? this.status,
      connectedSince:
          clearConnectedSince ? null : (connectedSince ?? this.connectedSince),
      rxBytes: rxBytes ?? this.rxBytes,
      txBytes: txBytes ?? this.txBytes,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      sessionEndsAt:
          clearSessionEndsAt ? null : (sessionEndsAt ?? this.sessionEndsAt),
      cooldownUntil:
          clearCooldown ? null : (cooldownUntil ?? this.cooldownUntil),
      demoExpired: demoExpired ?? this.demoExpired,
      noServerNudge: noServerNudge ?? this.noServerNudge,
    );
  }

  @override
  List<Object?> get props => [
        status,
        connectedSince,
        rxBytes,
        txBytes,
        errorMessage,
        sessionEndsAt,
        cooldownUntil,
        demoExpired,
        noServerNudge,
      ];
}
