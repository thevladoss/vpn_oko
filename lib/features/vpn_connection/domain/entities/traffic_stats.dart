import 'package:equatable/equatable.dart';

class TrafficStats extends Equatable {
  const TrafficStats({required this.rxBytes, required this.txBytes});

  final int rxBytes;
  final int txBytes;

  @override
  List<Object?> get props => [rxBytes, txBytes];
}
