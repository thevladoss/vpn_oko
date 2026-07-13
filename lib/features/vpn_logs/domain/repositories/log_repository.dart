import 'package:vpn_oko/features/vpn_logs/domain/entities/log_entry.dart';

abstract interface class LogRepository {
  Stream<LogEntry> watchLogs();
  Future<void> dispose();
}
