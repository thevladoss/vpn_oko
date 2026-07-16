import 'dart:async';

import 'package:vpn_osin/features/vpn_logs/data/datasources/log_native_datasource.dart';
import 'package:vpn_osin/features/vpn_logs/domain/entities/log_entry.dart';

class FakeLogNativeDatasource implements LogNativeDatasource {
  final StreamController<LogEntry> _logs =
      StreamController<LogEntry>.broadcast();

  void emitLog(LogEntry entry) => _logs.add(entry);

  @override
  Stream<LogEntry> get logs => _logs.stream;

  Future<void> dispose() async {
    await _logs.close();
  }
}
