import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_oko/features/server_config/domain/entities/vless_parse_result.dart';
import 'package:vpn_oko/features/server_config/domain/repositories/clipboard_source.dart';
import 'package:vpn_oko/features/server_config/domain/repositories/latency_probe.dart';
import 'package:vpn_oko/features/server_config/domain/services/vless_parser.dart';
import 'package:vpn_oko/features/server_config/presentation/cubit/server_config_state.dart';

class ServerConfigCubit extends Cubit<ServerConfigState> {
  ServerConfigCubit({required this.clipboard, required this.probe})
      : super(const ServerConfigInitial());

  final ClipboardSource clipboard;
  final LatencyProbe probe;

  Future<void> pasteFromClipboard() async {
    final raw = await clipboard.readText();
    if (raw == null || raw.trim().isEmpty) {
      emit(const ServerConfigError(VlessError.empty));
      return;
    }
    switch (parseVless(raw)) {
      case VlessParseFailure(:final error):
        emit(ServerConfigError(error));
      case VlessParsed(:final config):
        emit(ServerConfigLoaded(config));
        final latency = await probe.measure(config.host, config.port);
        emit(ServerConfigLoaded(config, latency: latency));
    }
  }
}
