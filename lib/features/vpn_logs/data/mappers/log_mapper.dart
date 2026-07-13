import 'package:vpn_oko/core/bridge/vpn_api.g.dart';
import 'package:vpn_oko/features/vpn_logs/domain/entities/log_entry.dart';

LogEntry logToEntity(LogMessage m) => LogEntry(
      text: m.text,
      level: LogLevel.values.firstWhere(
        (l) => l.name == m.level.toLowerCase(),
        orElse: () => LogLevel.info,
      ),
      time: DateTime.fromMillisecondsSinceEpoch(m.timestampMillis),
    );
