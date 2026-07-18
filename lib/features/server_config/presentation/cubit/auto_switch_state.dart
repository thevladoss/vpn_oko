import 'package:equatable/equatable.dart';

class AutoSwitchState extends Equatable {
  const AutoSwitchState({
    this.enabled = false,
    this.available = false,
  });

  final bool enabled;
  final bool available;

  AutoSwitchState copyWith({
    bool? enabled,
    bool? available,
  }) {
    return AutoSwitchState(
      enabled: enabled ?? this.enabled,
      available: available ?? this.available,
    );
  }

  @override
  List<Object?> get props => [enabled, available];
}
