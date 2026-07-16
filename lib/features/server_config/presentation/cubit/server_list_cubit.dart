import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_osin/features/server_config/domain/entities/add_server_outcome.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_parse_result.dart';
import 'package:vpn_osin/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/clipboard_source.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/server_repository.dart';
import 'package:vpn_osin/features/server_config/domain/services/proxy_parser.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/server_list_state.dart';

class ServerListCubit extends Cubit<ServerListState> {
  ServerListCubit({required this.repository, required this.clipboard})
      : super(const ServerListState()) {
    _allSubscription = repository.watchAll().listen(_onServers);
    _activeSubscription = repository.watchActive().listen(_onActive);
  }

  final ServerRepository repository;
  final ClipboardSource clipboard;

  late final StreamSubscription<List<ServerProfile>> _allSubscription;
  late final StreamSubscription<ServerProfile?> _activeSubscription;

  Future<void> addFromClipboard() async {
    final String? raw;
    try {
      raw = await clipboard.readText();
    } on Object {
      _emitNotice(const NoticeInvalid(ProxyParseError.empty));
      return;
    }
    if (raw == null || raw.trim().isEmpty) {
      _emitNotice(const NoticeInvalid(ProxyParseError.empty));
      return;
    }
    await _addFromRaw(raw);
  }

  Future<void> addFromScan(String raw) => _addFromRaw(raw);

  Future<void> setActive(int id) async {
    try {
      await repository.setActive(id);
    } on Object {
      return;
    }
  }

  Future<void> rename(int id, String label) async {
    try {
      await repository.rename(id, label);
    } on Object {
      return;
    }
  }

  Future<void> delete(int id) async {
    try {
      await repository.delete(id);
    } on Object {
      return;
    }
  }

  Future<void> _addFromRaw(String raw) async {
    final trimmed = raw.trim();
    switch (parseProxyUrl(trimmed)) {
      case ProxyParseFailure(:final error):
        _emitNotice(NoticeInvalid(error));
      case ProxyParsed(:final config):
        final AddServerOutcome outcome;
        try {
          outcome = await repository.add(config, trimmed);
        } on Object {
          _emitNotice(const NoticeInvalid(ProxyParseError.malformed));
          return;
        }
        switch (outcome) {
          case ServerSaved(:final profile):
            _emitNotice(NoticeSaved(profile.label));
          case ServerDuplicate(:final existing):
            _emitNotice(NoticeDuplicate(existing.label));
        }
    }
  }

  void _onServers(List<ServerProfile> servers) {
    if (isClosed) return;
    emit(state.copyWith(servers: servers, clearNotice: true));
  }

  void _onActive(ServerProfile? active) {
    if (isClosed) return;
    emit(
      state.copyWith(
        activeId: active?.id,
        clearActiveId: active == null,
        clearNotice: true,
      ),
    );
  }

  void _emitNotice(ServerListNotice notice) {
    if (isClosed) return;
    emit(state.copyWith(notice: notice));
  }

  @override
  Future<void> close() {
    unawaited(_allSubscription.cancel());
    unawaited(_activeSubscription.cancel());
    return super.close();
  }
}
