import 'package:equatable/equatable.dart';

sealed class VpnState extends Equatable {
  const VpnState();

  @override
  List<Object?> get props => const [];
}

class VpnDisconnected extends VpnState {
  const VpnDisconnected();
}

class VpnConnecting extends VpnState {
  const VpnConnecting();
}

class VpnConnected extends VpnState {
  const VpnConnected({this.connectedSince});

  final DateTime? connectedSince;

  @override
  List<Object?> get props => [connectedSince];
}

class VpnDisconnecting extends VpnState {
  const VpnDisconnecting();
}

class VpnError extends VpnState {
  const VpnError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
