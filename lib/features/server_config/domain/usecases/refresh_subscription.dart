import 'package:vpn_osin/core/error/failures.dart';
import 'package:vpn_osin/features/server_config/data/datasources/subscription_remote.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription_import.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/subscription_repository.dart';
import 'package:vpn_osin/features/server_config/domain/services/subscription_parser.dart';

class RefreshSubscriptionResult {
  const RefreshSubscriptionResult({
    required this.imported,
    required this.skipped,
    required this.format,
  });

  final int imported;
  final int skipped;
  final SubscriptionFormat format;
}

class RefreshSubscription {
  RefreshSubscription(
    this._remote,
    this._repository, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SubscriptionRemote _remote;
  final SubscriptionRepository _repository;
  final DateTime Function() _now;

  Future<RefreshSubscriptionResult> call(Subscription subscription) async {
    final SubscriptionFetch fetched;
    try {
      fetched = await _remote.fetch(subscription.url);
    } on SubscriptionFetchException catch (error) {
      throw SubscriptionFailure(error.message, statusCode: error.statusCode);
    }

    final parsed = parseSubscription(fetched.body);
    await _repository.applyDiff(subscription.id, parsed.servers);
    await _repository.updateMeta(subscription.id, fetched.userInfo, _now());
    return RefreshSubscriptionResult(
      imported: parsed.servers.length,
      skipped: parsed.skipped,
      format: parsed.format,
    );
  }
}
