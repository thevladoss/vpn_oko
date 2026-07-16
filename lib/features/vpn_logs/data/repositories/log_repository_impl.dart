import 'dart:async';

import 'package:vpn_osin/features/vpn_logs/data/datasources/log_native_datasource.dart';
import 'package:vpn_osin/features/vpn_logs/domain/entities/log_entry.dart';
import 'package:vpn_osin/features/vpn_logs/domain/repositories/log_repository.dart';

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
  Stream<LogEntry> watchLogs() {
    late final StreamController<LogEntry> output;
    StreamSubscription<LogEntry>? forwarding;
    output = StreamController<LogEntry>(
      onListen: () {
        forwarding = _controller.stream.listen(
          output.add,
          onError: output.addError,
          onDone: output.close,
        );
        List<LogEntry>.of(_buffer).forEach(output.add);
      },
      onCancel: () => forwarding?.cancel(),
    );
    return output.stream;
  }

  @override
  Future<void> dispose() async {
    await _subscription.cancel();
    await _controller.close();
  }
}
