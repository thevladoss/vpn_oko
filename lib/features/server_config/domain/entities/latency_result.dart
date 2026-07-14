import 'package:equatable/equatable.dart';

sealed class LatencyResult extends Equatable {
  const LatencyResult();

  @override
  List<Object?> get props => const [];
}

class LatencyMeasured extends LatencyResult {
  const LatencyMeasured(this.rtt);

  final Duration rtt;

  @override
  List<Object?> get props => [rtt];
}

class LatencyUnreachable extends LatencyResult {
  const LatencyUnreachable();
}
