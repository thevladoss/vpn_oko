import 'dart:async';

import 'package:vpn_oko/features/vpn_logs/data/datasources/log_native_datasource.dart';
import 'package:vpn_oko/features/vpn_logs/domain/entities/log_entry.dart';
import 'package:vpn_oko/features/vpn_logs/domain/repositories/log_repository.dart';

class LogRepositoryImpl implements LogRepository {
  LogRepositoryImpl(this._ds) {
    _subscription = _ds.logs.listen(_onLog);
  }

  static const int _maxBufferSize = 500;

  final LogNativeDatasource _ds;
  final StreamController<LogEntry> _controller =
      StreamController<LogEntry>.broadcast();
  final List<LogEntry> _buffer = <LogEntry>[];
  late final StreamSubscription<LogEntry> _subscription;

  void _onLog(LogEntry entry) {
    _buffer.add(entry);
    if (_buffer.length > _maxBufferSize) {
      _buffer.removeAt(0);
    }
    _controller.add(entry);
  }

  @override
  Stream<LogEntry> watchLogs() async* {
    for (final entry in List<LogEntry>.of(_buffer)) {
      yield entry;
    }
    yield* _controller.stream;
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _controller.close();
  }
}
