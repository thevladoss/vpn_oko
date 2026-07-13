import 'package:equatable/equatable.dart';

enum LogLevel { info, warning, error }

class LogEntry extends Equatable {
  const LogEntry({
    required this.text,
    required this.level,
    required this.time,
  });

  final String text;
  final LogLevel level;
  final DateTime time;

  @override
  List<Object?> get props => [text, level, time];
}
