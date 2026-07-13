---
phase: 03-flutter-ui
plan: 04
subsystem: ui
tags: [flutter, flutter_bloc, cubit, equatable, formatters, logs, tdd]

# Dependency graph
requires:
  - phase: 03-01
    provides: bloc_test и mocktail в dev-зависимостях, google_fonts подключён
  - phase: 02-логи (vpn_logs domain/data)
    provides: LogEntry, LogLevel, WatchLogs usecase, LogRepositoryImpl с cap 500 и replay
provides:
  - "formatBytes(int) — авто-единица B/KB/MB/GB, делитель 1024 (UI-05)"
  - "hhmmss(Duration) — zero-pad HH:MM:SS для таймера (UI-04)"
  - "LogsCubit + LogsState — буфер cap 500, флаг autoScroll, plainText для copy-all (UI-03, UI-08)"
affects: [03-05, 03-06, 03-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Чистые top-level форматтеры под unit-тест (не дублировать в виджетах)"
    - "Cubit аккумулирует stream в кольцевой буфер с cap, дроп головы через removeRange"

key-files:
  created:
    - lib/features/vpn_connection/presentation/formatters/byte_format.dart
    - lib/features/vpn_connection/presentation/formatters/duration_format.dart
    - lib/features/vpn_logs/presentation/bloc/logs_state.dart
    - lib/features/vpn_logs/presentation/bloc/logs_cubit.dart
    - test/features/vpn_connection/presentation/format_bytes_test.dart
    - test/features/vpn_connection/presentation/timer_format_test.dart
    - test/features/vpn_logs/presentation/bloc/logs_cubit_test.dart
  modified: []

key-decisions:
  - "plainText форматирует время через приватный _hms (DateTime → HH:mm:ss), отдельно от hhmmss (Duration)"
  - "unawaited(_sub.cancel()) в close() вместо голого вызова — снимает discarded_futures hint"

patterns-established:
  - "Форматтеры лежат в presentation/formatters как чистые функции, тестируются напрямую"
  - "Мок WatchLogs в тесте — мини-fake со StreamController, без общего хелпера"

requirements-completed: [UI-03, UI-04, UI-05, UI-08]

# Metrics
duration: 3min
completed: 2026-07-14
---

# Phase 03 Plan 04: Форматтеры и LogsCubit Summary

**Чистые форматтеры formatBytes/hhmmss плюс LogsCubit с буфером cap 500, флагом autoScroll и plainText для copy-all — логическая база трафика, таймера и панели логов.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-07-13T22:21:02Z
- **Completed:** 2026-07-13T22:23:58Z
- **Tasks:** 2
- **Files modified:** 7 (все созданы)

## Accomplishments
- `formatBytes(int)`: авто-единица B/KB/MB/GB (делитель 1024), целое для B, одна десятичная от KB — покрыт границами 1024/MB/GB (UI-05)
- `hhmmss(Duration)`: zero-pad HH:MM:SS, overflow минут в часы, часы >2 цифр не режутся (UI-04)
- `LogsCubit`: подписка на `watchLogs()`, append+cap 500 с дропом головы, `pauseAutoScroll`/`resumeAutoScroll` идемпотентны, `plainText()` формата `HH:mm:ss [LEVEL] text`, `close()` отменяет подписку (UI-03, UI-08)

## Task Commits

Каждая задача закоммичена атомарно по TDD-циклу RED→GREEN:

1. **Task 1: форматтеры (RED)** - `cc6a111` (test)
2. **Task 1: форматтеры (GREEN)** - `6bf758f` (feat)
3. **Task 2: LogsCubit (RED)** - `0093a69` (test)
4. **Task 2: LogsCubit (GREEN)** - `99dfb23` (feat)

## Files Created/Modified
- `lib/features/vpn_connection/presentation/formatters/byte_format.dart` - чистая `formatBytes`
- `lib/features/vpn_connection/presentation/formatters/duration_format.dart` - чистая `hhmmss`
- `lib/features/vpn_logs/presentation/bloc/logs_state.dart` - `LogsState(entries, autoScroll)` с copyWith/props
- `lib/features/vpn_logs/presentation/bloc/logs_cubit.dart` - `LogsCubit`: буфер, autoScroll, plainText
- `test/features/vpn_connection/presentation/format_bytes_test.dart` - кейсы formatBytes
- `test/features/vpn_connection/presentation/timer_format_test.dart` - кейсы hhmmss
- `test/features/vpn_logs/presentation/bloc/logs_cubit_test.dart` - append, cap 500, pause/resume, plainText, close

## Decisions Made
- Время лога форматирует приватный `_hms(DateTime)` внутри Cubit (wall-clock), отдельно от `hhmmss(Duration)` для таймера — разные входные типы, дублирования логики нет
- `unawaited(_sub.cancel())` в `close()` вместо голого вызова, чтобы убрать `discarded_futures` hint; поведение (fire-and-forget cancel перед super.close) не меняется

## Deviations from Plan

None - plan executed exactly as written. Обе задачи прошли RED→GREEN по `<behavior>`; одно косметическое уточнение (`unawaited`) зафиксировано как решение, не как отклонение.

## Threat Register Coverage
- **T-3-01 (Information Disclosure, plainText):** mitigate — plainText маппит только `LogEntry.text/level/time`, секреты/конфиг в буфер не попадают
- **T-3-05 (DoS, буфер логов):** mitigate — cap 500 с дропом головы (`removeRange`), тест `caps the buffer at 500` подтверждает

## Issues Encountered
None.

## User Setup Required
None - внешних сервисов не требуется.

## Next Phase Readiness
- Форматтеры и LogsCubit готовы для виджетов: TrafficTile (03-05/06), ConnectionTimer (03-06), LogConsole/LogLine (03-07) строятся поверх
- Весь `flutter test` зелёный (67 тестов), `flutter analyze` чист

## Self-Check: PASSED

Все 8 артефактов (7 файлов кода/тестов + SUMMARY) на диске; все 4 коммита (cc6a111, 6bf758f, 0093a69, 99dfb23) в истории.

---
*Phase: 03-flutter-ui*
*Completed: 2026-07-14*
