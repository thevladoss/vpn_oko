import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_oko/features/vpn_logs/domain/entities/log_entry.dart';
import 'package:vpn_oko/features/vpn_logs/domain/usecases/watch_logs.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/bloc/logs_state.dart';

class LogsCubit extends Cubit<LogsState> {
  LogsCubit({required WatchLogs watchLogs}) : super(const LogsState()) {
    _sub = watchLogs().listen(_append);
  }

  static const _cap = 500;

  late final StreamSubscription<LogEntry> _sub;

  void _append(LogEntry entry) {
    final next = [...state.entries, entry];
    if (next.length > _cap) next.removeRange(0, next.length - _cap);
    emit(state.copyWith(entries: next));
  }

  void pauseAutoScroll() {
    if (state.autoScroll) emit(state.copyWith(autoScroll: false));
  }

  void resumeAutoScroll() {
    if (!state.autoScroll) emit(state.copyWith(autoScroll: true));
  }

  String plainText() => state.entries
      .map((e) => '${_hms(e.time)} [${e.level.name.toUpperCase()}] ${e.text}')
      .join('\n');

  String _hms(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Future<void> close() {
    unawaited(_sub.cancel());
    return super.close();
  }
}
