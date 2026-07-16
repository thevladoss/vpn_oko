import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:vpn_osin/features/server_config/domain/entities/subscription_userinfo.dart';

class SubscriptionFetch {
  const SubscriptionFetch(this.body, this.userInfo);

  final String body;
  final SubscriptionUserInfo userInfo;
}

class SubscriptionFetchException implements Exception {
  const SubscriptionFetchException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode == null
      ? 'SubscriptionFetchException: $message'
      : 'SubscriptionFetchException($statusCode): $message';
}

class SubscriptionRemote {
  const SubscriptionRemote(
    this._client, {
    this.maxBodyBytes = 512 * 1024,
    this.timeout = const Duration(seconds: 15),
  });

  final http.Client _client;
  final int maxBodyBytes;
  final Duration timeout;

  Future<SubscriptionFetch> fetch(String url) async {
    final http.Response response;
    try {
      response = await _client.get(Uri.parse(url)).timeout(timeout);
    } on TimeoutException {
      throw const SubscriptionFetchException('request timed out');
    } on http.ClientException {
      throw const SubscriptionFetchException('network error');
    }

    if (response.statusCode != 200) {
      throw SubscriptionFetchException(
        'unexpected status',
        response.statusCode,
      );
    }
    if (response.bodyBytes.length > maxBodyBytes) {
      throw const SubscriptionFetchException('response body too large');
    }

    final headers = response.headers;
    final userInfo = parseSubscriptionUserInfo(
      headers['subscription-userinfo'],
      profileTitle: headers['profile-title'],
      profileUpdateInterval: headers['profile-update-interval'],
    );
    return SubscriptionFetch(response.body, userInfo);
  }
}
