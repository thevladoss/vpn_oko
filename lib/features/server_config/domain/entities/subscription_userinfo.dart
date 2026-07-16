import 'package:equatable/equatable.dart';

class SubscriptionUserInfo extends Equatable {
  const SubscriptionUserInfo({
    this.upload = 0,
    this.download = 0,
    this.total = 0,
    this.expiresAt,
    this.profileTitle,
    this.updateIntervalHours,
  });

  final int upload;
  final int download;
  final int total;
  final DateTime? expiresAt;
  final String? profileTitle;
  final int? updateIntervalHours;

  @override
  List<Object?> get props => [
    upload,
    download,
    total,
    expiresAt,
    profileTitle,
    updateIntervalHours,
  ];
}

SubscriptionUserInfo parseSubscriptionUserInfo(
  String? header, {
  String? profileTitle,
  String? profileUpdateInterval,
}) {
  final fields = <String, String>{};
  if (header != null && header.trim().isNotEmpty) {
    for (final part in header.split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      final key = part.substring(0, separator).trim().toLowerCase();
      final value = part.substring(separator + 1).trim();
      if (key.isNotEmpty) {
        fields[key] = value;
      }
    }
  }
  final expireSeconds = int.tryParse(fields['expire'] ?? '');
  final title = profileTitle != null && profileTitle.isNotEmpty
      ? profileTitle
      : null;
  return SubscriptionUserInfo(
    upload: int.tryParse(fields['upload'] ?? '') ?? 0,
    download: int.tryParse(fields['download'] ?? '') ?? 0,
    total: int.tryParse(fields['total'] ?? '') ?? 0,
    expiresAt: expireSeconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(expireSeconds * 1000),
    profileTitle: title,
    updateIntervalHours: int.tryParse(profileUpdateInterval ?? ''),
  );
}
