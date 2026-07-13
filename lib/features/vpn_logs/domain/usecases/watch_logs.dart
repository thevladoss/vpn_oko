import 'package:vpn_oko/features/vpn_logs/domain/entities/log_entry.dart';
import 'package:vpn_oko/features/vpn_logs/domain/repositories/log_repository.dart';

class WatchLogs {
  const WatchLogs(this._repository);

  final LogRepository _repository;

  Stream<LogEntry> call() => _repository.watchLogs();
}
