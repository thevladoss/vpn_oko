import 'package:equatable/equatable.dart';
import 'package:vpn_osin/features/vpn_logs/domain/entities/log_entry.dart';

class LogsState extends Equatable {
  const LogsState({this.entries = const [], this.autoScroll = true});

  final List<LogEntry> entries;
  final bool autoScroll;

  LogsState copyWith({List<LogEntry>? entries, bool? autoScroll}) => LogsState(
        entries: entries ?? this.entries,
        autoScroll: autoScroll ?? this.autoScroll,
      );

  @override
  List<Object?> get props => [entries, autoScroll];
}
