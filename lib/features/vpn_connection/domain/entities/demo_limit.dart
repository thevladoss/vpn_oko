import 'package:equatable/equatable.dart';

const kDemoSessionDuration = Duration(minutes: 5);
const kDemoCooldownDuration = Duration(minutes: 2);

class DemoExpiry extends Equatable {
  const DemoExpiry({required this.cooldownUntil, required this.justExpired});

  final DateTime cooldownUntil;
  final bool justExpired;

  @override
  List<Object?> get props => [cooldownUntil, justExpired];
}
