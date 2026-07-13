---
phase: 03-flutter-ui
plan: 07
subsystem: ui
tags: [flutter, flutter_bloc, draggable_scroll_sheet, logs, autoscroll, tdd]

# Dependency graph
requires:
  - phase: 03-02
    provides: OkoTones (accentTransitional/accentError/textSecondary), OkoTypography.mono, OkoMotion.autoscroll
  - phase: 03-04
    provides: LogsCubit/LogsState — buffer, autoScroll flag, pauseAutoScroll/resumeAutoScroll, plainText
provides:
  - "LogLine — одна строка лога, JetBrains Mono, время secondary, цвет по уровню (UI-08)"
  - "LogConsole — DraggableScrollableSheet с автоскроллом, паузой при ручной прокрутке, copy-all и empty state (UI-03, UI-08)"
affects: [03-08, 03-09]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "DraggableScrollableSheet отдаёт свой ScrollController — виджет использует его для ListView и animateTo, свой не заводит"
    - "animateTo только после layout: hasClients + addPostFrameCallback (Pitfall 6)"
    - "Text.rich с root-стилем уровня и override-спаном secondary для времени — цвет уровня инспектируется в тесте через textSpan.style.color"

key-files:
  created:
    - lib/features/vpn_logs/presentation/widgets/log_line.dart
    - lib/features/vpn_logs/presentation/widgets/log_console.dart
    - test/features/vpn_logs/presentation/widgets/log_console_test.dart
  modified: []

key-decisions:
  - "Цвет уровня несёт root TextSpan (info→textSecondary, warning→accentTransitional, error→accentError); время всегда secondary через дочерний спан"
  - "empty state — ListView с sheet-контроллером (не Center), чтобы панель оставалась draggable при пустом буфере"
  - "copy-all захватывает ScaffoldMessenger до await (use_build_context_synchronously), затем Clipboard.setData + HapticFeedback.selectionClick + SnackBar 'Copied N lines'"

patterns-established:
  - "Widget-тест панели логов: увеличенная physicalSize (1000x2000), чтобы sheet при initial 0.12 вмещал шапку и строки без RenderFlex overflow"
  - "Перехват Clipboard через tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform)"

requirements-completed: [UI-03, UI-08]

# Metrics
duration: 8min
completed: 2026-07-14
---

# Phase 03 Plan 07: LogConsole + LogLine Summary

**Панель логов на DraggableScrollableSheet: живые моноширинные строки с цветом уровня, автоскролл с паузой при ручной прокрутке вверх, copy-all в буфер и осмысленное пустое состояние.**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-07-13T23:10:39Z
- **Tasks:** 1 (TDD RED→GREEN)
- **Files created:** 3

## Accomplishments
- `LogLine`: `Text.rich` JetBrains Mono 12, формат `HH:mm:ss  text`, время всегда textSecondary, цвет строки ведёт уровень — info→textSecondary, warning→accentTransitional, error→accentError (UI-08); `Semantics(label: '{level}: {text}')`
- `LogConsole`: `DraggableScrollableSheet` (0.12/0.12/0.70), фон surfaceElevated, верхние углы 24; шапка — grabber 4x36 secondary, заголовок `Logs` (heading), copy-all кнопка (`Icons.copy_rounded`, touch 48, Semantics 'Copy all logs')
- Автоскролл: `BlocConsumer` листенер зовёт `animateTo(maxScrollExtent)` через `addPostFrameCallback` только при `autoScroll && hasClients` (Pitfall 6); `NotificationListener` ставит `pauseAutoScroll` при уходе от низа >24px и `resumeAutoScroll` у низа
- Использован выданный sheet-контроллер и для `ListView`, и для `animateTo` — свой `ScrollController` не заводится (Pattern 8)
- Copy-all: `Clipboard.setData(plainText())` + `HapticFeedback.selectionClick` + SnackBar `Copied N lines`
- Empty state: `Icons.terminal_rounded` 32 + `Waiting for events` + `Tunnel logs stream here in real time.` вместо пустого прямоугольника (UI-03)

## Task Commits

TDD-цикл RED→GREEN:

1. **Task 1 (RED)** — `52398f2` (test): падающие widget-тесты + скелеты виджетов
2. **Task 1 (GREEN)** — `2edb307` (feat): реализация LogLine + LogConsole

## Files Created/Modified
- `lib/features/vpn_logs/presentation/widgets/log_line.dart` — `LogLine`, цвет уровня, JetBrains Mono, Semantics
- `lib/features/vpn_logs/presentation/widgets/log_console.dart` — `LogConsole` (sheet, шапка, автоскролл, copy-all, empty state)
- `test/features/vpn_logs/presentation/widgets/log_console_test.dart` — рендер строк, empty state, цвета уровней, вызов Clipboard

## Decisions Made
- Цвет уровня несёт root `TextSpan`, время — дочерний спан secondary: разделяет «время всегда нейтрально» и «текст красит уровень», плюс делает цвет инспектируемым в тесте
- Empty state построен как `ListView` с sheet-контроллером, а не `Center`, чтобы drag панели работал и при пустом буфере
- В widget-тесте увеличен `physicalSize` до 1000x2000: при `initialChildSize 0.12` шапка и строки помещаются без RenderFlex overflow, copy-кнопка кликабельна без drag

## Deviations from Plan

None — план исполнен как написан. Одно косметическое уточнение (`unawaited(controller.animateTo(...))` для снятия `discarded_futures`) зафиксировано как решение, поведение не меняет.

## Threat Register Coverage
- **T-3-01 (Information Disclosure, copy-all → Clipboard):** mitigate — copy-all копирует только `LogsCubit.plainText()` (маппинг `LogEntry.text/level/time`); секреты/конфиг в буфер логов не попадают (решение native, 02-03)
- **T-3-08 (Tampering, рендер строки лога):** accept — `Text`/`Text.rich` не исполняют разметку; строки из собственного native

## Issues Encountered
None.

## User Setup Required
None — внешних сервисов не требуется.

## Next Phase Readiness
- LogConsole/LogLine готовы к сборке в экран (03-08): встраиваются в `Stack` поверх контента как нижний sheet, читают `LogsCubit` из провайдера
- `flutter analyze` чист по всему проекту; полный `flutter test` зелёный (96 тестов)

## Self-Check: PASSED

Все 4 артефакта (3 файла кода/теста + SUMMARY) на диске; оба коммита (52398f2, 2edb307) в истории.
