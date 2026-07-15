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
  const VpnConnected({this.connectedSince, this.sessionEndsAt});

  final DateTime? connectedSince;
  final DateTime? sessionEndsAt;

  @override
  List<Object?> get props => [connectedSince, sessionEndsAt];
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
