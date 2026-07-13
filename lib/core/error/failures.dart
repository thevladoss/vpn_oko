import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable implements Exception {
  const Failure();

  @override
  List<Object?> get props => const [];
}

class PlatformFailure extends Failure {
  const PlatformFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class VpnStartFailure extends Failure {
  const VpnStartFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  List<Object?> get props => [code, message];
}
