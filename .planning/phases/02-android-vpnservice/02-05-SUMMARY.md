---
phase: 02-android-vpnservice
plan: 05
subsystem: harness
tags: [traffic, stream-builder, debug-harness, di, composition-root, rx-tx]

# Dependency graph
requires:
  - phase: 01-pigeon
    provides: "VpnRepositoryImpl.watchTraffic() (проксирует ds.traffic), TrafficStats{rxBytes,txBytes}, trafficToEntity, AppDependencies composition root, DebugHarness (StreamBuilder статуса + логи)"
  - phase: 02-android-vpnservice
    provides: "02-03 OkoVpnService: ticker шлёт trafficChanged из native при активном туннеле (источник rx/tx)"
provides:
  - "AppDependencies.watchTraffic() — проброс потока TrafficStats из vpnRepository в harness без новых репозиториев/датасорсов"
  - "DebugHarness: StreamBuilder<TrafficStats> с readout 'rx: N B  tx: N B' под блоком статуса — AND-05 наблюдаем на phase-gate"
affects: [02-06, 03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "harness читает трафик тем же паттерном, что и статус: поток кэшируется в late final _trafficStream в initState, StreamBuilder не переподписывается на rebuild"
    - "readout начального состояния (нет данных) через null-coalescing на нули — StreamBuilder до первого события не рисует прочерк, а показывает rx: 0 B tx: 0 B"

key-files:
  created: []
  modified:
    - lib/app/di.dart
    - lib/main.dart

key-decisions:
  - "watchTraffic() — метод-проброс в AppDependencies поверх уже связанного vpnRepository (композиция не расширяется: без новых датасорсов/репозиториев)"
  - "harness кэширует _trafficStream в initState (симметрично _stateStream) — StreamBuilder держит одну подписку на broadcast-поток репозитория"
  - "начальное состояние StreamBuilder (snapshot.data == null) рендерится нулями (rx: 0 B tx: 0 B), не прочерком — счётчик читаем сразу до первого trafficChanged"

patterns-established:
  - "harness-readout трафика: late final _trafficStream + StreamBuilder<TrafficStats> + чистый форматтер _describeTraffic (симметрия с _describeState)"

requirements-completed: [AND-05]

# Metrics
duration: 2min
completed: 2026-07-13
---

# Phase 2 Plan 05: Счётчики rx/tx в debug-harness Summary

**AppDependencies.watchTraffic() пробрасывает поток TrafficStats из репозитория, DebugHarness рисует живой readout `rx: N B  tx: N B` под статусом — AND-05 наблюдаем в harness без Phase 3 UI**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-07-13T20:27:14Z
- **Completed:** 2026-07-13T20:29:00Z
- **Tasks:** 1 (auto)
- **Files modified:** 2

## Accomplishments
- `AppDependencies.watchTraffic()` экспонирует уже связанный `vpnRepository.watchTraffic()` в harness — без новых репозиториев/датасорсов, композиция не расширена
- `DebugHarness` кэширует `_trafficStream` в `initState` (симметрично `_stateStream`) и рисует `StreamBuilder<TrafficStats>` с readout `rx: <rxBytes> B  tx: <txBytes> B` под блоком статуса, до списка логов
- Чистый форматтер `_describeTraffic(TrafficStats?)` рендерит нули до первого события — счётчик читаем сразу; при ticker'е сервиса (план 03) значение наблюдаемо растёт (device-чек плана 06)
- Автогейт зелёный: `flutter analyze` — No issues found; `flutter test` — 46 passed (регресс фаз 1/2 не тронут); `flutter build apk --debug` собирается

## Task Commits

Каждая задача закоммичена атомарно:

1. **Task 1: счётчики rx/tx из watchTraffic в debug-harness** - `f018dfd` (feat)

**Plan metadata:** (следующий commit — docs: complete plan)

## Files Created/Modified
- `lib/app/di.dart` — добавлен импорт `TrafficStats` и метод-проброс `Stream<TrafficStats> watchTraffic() => vpnRepository.watchTraffic()`
- `lib/main.dart` — импорт `TrafficStats`, поле `late final _trafficStream`, подписка в `initState`, `StreamBuilder<TrafficStats>` под статусом, форматтер `_describeTraffic`

## Decisions Made
- `watchTraffic()` — тонкий проброс поверх `vpnRepository`, а не новый usecase: harness — throwaway-инструмент проверки, доменный `WatchTraffic` usecase появится в Phase 3 UI (как отмечено в 01-04-SUMMARY). Границы фазы соблюдены: тронуты только `lib/app` (di + harness), native/domain-модели/mappers не затронуты
- `_trafficStream` кэшируется в `initState` симметрично `_stateStream` — одна подписка на broadcast-поток репозитория, StreamBuilder не переподписывается на rebuild
- начальное состояние (`snapshot.data == null`) рендерится нулями через `stats?.rxBytes ?? 0`, а не прочерком — счётчик читаем немедленно, наблюдение роста при ping (план 06) начинается с чёткой базовой линии 0

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None. Транзиентные analyzer-warnings (unused import / unused field / undefined method) фиксировались IDE между последовательными Edit'ами до применения всех правок; финальный `flutter analyze` — No issues found.

## User Setup Required
None — чистый Dart-слой harness. Живой рост rx/tx проверяется на эмуляторе в плане 06 (`adb shell ping` в подсеть туннеля при активном OkoVpnService).

## Next Phase Readiness
- AND-05 наблюдаем в harness: readout rx/tx готов принять поток `trafficChanged` из native (ticker сервиса плана 03) — план 06 замыкает device-чеклист «rx растёт при ping»
- Phase 3 UI заменит harness Bloc-экраном по DESIGN.md, читая `WatchTraffic` usecase из `AppDependencies`; harness-readout — временный инструмент phase-gate
- Границы соблюдены: native, domain-модели, mappers, Bloc не тронуты; композиция не расширена

## Self-Check: PASSED

Оба заявленных файла (`lib/app/di.dart`, `lib/main.dart`) на диске; коммит `f018dfd` в истории; `flutter analyze` — No issues found; `flutter test` — 46 passed; `flutter build apk --debug` собран. Acceptance: `grep -c watchTraffic lib/app/di.dart`=1, `grep -c TrafficStats lib/main.dart`=3, `StreamBuilder<TrafficStats>` в harness присутствует.

---
*Phase: 02-android-vpnservice*
*Completed: 2026-07-13*
