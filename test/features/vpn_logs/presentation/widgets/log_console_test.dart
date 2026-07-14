import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/core/theme/oko_theme.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/features/vpn_logs/domain/entities/log_entry.dart';
import 'package:vpn_oko/features/vpn_logs/domain/usecases/watch_logs.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/bloc/logs_cubit.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/widgets/log_console.dart';
import 'package:vpn_oko/features/vpn_logs/presentation/widgets/log_line.dart';

class _FakeWatchLogs implements WatchLogs {
  _FakeWatchLogs(this.controller);

  final StreamController<LogEntry> controller;

  @override
  Stream<LogEntry> call() => controller.stream;
}

LogEntry _entry(String text, {LogLevel level = LogLevel.info}) => LogEntry(
      text: text,
      level: level,
      time: DateTime(2026, 7, 14, 9, 8, 7),
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

  void enlarge(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget consoleHost() => BlocProvider<LogsCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: OkoTheme.dark,
          home: const Scaffold(body: LogConsole()),
        ),
      );

  Future<void> tapHeader(WidgetTester tester) async {
    await tester.tap(find.text('Logs'));
    await tester.pumpAndSettle();
  }

  double listHeight(WidgetTester tester) =>
      tester.getSize(find.byType(ListView)).height;

  group('LogConsole', () {
    test('collapsed height is 64', () {
      expect(LogConsole.collapsedHeight, 64);
    });

    testWidgets('shows no expand chevron in the header', (tester) async {
      enlarge(tester);
      controller.add(_entry('alpha'));
      await tester.pumpWidget(consoleHost());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_less_rounded), findsNothing);
      expect(find.byIcon(Icons.expand_more_rounded), findsNothing);

      await tapHeader(tester);

      expect(find.byIcon(Icons.expand_less_rounded), findsNothing);
      expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
    });

    testWidgets('renders one LogLine per buffered entry once expanded',
        (tester) async {
      enlarge(tester);
      controller
        ..add(_entry('alpha'))
        ..add(_entry('beta', level: LogLevel.warning))
        ..add(_entry('gamma', level: LogLevel.error));
      await tester.pumpWidget(consoleHost());
      await tester.pumpAndSettle();
      await tapHeader(tester);

      expect(find.byType(LogLine), findsNWidgets(3));
    });

    testWidgets('shows Waiting for events for an empty expanded panel',
        (tester) async {
      enlarge(tester);
      await tester.pumpWidget(consoleHost());
      await tester.pumpAndSettle();
      await tapHeader(tester);

      expect(find.text('Waiting for events'), findsOneWidget);
      expect(
        find.text('Tunnel logs stream here in real time.'),
        findsOneWidget,
      );
      expect(find.byType(LogLine), findsNothing);
    });

    testWidgets('a tap on the header expands the panel', (tester) async {
      enlarge(tester);
      controller.add(_entry('alpha'));
      await tester.pumpWidget(consoleHost());
      await tester.pumpAndSettle();

      expect(listHeight(tester), 0);

      await tapHeader(tester);

      expect(listHeight(tester), greaterThan(0));
      expect(find.byType(LogLine), findsOneWidget);
    });

    testWidgets('a swipe up on the header expands the panel', (tester) async {
      enlarge(tester);
      controller.add(_entry('alpha'));
      await tester.pumpWidget(consoleHost());
      await tester.pumpAndSettle();

      expect(listHeight(tester), 0);

      await tester.drag(find.text('Logs'), const Offset(0, -900));
      await tester.pumpAndSettle();

      expect(listHeight(tester), greaterThan(0));
    });

    testWidgets(
        'a drag on the header expands the panel without scrolling the list',
        (tester) async {
      enlarge(tester);
      for (var i = 0; i < 20; i++) {
        controller.add(_entry('line $i'));
      }
      await tester.pumpWidget(consoleHost());
      await tester.pumpAndSettle();

      expect(listHeight(tester), 0);

      await tester.drag(find.text('Logs'), const Offset(0, -900));
      await tester.pumpAndSettle();

      expect(listHeight(tester), greaterThan(0));
      expect(find.byType(LogLine), findsWidgets);
      expect(cubit.state.autoScroll, isTrue);
    });

    testWidgets('a tap on the header again collapses the panel',
        (tester) async {
      enlarge(tester);
      controller.add(_entry('alpha'));
      await tester.pumpWidget(consoleHost());
      await tester.pumpAndSettle();

      await tapHeader(tester);
      expect(listHeight(tester), greaterThan(0));

      await tapHeader(tester);
      expect(listHeight(tester), 0);
    });

    testWidgets(
        'H-01: bursts of entries keep auto-scroll on (programmatic '
        'scroll does not pause)', (tester) async {
      enlarge(tester);
      await tester.pumpWidget(consoleHost());
      await tester.pumpAndSettle();
      await tapHeader(tester);

      for (var i = 0; i < 120; i++) {
        controller.add(_entry('line $i'));
      }
      await tester.pumpAndSettle();
      expect(cubit.state.autoScroll, isTrue);

      for (var i = 120; i < 240; i++) {
        controller.add(_entry('line $i'));
      }
      await tester.pumpAndSettle();
      expect(cubit.state.autoScroll, isTrue);
    });

    testWidgets('H-01: a user drag away from the bottom pauses auto-scroll',
        (tester) async {
      enlarge(tester);
      for (var i = 0; i < 120; i++) {
        controller.add(_entry('line $i'));
      }
      await tester.pumpWidget(consoleHost());
      await tester.pumpAndSettle();
      await tapHeader(tester);
      expect(cubit.state.autoScroll, isTrue);

      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(cubit.state.autoScroll, isFalse);
    });

    testWidgets('copy-all writes plainText to the clipboard while collapsed',
        (tester) async {
      enlarge(tester);
      final clipboard = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') clipboard.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      controller.add(_entry('alpha'));
      await tester.pumpWidget(consoleHost());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pumpAndSettle();

      expect(clipboard, hasLength(1));
      final text = (clipboard.single.arguments as Map)['text'] as String;
      expect(text, contains('alpha'));

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('LogLine', () {
    Future<void> pumpLine(WidgetTester tester, LogLevel level) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OkoTheme.dark,
          home: Scaffold(body: LogLine(entry: _entry('payload', level: level))),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('paints info in textSecondary', (tester) async {
      await pumpLine(tester, LogLevel.info);
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textSpan!.style!.color, OkoTones.dark.textSecondary);
    });

    testWidgets('paints warning in accentTransitional', (tester) async {
      await pumpLine(tester, LogLevel.warning);
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textSpan!.style!.color, OkoTones.dark.accentTransitional);
    });

    testWidgets('paints error in accentError', (tester) async {
      await pumpLine(tester, LogLevel.error);
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textSpan!.style!.color, OkoTones.dark.accentError);
    });
  });
}
