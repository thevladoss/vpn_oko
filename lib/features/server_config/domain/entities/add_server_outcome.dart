import 'package:equatable/equatable.dart';
import 'package:vpn_osin/features/server_config/domain/entities/server_profile.dart';

sealed class AddServerOutcome extends Equatable {
  const AddServerOutcome();

  @override
  List<Object?> get props => const [];
}

final class ServerSaved extends AddServerOutcome {
  const ServerSaved(this.profile);

  final ServerProfile profile;

  @override
  List<Object?> get props => [profile];
}

final class ServerDuplicate extends AddServerOutcome {
  const ServerDuplicate(this.existing);

  final ServerProfile existing;

  @override
  List<Object?> get props => [existing];
}
