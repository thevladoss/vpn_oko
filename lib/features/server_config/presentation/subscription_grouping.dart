import 'package:equatable/equatable.dart';
import 'package:vpn_osin/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription.dart';

class ServerGroup extends Equatable {
  const ServerGroup({required this.subscription, required this.servers});

  final Subscription? subscription;
  final List<ServerProfile> servers;

  @override
  List<Object?> get props => [subscription, servers];
}

List<ServerGroup> groupServersBySubscription(
  List<ServerProfile> servers,
  List<Subscription> subscriptions,
) {
  final knownIds = {for (final sub in subscriptions) sub.id};
  final bySubscription = <int, List<ServerProfile>>{};
  final ungrouped = <ServerProfile>[];

  for (final server in servers) {
    final id = server.subscriptionId;
    if (id != null && knownIds.contains(id)) {
      bySubscription.putIfAbsent(id, () => []).add(server);
    } else {
      ungrouped.add(server);
    }
  }

  final groups = [
    for (final sub in subscriptions)
      ServerGroup(
        subscription: sub,
        servers: bySubscription[sub.id] ?? const [],
      ),
  ];

  if (ungrouped.isNotEmpty) {
    groups.add(ServerGroup(subscription: null, servers: ungrouped));
  }

  return groups;
}
