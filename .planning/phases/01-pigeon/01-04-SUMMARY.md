---
phase: 01-pigeon
plan: 04
subsystem: data
tags: [repository, replay, broadcast, ring-buffer, composition-root, di, harness, platform-exception, failure, tdd]

# Dependency graph
requires:
  - "01-02: доменные entity (sealed VpnState, VpnConfig, TrafficStats, LogEntry), интерфейсы VpnRepository/LogRepository, usecases, sealed Failure (PlatformFailure/VpnStartFailure)"
  - "01-03: VpnBridge, датасорсы VpnNativeDatasource/LogNativeDatasource, мапперы statusToEntity/trafficToEntity/logToEntity, top-level vpnEvents(), VpnHostApi"
provides:
  - "VpnRepositoryImpl — кэш _last + broadcast, watchState() реплеит последний статус первым (BRG-04); connect маппит VpnConfig→VpnConfigMessage и ловит PlatformException→VpnStartFailure (BRG-03)"
  - "LogRepositoryImpl — ring buffer на 500 записей + broadcast, watchLogs() реплеит буфер затем поток"
  - "lib/core/error/vpn_exception.dart — mapPlatformException(PlatformException)→Failure"
  - "snapshotToEntity(VpnStatusSnapshotMessage)→VpnState для syncStatus"
  - "AppDependencies (lib/app/di.dart) — composition root: единственный vpnEvents(), проводка bridge→datasource→repo→usecase"
  - "OkoApp + debug-harness (lib/app/app.dart, lib/main.dart) — echo Connect/Disconnect и живой вывод статуса/логов через usecase"
affects: [01-07, 02, 03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Двойная защита от гонки старта: native replay в onListen (Kotlin/Swift, планы 05/06) + Dart-кэш _last в repository (BRG-04)"
    - "watchState() как async* с yield _last; yield* _controller.stream — реплей кэша перед broadcast-обновлениями"
    - "Ring buffer логов (лимит 500, removeAt(0) при переполнении) + broadcast; watchLogs реплеит снапшот буфера"
    - "Composition root ручной проводкой (Code Example 9): единственное место вызова vpnEvents(), конструкторная инъекция без DI-контейнера"
    - "debug-harness ходит только через usecase (Pitfall 5): g.dart изолирован в di.dart через VpnBridge/VpnHostApi"
    - "Failure implements Exception — типобезопасный throw доменной ошибки без inline-ignore only_throw_errors"

key-files:
  created:
    - lib/features/vpn_connection/data/repositories/vpn_repository_impl.dart
    - lib/features/vpn_logs/data/repositories/log_repository_impl.dart
    - lib/core/error/vpn_exception.dart
    - lib/app/di.dart
    - lib/app/app.dart
    - test/features/vpn_connection/data/repositories/vpn_repository_impl_test.dart
    - test/helpers/fake_vpn_native_datasource.dart
  modified:
    - lib/main.dart
    - lib/core/error/failures.dart
    - lib/features/vpn_connection/data/mappers/vpn_event_mapper.dart

key-decisions:
  - "Failure implements Exception (в дополнение к extends Equatable) — connect() бросает типизированный VpnStartFailure без нарушения only_throw_errors и без комментария-ignore"
  - "snapshotToEntity добавлен в vpn_event_mapper.dart через общий приватный _statusToState; statusToEntity рефакторён на тот же хелпер с сохранением поведения (тесты 01-03 зелёные)"
  - "mapPlatformException возвращает VpnStartFailure(code, message) для start-пути; PlatformFailure остаётся для будущего маппинга ошибок прочих host-вызовов"
  - "FakeVpnNativeDatasource implements VpnNativeDatasource (концертная подмена через implicit interface) — тест репозитория идёт без платформы и без моста"
  - "Harness выводит статус и логи (по acceptance); трафик опущен — WatchTraffic usecase вне скоупа домена (плана 02), добавится в Phase 3 UI"

patterns-established:
  - "BRG-04 double-replay: native onListen replay + Dart repository _last cache"
  - "Изоляция кодогена: g.dart только в di.dart; harness/app импортируют лишь usecase и entity"

requirements-completed: [BRG-03, BRG-04]

# Metrics
duration: 12min
completed: 2026-07-13
---

# Phase 1 Plan 04: Репозитории с replay, composition root и debug-harness Summary

**VpnRepositoryImpl реплеит последний статус первым (BRG-04), PlatformException становится типизированным VpnStartFailure (BRG-03), composition root связывает bridge→datasource→repo→usecase, а минимальный echo-harness прогоняет статус и логи через слои**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-07-13T19:47:00Z
- **Completed:** 2026-07-13T19:58:00Z
- **Tasks:** 2 (Task 1 — TDD RED→GREEN)
- **Files modified:** 10 (7 created, 3 modified)

## Accomplishments
- `VpnRepositoryImpl` замыкает двойную защиту от гонки старта: подписка на `ds.states` в конструкторе кэширует `_last` и пушит в broadcast; `watchState()` (`async*`) отдаёт `_last` первым, затем `_controller.stream` — поздний подписчик всегда видит актуальный статус (BRG-04)
- `syncStatus()` читает снапшот `getStatus()` через `snapshotToEntity` и обновляет кэш; `connect()` маппит `VpnConfig→VpnConfigMessage` и переводит `PlatformException` в `VpnStartFailure` (BRG-03)
- `LogRepositoryImpl` — ring buffer на 500 записей + broadcast; `watchLogs()` реплеит снапшот буфера, затем живой поток
- `AppDependencies` — composition root с единственным вызовом `vpnEvents()`, ручной проводкой bridge→datasource→repo→usecase (Code Example 9, SOLID)
- Минимальный debug-harness: `StreamBuilder` статуса + аккумулирующий список логов через usecase, кнопки echo Connect/Disconnect; `vpn_api.g.dart` в виджете не импортируется (Pitfall 5)
- 9 новых тестов репозитория (replay `_last`, обновление кэша через `ds.states` и `syncStatus`, порядок событий, проксирование трафика, маппинг ошибки); весь набор — 37 тестов зелёные

## Task Commits

Task 1 — TDD (RED→GREEN); Task 2 — auto:

1. **Task 1 (RED): падающие тесты replay-репозитория и маппинга ошибок** - `39c461b` (test)
2. **Task 1 (GREEN): репозитории с replay и типизированные ошибки** - `e8fb5ff` (feat)
3. **Task 2: composition root и debug-harness echo** - `ddeb1bc` (feat)

## Files Created/Modified
- `lib/features/vpn_connection/data/repositories/vpn_repository_impl.dart` — кэш `_last` + broadcast, `watchState` replay, connect с маппингом ошибки, `syncStatus`, `dispose`
- `lib/features/vpn_logs/data/repositories/log_repository_impl.dart` — ring buffer (500) + broadcast, `watchLogs` реплеит буфер
- `lib/core/error/vpn_exception.dart` — `mapPlatformException(PlatformException)→VpnStartFailure`
- `lib/app/di.dart` — `AppDependencies`: единственный `vpnEvents()`, проводка слоёв, usecases как `late final`
- `lib/app/app.dart` — `OkoApp` минимальный `MaterialApp` (тема из DESIGN.md отложена в Phase 3)
- `lib/main.dart` — bootstrap `AppDependencies`, `syncStatus()` на старте, `DebugHarness` (StreamBuilder статуса, список логов, echo-кнопки)
- `lib/core/error/failures.dart` — `Failure` теперь `implements Exception`
- `lib/features/vpn_connection/data/mappers/vpn_event_mapper.dart` — добавлен `snapshotToEntity`, общий `_statusToState`
- `test/features/vpn_connection/data/repositories/vpn_repository_impl_test.dart` — 9 тестов replay/кэш/порядок/маппинг
- `test/helpers/fake_vpn_native_datasource.dart` — фейк датасорса с управляемыми стримами и снапшотом

## Decisions Made
- `Failure implements Exception`: `connect()` бросает `VpnStartFailure` напрямую; `only_throw_errors` из very_good_analysis удовлетворён без inline-ignore (запрет комментариев соблюдён). `Exception` — пустой маркер, `extends Equatable` и равенство по значению не затронуты
- `snapshotToEntity` вынесен рядом с `statusToEntity` в data-маппере vpn_connection; общий приватный `_statusToState(status, epochMs)` убирает дублирование switch. Поведение `statusToEntity` идентично — тесты маппера 01-03 остались зелёными
- `mapPlatformException` возвращает `VpnStartFailure(code, message)` для start-пути (единственный вызывающий — `connect`); `PlatformFailure` остаётся типом для маппинга ошибок прочих host-вызовов в будущем
- Harness выводит статус и логи через usecase (acceptance); трафик не отображается — `WatchTraffic` usecase не входит в доменный скоуп плана 02, добавится в Phase 3 UI. Это осознанный scope-boundary, не заглушка

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Failure implements Exception для типобезопасного throw**
- **Found during:** Task 1 (GREEN — реализация connect)
- **Issue:** `connect()` по интерфейсу плана бросает типизированный `Failure` на `PlatformException`. `Failure extends Equatable` (план 02) не является `Exception`, поэтому `throw mapPlatformException(e)` триггерит `only_throw_errors` (very_good_analysis). Inline-ignore запрещён правилом «без комментариев»
- **Fix:** `sealed class Failure extends Equatable implements Exception`. `Exception` — пустой маркер-интерфейс, членов не добавляет; равенство и все подтипы плана 02 не изменены
- **Files modified:** lib/core/error/failures.dart
- **Verification:** `flutter analyze lib` → No issues found; тест `connect translates PlatformException into a typed VpnStartFailure` зелёный
- **Committed in:** `e8fb5ff` (Task 1 GREEN)

**2. [Rule 3 - Blocking] snapshotToEntity в data-маппере для syncStatus**
- **Found during:** Task 1 (GREEN — реализация syncStatus)
- **Issue:** `syncStatus()` по Code Example 6 делает `(await ds.currentStatus()).toEntity()`; `currentStatus()` отдаёт DTO `VpnStatusSnapshotMessage` (маппинг снапшота отложен в план 04 ещё в 01-03-SUMMARY). Готового маппера снапшота не было; `vpn_event_mapper.dart` не значился в `files_modified`
- **Fix:** в `vpn_event_mapper.dart` добавлен `snapshotToEntity(VpnStatusSnapshotMessage)`; общий приватный `_statusToState(status, epochMs)` убирает дублирование пятиветочного switch; `statusToEntity` рефакторён на тот же хелпер без изменения поведения
- **Files modified:** lib/features/vpn_connection/data/mappers/vpn_event_mapper.dart
- **Verification:** тесты маппера 01-03 (6 шт.) остались зелёными; тест `syncStatus reads snapshot and replays it` зелёный; `flutter analyze` чист
- **Committed in:** `e8fb5ff` (Task 1 GREEN)

---

**Total deviations:** 2 auto-fixed (оба blocking)
**Impact on plan:** обе правки в data/core-слое, ожидались контекстом (01-03-SUMMARY явно отложил маппинг снапшота в план 04). Контракт и границы фазы соблюдены — тронуты только data-репозитории, core/error, app/harness и Wave-0 тест; domain-модели, native и presentation-Bloc не затронуты. Scope не расширен

## Issues Encountered
- `PlatformException` не имеет const-конструктора — в тесте убран `const` перед его созданием (поймано IDE-диагностикой сразу на RED-стадии)
- `subscription.cancel()` в `dispose()` harness триггерил `discarded_futures` — обёрнут в `unawaited`

## Threat Model Compliance
- **T-1-05 (ложный статус):** `_last` меняется только событиями из `ds.states` и снапшотом `syncStatus()`; Flutter сам Connected не выставляет. Тест `subscriber before emits receives events in order` подтверждает, что реплеится именно last-статус
- **T-1-02 (утечка):** `mapPlatformException` переводит `PlatformException` в доменный `VpnStartFailure` с чистым `code`/`message`; сырые строки/стек платформы в домен не уходят
- **T-1-01 (harness-лог):** harness рисует синтетические echo-тексты; реальных кред нет (VLESS — Phase 4)

## User Setup Required
None — чистый Dart-слой; harness проверяется живьём в плане 07 (`flutter run` на устройстве/эмуляторе).

## Next Phase Readiness
- BRG-03 и BRG-04 закрыты на уровне Dart-стека: репозиторий реплеит last-статус, ошибки типизированы, снапшот маппится
- Вертикальный срез walking-skeleton на Dart-стороне замкнут: `AppDependencies` → usecase → repository → `VpnBridge` → `vpnEvents()`. План 07 подключает живой echo Android/iOS через harness
- Phase 3 UI заменит harness Bloc-экраном по DESIGN.md, читая те же usecases из `AppDependencies`; тогда же появится `WatchTraffic` usecase для отображения трафика
- Границы соблюдены: domain/native/presentation-Bloc/VLESS не тронуты

## Self-Check: PASSED

Все 8 заявленных файлов (7 created + main.dart) существуют на диске; коммиты `39c461b`, `e8fb5ff`, `ddeb1bc` присутствуют в истории; `flutter analyze lib` — No issues found; `flutter test` — 37 passed; harness/app не импортируют `vpn_api.g.dart`, в di.dart ровно один `vpnEvents()`.

---
*Phase: 01-pigeon*
*Completed: 2026-07-13*
