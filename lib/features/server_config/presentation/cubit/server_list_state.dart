import 'package:equatable/equatable.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_parse_result.dart';
import 'package:vpn_osin/features/server_config/domain/entities/server_profile.dart';

class ServerListState extends Equatable {
  const ServerListState({
    this.servers = const [],
    this.activeId,
    this.notice,
  });

  final List<ServerProfile> servers;
  final int? activeId;
  final ServerListNotice? notice;

  ServerListState copyWith({
    List<ServerProfile>? servers,
    int? activeId,
    bool clearActiveId = false,
    ServerListNotice? notice,
    bool clearNotice = false,
  }) {
    return ServerListState(
      servers: servers ?? this.servers,
      activeId: clearActiveId ? null : (activeId ?? this.activeId),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }

  @override
  List<Object?> get props => [servers, activeId, notice];
}

sealed class ServerListNotice extends Equatable {
  const ServerListNotice();

  @override
  List<Object?> get props => const [];
}

final class NoticeSaved extends ServerListNotice {
  const NoticeSaved(this.label);

  final String label;

  @override
  List<Object?> get props => [label];
}

final class NoticeDuplicate extends ServerListNotice {
  const NoticeDuplicate(this.label);

  final String label;

  @override
  List<Object?> get props => [label];
}

final class NoticeInvalid extends ServerListNotice {
  const NoticeInvalid(this.error);

  final ProxyParseError error;

  @override
  List<Object?> get props => [error];
}
