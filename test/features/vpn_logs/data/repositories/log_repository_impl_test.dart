import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/features/vpn_logs/data/repositories/log_repository_impl.dart';
import 'package:vpn_oko/features/vpn_logs/domain/entities/log_entry.dart';

import '../../../../helpers/fake_log_native_datasource.dart';

LogEntry _entry(String text) => LogEntry(
      text: text,
      level: LogLevel.info,
      time: DateTime.fromMillisecondsSinceEpoch(0),
    );

void main() {
  late FakeLogNativeDatasource fake;
  late LogRepositoryImpl repository;

  setUp(() {
    fake = FakeLogNativeDatasource();
    repository = LogRepositoryImpl(fake);
  });

  tearDown(() async {
    await repository.dispose();
    await fake.dispose();
  });

  group('watchLogs replay', () {
    test('replays buffered entries to a late subscriber', () async {
      fake
        ..emitLog(_entry('a'))
        ..emitLog(_entry('b'));
      await pumpEventQueue();

      final received = <LogEntry>[];
      final subscription = repository.watchLogs().listen(received.add);
      await pumpEventQueue();
      await subscription.cancel();

      expect(received, [_entry('a'), _entry('b')]);
    });

    test('does not drop a log emitted right after listen (race window)',
        () async {
      final received = <LogEntry>[];
      final subscription = repository.watchLogs().listen(received.add);

      fake.emitLog(_entry('live'));
      await pumpEventQueue();
      await subscription.cancel();

      expect(received, [_entry('live')]);
    });

    test('buffer keeps at most the last entries and never duplicates',
        () async {
      fake.emitLog(_entry('buffered'));
      await pumpEventQueue();

      final received = <LogEntry>[];
      final subscription = repository.watchLogs().listen(received.add);
      await pumpEventQueue();

      fake.emitLog(_entry('after'));
      await pumpEventQueue();
      await subscription.cancel();

      expect(received, [_entry('buffered'), _entry('after')]);
    });
  });

  group('dispose', () {
    test('closes the log stream and is safe to call repeatedly', () async {
      var done = false;
      repository.watchLogs().listen((_) {}, onDone: () => done = true);
      await pumpEventQueue();

      await repository.dispose();
      await repository.dispose();
      await pumpEventQueue();

      expect(done, isTrue);
    });
  });
}
