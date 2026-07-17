import 'package:equatable/equatable.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription.dart';

class SubscriptionState extends Equatable {
  const SubscriptionState({
    this.subscriptions = const [],
    this.busyIds = const {},
    this.adding = false,
    this.notice,
  });

  final List<Subscription> subscriptions;
  final Set<int> busyIds;
  final bool adding;
  final SubscriptionNotice? notice;

  SubscriptionState copyWith({
    List<Subscription>? subscriptions,
    Set<int>? busyIds,
    bool? adding,
    SubscriptionNotice? notice,
    bool clearNotice = false,
  }) {
    return SubscriptionState(
      subscriptions: subscriptions ?? this.subscriptions,
      busyIds: busyIds ?? this.busyIds,
      adding: adding ?? this.adding,
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }

  @override
  List<Object?> get props => [subscriptions, busyIds, adding, notice];
}

sealed class SubscriptionNotice extends Equatable {
  const SubscriptionNotice();

  @override
  List<Object?> get props => const [];
}

final class SubImported extends SubscriptionNotice {
  const SubImported(this.imported, this.skipped);

  final int imported;
  final int skipped;

  @override
  List<Object?> get props => [imported, skipped];
}

final class SubRefreshed extends SubscriptionNotice {
  const SubRefreshed(this.imported, this.skipped);

  final int imported;
  final int skipped;

  @override
  List<Object?> get props => [imported, skipped];
}

final class SubRemoved extends SubscriptionNotice {
  const SubRemoved();
}

final class SubUnsupportedFormat extends SubscriptionNotice {
  const SubUnsupportedFormat();
}

final class SubError extends SubscriptionNotice {
  const SubError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
