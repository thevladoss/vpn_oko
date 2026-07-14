---
phase: 04-vless
plan: 02
subsystem: data
tags: [vless, tcping, socket, clipboard, dart-io, flutter-services, tdd]

requires:
  - phase: 04-vless
    provides: контракты LatencyProbe/ClipboardSource/LatencyResult (04-01)
provides:
  - SocketLatencyProbe (implements LatencyProbe) — tcping через Socket.connect+Stopwatch с инъектируемым коннектором
  - TcpConnector typedef — шов для тестов без реальной сети
  - SystemClipboardSource (implements ClipboardSource) — чтение буфера через Clipboard.getData
affects: [04-05]

tech-stack:
  added: []
  patterns:
    - "Инъектируемый typedef-коннектор (nullable) вместо мока сети: дефолт резолвится в measure, конструктор остаётся const"
    - "dart:io / flutter/services изолированы в data-слое за domain-абстракциями"

key-files:
  created:
    - lib/features/server_config/data/probes/socket_latency_probe.dart
    - lib/features/server_config/data/datasources/clipboard_source_impl.dart
    - test/features/server_config/data/socket_latency_probe_test.dart
  modified: []

key-decisions:
  - "connector — nullable-поле, дефолт _defaultConnect резолвится внутри measure (не в инициализаторе поля): tearoff instance-метода не const, но const-конструктор SocketLatencyProbe нужен для DI 04-05"
  - "measure ловит только SocketException — Socket.connect(timeout:) даёт SocketException и на отказ, и на таймаут (VERIFIED в 04-RESEARCH); отдельный on TimeoutException был бы мёртвым кодом"
  - "SystemClipboardSource — тонкая обёртка platform channel, unit-тестом не покрывается (device-gate 04-06, фейк в screen-тесте 04-05)"

patterns-established:
  - "Проба меряет RTT через Stopwatch вокруг await connect(host, port, timeout); деградация в LatencyUnreachable без rethrow"
  - "Тест инъектит фейк-коннектор (успешный/бросающий/захват аргументов) — ноль реальной сети в автосьюте (A3)"

requirements-completed: [VLS-03, VLS-02]

duration: 2min
completed: 2026-07-14
---

# Phase 04 Plan 02: Data-слой server_config (tcping + буфер) Summary

**SocketLatencyProbe меряет TCP connect time через Socket.connect+Stopwatch за инъектируемым коннектором (const-конструктор для DI, деградация в LatencyUnreachable) и SystemClipboardSource читает буфер через Clipboard.getData.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-07-14T00:50:31Z
- **Completed:** 2026-07-14T00:52:40Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- VLS-03 закрыт: проба меряет RTT и корректно деградирует в LatencyUnreachable на SocketException, тестируема без сети через инъекцию `TcpConnector`
- const-конструктор `SocketLatencyProbe` валиден (тест на `const SocketLatencyProbe()`) — готов к DI-регистрации в 04-05
- VLS-02 инфраструктура: SystemClipboardSource читает буфер за абстракцией ClipboardSource
- `dart:io` Socket и `flutter/services` Clipboard изолированы в data — presentation увидит только domain-абстракции
- Полный набор проекта зелёный: 121 тест (117 прежних + 4 новых), analyzer чист, ноль новых пакетов

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: падающие тесты SocketLatencyProbe** - `b83c689` (test)
2. **Task 1 GREEN: реализация SocketLatencyProbe** - `4d6ddb8` (feat)
3. **Task 2: SystemClipboardSource** - `4749e1b` (feat)

_TDD: Task 1 выполнен как RED → GREEN; REFACTOR не потребовался (проба минимальна и чиста)._

## Files Created/Modified
- `lib/features/server_config/data/probes/socket_latency_probe.dart` - SocketLatencyProbe + TcpConnector typedef; measure() меряет RTT, ловит SocketException
- `lib/features/server_config/data/datasources/clipboard_source_impl.dart` - SystemClipboardSource: Clipboard.getData(kTextPlain) → text
- `test/features/server_config/data/socket_latency_probe_test.dart` - 4 кейса через фейк-коннектор (measured, unreachable, проброс аргументов, валидность const)

## Decisions Made
- `connector` хранится как nullable-поле; дефолтный `_defaultConnect` резолвится ВНУТРИ `measure` через `connector ?? _defaultConnect` — tearoff instance-метода не const, резолв в инициализаторе поля сломал бы `const SocketLatencyProbe()`, нужный для DI 04-05
- `measure` ловит только `SocketException`: `Socket.connect(timeout:)` бросает его и на отказ соединения, и на таймаут (эмпирика 04-RESEARCH), поэтому отдельный `on TimeoutException` был бы мёртвым кодом
- SystemClipboardSource — тонкая platform-channel обёртка, не покрывается unit-тестом (проверка в device-gate 04-06 и через фейк в screen-тесте 04-05)

## Deviations from Plan

None - plan executed exactly as written (учтена ревизия W3: nullable-connector, дефолт в measure, const-конструктор).

## Issues Encountered
None. Socket.connect и Clipboard спрятаны за абстракциями ровно как в research; тесты бьют по инъектируемому коннектору, реальной сети в автосьюте нет.

## Threat Model Coverage
- **T-4-01 (DoS, mitigate):** `measure` ловит `SocketException` → `LatencyUnreachable`, наружу не пробрасывает — тест на бросающий коннектор фиксирует это.
- **T-4-04 (SSRF-подобный, accept):** коннект инициирует сам пользователь вставкой; `timeout` 3с по умолчанию не даёт зависнуть; только TCP-connect без записи данных (`socket.destroy()` сразу), авто-коннекта нет.
- Новых surface за пределами threat_model плана не добавлено.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `SocketLatencyProbe` и `SystemClipboardSource` готовы к DI-регистрации в composition root (04-05); const-конструкторы обеих реализаций валидны
- Presentation-план (ServerConfigCubit) получит `LatencyProbe`/`ClipboardSource` как domain-абстракции и подставит фейки в тестах
- Живой tcping и реальный буфер проверяются в device-gate (04-06)

## Self-Check: PASSED

Все 3 созданных файла + SUMMARY на диске; коммиты `b83c689`, `4d6ddb8`, `4749e1b` в истории.

---
*Phase: 04-vless*
*Completed: 2026-07-14*
