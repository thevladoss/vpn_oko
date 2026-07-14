import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_oko/features/server_config/domain/repositories/clipboard_source.dart';
import 'package:vpn_oko/features/server_config/domain/repositories/latency_probe.dart';
import 'package:vpn_oko/features/server_config/presentation/cubit/server_config_state.dart';

class ServerConfigCubit extends Cubit<ServerConfigState> {
  ServerConfigCubit({required this.clipboard, required this.probe})
      : super(const ServerConfigInitial());

  final ClipboardSource clipboard;
  final LatencyProbe probe;

  Future<void> pasteFromClipboard() async {}
}
