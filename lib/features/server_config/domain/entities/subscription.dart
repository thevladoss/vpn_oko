import 'package:equatable/equatable.dart';

class Subscription extends Equatable {
  const Subscription({
    required this.id,
    required this.name,
    required this.url,
    required this.updateIntervalHours,
    required this.upload,
    required this.download,
    required this.total,
    required this.expiresAt,
    required this.lastUpdatedAt,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String url;
  final int updateIntervalHours;
  final int upload;
  final int download;
  final int total;
  final DateTime? expiresAt;
  final DateTime? lastUpdatedAt;
  final DateTime createdAt;

  Subscription copyWith({
    int? id,
    String? name,
    String? url,
    int? updateIntervalHours,
    int? upload,
    int? download,
    int? total,
    DateTime? expiresAt,
    DateTime? lastUpdatedAt,
    DateTime? createdAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      updateIntervalHours: updateIntervalHours ?? this.updateIntervalHours,
      upload: upload ?? this.upload,
      download: download ?? this.download,
      total: total ?? this.total,
      expiresAt: expiresAt ?? this.expiresAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    url,
    updateIntervalHours,
    upload,
    download,
    total,
    expiresAt,
    lastUpdatedAt,
    createdAt,
  ];
}
