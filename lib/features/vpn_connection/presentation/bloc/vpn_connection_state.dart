import 'package:equatable/equatable.dart';
import 'package:vpn_oko/core/theme/vpn_status.dart';

class VpnConnectionState extends Equatable {
  const VpnConnectionState({
    required this.status,
    this.connectedSince,
    this.rxBytes = 0,
    this.txBytes = 0,
    this.errorMessage,
  });

  final VpnStatus status;
  final DateTime? connectedSince;
  final int rxBytes;
  final int txBytes;
  final String? errorMessage;

  bool get isBusy =>
      status == VpnStatus.connecting || status == VpnStatus.disconnecting;

  VpnConnectionState copyWith({
    VpnStatus? status,
    DateTime? connectedSince,
    bool clearConnectedSince = false,
    int? rxBytes,
    int? txBytes,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VpnConnectionState(
      status: status ?? this.status,
      connectedSince:
          clearConnectedSince ? null : (connectedSince ?? this.connectedSince),
      rxBytes: rxBytes ?? this.rxBytes,
      txBytes: txBytes ?? this.txBytes,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, connectedSince, rxBytes, txBytes, errorMessage];
}
