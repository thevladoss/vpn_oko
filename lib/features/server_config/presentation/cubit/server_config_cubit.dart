import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_osin/features/server_config/domain/entities/latency_result.dart';
import 'package:vpn_osin/features/server_config/domain/entities/vless_parse_result.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/clipboard_source.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/latency_probe.dart';
import 'package:vpn_osin/features/server_config/domain/services/vless_parser.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/server_config_state.dart';

class ServerConfigCubit extends Cubit<ServerConfigState> {
  ServerConfigCubit({required this.clipboard, required this.probe})
      : super(const ServerConfigInitial());

  final ClipboardSource clipboard;
  final LatencyProbe probe;

  int _generation = 0;

  Future<void> pasteFromClipboard() async {
    final generation = ++_generation;
    final String? raw;
    try {
      raw = await clipboard.readText();
    } on Object {
      if (!isClosed && generation == _generation) {
        emit(const ServerConfigError(VlessError.malformed));
      }
      return;
    }
    if (isClosed || generation != _generation) {
      return;
    }
    if (raw == null || raw.trim().isEmpty) {
      emit(const ServerConfigError(VlessError.empty));
      return;
    }
    switch (parseVless(raw)) {
      case VlessParseFailure(:final error):
        emit(ServerConfigError(error));
      case VlessParsed(:final config):
        emit(ServerConfigLoaded(config));
        final LatencyResult latency;
        try {
          latency = await probe.measure(config.host, config.port);
        } on Object {
          if (!isClosed && generation == _generation) {
            emit(
              ServerConfigLoaded(config, latency: const LatencyUnreachable()),
            );
          }
          return;
        }
        if (isClosed || generation != _generation) {
          return;
        }
        emit(ServerConfigLoaded(config, latency: latency));
    }
  }
}
