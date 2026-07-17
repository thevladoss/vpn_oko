import 'package:vpn_osin/core/error/failures.dart';
import 'package:vpn_osin/features/server_config/data/datasources/subscription_remote.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription.dart';
import 'package:vpn_osin/features/server_config/domain/entities/subscription_import.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/subscription_repository.dart';
import 'package:vpn_osin/features/server_config/domain/services/subscription_parser.dart';

class AddSubscriptionResult {
  const AddSubscriptionResult({
    required this.subscription,
    required this.imported,
    required this.skipped,
    required this.format,
  });

  final Subscription subscription;
  final int imported;
  final int skipped;
  final SubscriptionFormat format;
}

class AddSubscription {
  AddSubscription(this._remote, this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final SubscriptionRemote _remote;
  final SubscriptionRepository _repository;
  final DateTime Function() _now;

  Future<AddSubscriptionResult> call(String url) async {
    final SubscriptionFetch fetched;
    try {
      fetched = await _remote.fetch(url);
    } on SubscriptionFetchException catch (error) {
      throw SubscriptionFailure(error.message, statusCode: error.statusCode);
    }

    final parsed = parseSubscription(fetched.body);
    final info = fetched.userInfo;
    final now = _now();
    final draft = Subscription(
      id: 0,
      name: info.profileTitle ?? Uri.parse(url).host,
      url: url,
      updateIntervalHours: info.updateIntervalHours ?? 0,
      upload: info.upload,
      download: info.download,
      total: info.total,
      expiresAt: info.expiresAt,
      lastUpdatedAt: now,
      createdAt: now,
    );

    final subscription = await _repository.add(draft, parsed.servers);
    return AddSubscriptionResult(
      subscription: subscription,
      imported: parsed.servers.length,
      skipped: parsed.skipped,
      format: parsed.format,
    );
  }
}
