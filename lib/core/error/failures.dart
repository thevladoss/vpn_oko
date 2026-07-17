import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable implements Exception {
  const Failure();

  @override
  List<Object?> get props => const [];
}

class VpnStartFailure extends Failure {
  const VpnStartFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  List<Object?> get props => [code, message];
}

class SubscriptionFailure extends Failure {
  const SubscriptionFailure(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}
