import 'package:vpn_oko/core/bridge/vpn_bridge.dart';
import 'package:vpn_oko/features/vpn_logs/data/mappers/log_mapper.dart';
import 'package:vpn_oko/features/vpn_logs/domain/entities/log_entry.dart';

class LogNativeDatasource {
  LogNativeDatasource(this._bridge);

  final VpnBridge _bridge;

  Stream<LogEntry> get logs => _bridge.logEvents.map(logToEntity);
}
