import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/features/vpn_logs/domain/entities/log_entry.dart';
import 'package:vpn_oko/features/vpn_logs/domain/usecases/watch_logs.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/bloc/logs_cubit.dart';

class _FakeWatchLogs implements WatchLogs {
  _FakeWatchLogs(this.controller);

  final StreamController<LogEntry> controller;

  @override
  Stream<LogEntry> call() => controller.stream;
}

LogEntry _entry(
  String text, {
  LogLevel level = LogLevel.info,
  DateTime? time,
}) =>
    LogEntry(
      text: text,
      level: level,
      time: time ?? DateTime(2026, 7, 14, 9, 8, 7),
    );

void main() {
  late StreamController<LogEntry> controller;
  late LogsCubit cubit;

  setUp(() {
    controller = StreamController<LogEntry>();
    cubit = LogsCubit(watchLogs: _FakeWatchLogs(controller));
  });

  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
    await controller.close();
  });

  test('appends stream entries in arrival order', () async {
    controller
      ..add(_entry('a'))
      ..add(_entry('b'))
      ..add(_entry('c'));
    await pumpEventQueue();

    expect(cubit.state.entries.map((e) => e.text), ['a', 'b', 'c']);
  });

  test('caps the buffer at 500 dropping the oldest entry', () async {
    for (var i = 0; i <= 500; i++) {
      controller.add(_entry('m$i'));
    }
    await pumpEventQueue();

    expect(cubit.state.entries.length, 500);
    expect(cubit.state.entries.first.text, 'm1');
    expect(cubit.state.entries.last.text, 'm500');
  });

  test('autoScroll defaults to true', () {
    expect(cubit.state.autoScroll, isTrue);
  });

  test('pause and resume emit only when the flag changes', () async {
    final emitted = <bool>[];
    final sub = cubit.stream.listen((s) => emitted.add(s.autoScroll));

    cubit
      ..pauseAutoScroll()
      ..pauseAutoScroll()
      ..resumeAutoScroll()
      ..resumeAutoScroll();
    await pumpEventQueue();
    await sub.cancel();

    expect(emitted, [false, true]);
  });

  test('plainText formats each entry as HH:mm:ss [LEVEL] text', () async {
    controller
      ..add(_entry('hello', time: DateTime(2026, 7, 14, 9, 8, 7)))
      ..add(_entry(
        'careful',
        level: LogLevel.warning,
        time: DateTime(2026, 7, 14, 12, 0, 5),
      ))
      ..add(_entry(
        'boom',
        level: LogLevel.error,
        time: DateTime(2026, 7, 14, 23, 59, 59),
      ));
    await pumpEventQueue();

    expect(
      cubit.plainText(),
      '09:08:07 [INFO] hello\n'
      '12:00:05 [WARNING] careful\n'
      '23:59:59 [ERROR] boom',
    );
  });

  test('close cancels the watchLogs subscription', () async {
    expect(controller.hasListener, isTrue);

    await cubit.close();

    expect(controller.hasListener, isFalse);
  });
}
