---
phase: 04-vless
plan: 04
subsystem: presentation
tags: [vless, cubit, bloc-test, sealed-state, tdd, flutter]

requires:
  - phase: 04-vless
    provides: parseVless, VlessConfig, sealed LatencyResult, абстракции LatencyProbe/ClipboardSource (04-01)
provides:
  - sealed ServerConfigState (Initial | Error | Loaded с опциональной latency)
  - ServerConfigCubit — оркестратор paste→parse→measure на domain-абстракциях
  - FakeClipboardSource, FakeLatencyProbe (счётчик measure) в test/helpers
affects: [04-05]

tech-stack:
  added: []
  patterns:
    - "Cubit зависит только от domain-абстракций; реализации инъектит DI в 04-05 (SOLID)"
    - "Порядок эмиссии loaded(config) → loaded(config, latency) даёт карточке мгновенный рендер до замера"
    - "Стаб-cubit в RED-шаге держит blocTest компилируемым: падение на ассертах, не на отсутствии класса"

key-files:
  created:
    - lib/features/server_config/presentation/cubit/server_config_state.dart
    - lib/features/server_config/presentation/cubit/server_config_cubit.dart
    - test/helpers/fake_clipboard_source.dart
    - test/helpers/fake_latency_probe.dart
    - test/features/server_config/presentation/server_config_cubit_test.dart
  modified: []

key-decisions:
  - "ServerConfigLoaded несёт latency как nullable-поле, а не отдельным state: карточка рендерит конфиг сразу, задержка доезжает вторым emit того же типа"
  - "uuid не выносится в отдельное поле state — живёт только внутри VlessConfig, карточка маскирует (T-4-02)"
  - "Фейки — ручные implements без mocktail: интерфейсы одно-методные, счётчик measureCallCount проще ручным полем"

patterns-established:
  - "blocTest build инъектит фейки, act зовёт pasteFromClipboard, expect сверяет список emit, verify бьёт по measureCallCount"
  - "RED через компилирующийся стаб: пустое тело эмитит только Initial, ожидаемые списки не сходятся"

requirements-completed: [VLS-02]

duration: 2min
completed: 2026-07-14
---

# Phase 04 Plan 04: ServerConfigCubit paste→parse→measure Summary

**ServerConfigCubit связывает ClipboardSource → parseVless → LatencyProbe и эмитит sealed ServerConfigState; 4 сценария blocTest зелёные без сети и platform channel.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-07-14T01:02:39Z
- **Completed:** 2026-07-14T01:04:31Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Логическое ядро VLS-02 готово: пустой буфер → error(empty), кривая ссылка → error(reason) без падения, валидная → loaded(config) затем loaded(config, latency)
- Cubit зависит только от domain-абстракций LatencyProbe/ClipboardSource — тестируется фейками, ноль сети и Clipboard в автосьюте
- sealed ServerConfigState (Initial | Error | Loaded) держит latency опциональным полем Loaded — карточка рендерит конфиг до завершения замера
- Полный набор проекта зелёный: 137 тестов (было 133), analyzer чист, ноль новых пакетов

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: sealed state + стаб-cubit + фейки + падающий bloc-тест** - `79c4006` (test)
2. **Task 2 GREEN: ServerConfigCubit оркеструет paste→parse→measure** - `b859c85` (feat)

_TDD: Task 1 зафиксировал RED (стаб компилируется, эмитит только Initial → ассерты не сходятся); Task 2 наполнил тело до GREEN. REFACTOR не потребовался (тело минимально)._

## Files Created/Modified
- `lib/features/server_config/presentation/cubit/server_config_state.dart` - sealed ServerConfigState: Initial | Error(VlessError) | Loaded(VlessConfig, {LatencyResult?})
- `lib/features/server_config/presentation/cubit/server_config_cubit.dart` - pasteFromClipboard оркеструет readText → parseVless → measure, эмитит loaded/error
- `test/helpers/fake_clipboard_source.dart` - FakeClipboardSource с настраиваемым textToReturn
- `test/helpers/fake_latency_probe.dart` - FakeLatencyProbe: настраиваемый resultToReturn, счётчик measureCallCount, захват host/port
- `test/features/server_config/presentation/server_config_cubit_test.dart` - blocTest: empty / valid+measured / valid+unreachable / invalid-scheme

## Decisions Made
- `ServerConfigLoaded` несёт `latency` как nullable-поле того же state, а не отдельным состоянием: два emit одного типа (без latency → с latency) дают карточке мгновенный рендер конфига и последующую дозагрузку задержки
- uuid не выносится в поле state — остаётся внутри `VlessConfig`, маскировку делает карточка (04-03); в cubit uuid не логируется
- Фейки написаны ручным `implements` без mocktail: одно-методные абстракции + счётчик `measureCallCount` проще прямым полем, чем `verify(() => ...)`

## Deviations from Plan

None - plan executed exactly as written (учтена ревизия W2: Task 1 создаёт компилирующийся стаб + RED на ассертах, Task 2 наполняет тело).

## Issues Encountered
None. Стаб-cubit из Task 1 дал RED ровно как задумано: `flutter analyze` чист, `flutter test` падает на сравнении списков (Expected [...] / Actual []), не на compile-error. Task 2 сделал все 4 сценария зелёными без правок тестов.

## Threat Model Coverage
- **T-4-01 (DoS, mitigate):** пустой буфер и кривая ссылка деградируют в `ServerConfigError`, cubit не бросает; blocTest на empty и invalid-scheme фиксируют отсутствие throw и что probe.measure не вызывается на error-ветке.
- **T-4-02 (Information Disclosure, mitigate):** uuid не логируется и не выносится отдельным полем state — живёт только внутри `VlessConfig`; карточка маскирует.
- Новой security-поверхности за пределами threat_model плана не добавлено.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `ServerConfigCubit` готов к регистрации в composition root (04-05): конструктор принимает domain-абстракции, DI подставит `SystemClipboardSource` и `SocketLatencyProbe`
- sealed `ServerConfigState` подключается к `VlessConfigCard` (04-03) через `BlocBuilder`: initial/error → ServerCard + строка ошибки, loaded → VlessConfigCard
- Фейки `test/helpers/fake_clipboard_source.dart` / `fake_latency_probe.dart` переиспользуются в screen-тесте 04-05

## Self-Check: PASSED

Все 5 созданных файлов + SUMMARY на диске; коммиты `79c4006`, `b859c85` в истории.

---
*Phase: 04-vless*
*Completed: 2026-07-14*
