---
phase: 01-pigeon
plan: 02
subsystem: domain
tags: [domain, sealed, equatable, clean-architecture, solid, tdd, usecase, repository, failure]

# Dependency graph
requires:
  - "01-01: утверждённый стек (equatable 2.1.0, very_good_analysis 10.3.0) и имя поля ErrorMessage.message"
provides:
  - "sealed VpnState (VpnDisconnected/VpnConnecting/VpnConnected/VpnDisconnecting/VpnError) с равенством по значению"
  - "immutable value objects VpnConfig(host/port/userId/serverName), TrafficStats(rxBytes/txBytes)"
  - "LogEntry(text/level/time) + enum LogLevel {info, warning, error}"
  - "abstract VpnRepository (watchState/watchTraffic/connect/disconnect/syncStatus) и LogRepository (watchLogs)"
  - "usecases ConnectVpn/DisconnectVpn/WatchVpnState/SyncStatus/WatchLogs с конструкторной инъекцией репозитория"
  - "sealed Failure (PlatformFailure, VpnStartFailure) для типизации ошибок платформы в data-слое"
affects: [01-03, 01-04, 01-05, 01-06, 01-07]

# Tech tracking
tech-stack:
  added: []
  patterns: [sealed+equatable вместо freezed, abstract interface class для репозиториев, один usecase на действие с методом call, доменная изоляция от кодогена]

key-files:
  created:
    - lib/features/vpn_connection/domain/entities/vpn_state.dart
    - lib/features/vpn_connection/domain/entities/vpn_config.dart
    - lib/features/vpn_connection/domain/entities/traffic_stats.dart
    - lib/features/vpn_logs/domain/entities/log_entry.dart
    - lib/features/vpn_connection/domain/repositories/vpn_repository.dart
    - lib/features/vpn_connection/domain/usecases/connect_vpn.dart
    - lib/features/vpn_connection/domain/usecases/disconnect_vpn.dart
    - lib/features/vpn_connection/domain/usecases/watch_vpn_state.dart
    - lib/features/vpn_connection/domain/usecases/sync_status.dart
    - lib/features/vpn_logs/domain/repositories/log_repository.dart
    - lib/features/vpn_logs/domain/usecases/watch_logs.dart
    - lib/core/error/failures.dart
    - test/features/vpn_connection/domain/entities/vpn_state_test.dart
  modified:
    - analysis_options.yaml

key-decisions:
  - "VpnConfig, TrafficStats, LogEntry и Failure сделаны полностью immutable value objects с const-конструкторами и полным списком props (равенство по значению)"
  - "Репозитории объявлены как abstract interface class (сигнал инверсии зависимостей); реализация живёт в data-слое (планы 03/04)"
  - "one_member_abstracts отключён в analysis_options под single-method repository-абстракции Clean Architecture (LogRepository)"
  - "VpnStartFailure принимает code и message позиционно по сигнатуре плана; VpnError.message соответствует полю контракта pigeon message из 01-01"

requirements-completed: [CORE-01]

# Metrics
duration: 5min
completed: 2026-07-13
---

# Phase 1 Plan 02: Доменное ядро Summary

**Sealed/immutable доменные модели с равенством по значению, интерфейсы репозиториев, usecases и типизированные Failure — чистый Dart, изолированный от кодогена pigeon**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-07-13T15:31:12Z
- **Completed:** 2026-07-13T15:36:02Z
- **Tasks:** 2
- **Files modified:** 14 (13 created, 1 modified)

## Accomplishments
- `VpnState` — sealed с пятью подтипами, равенство по значению через equatable; тест покрывает равенство всех подтипов и различие по `connectedSince`/`message`
- Immutable value objects `VpnConfig`, `TrafficStats`, `LogEntry` + enum `LogLevel {info, warning, error}` — const-конструкторы, полный `props`
- Интерфейсы `VpnRepository` (5 методов) и `LogRepository` (watchLogs) как `abstract interface class` — реализация отложена в data-слой
- Usecases по одному действию на класс с конструкторной инъекцией репозитория: `ConnectVpn`, `DisconnectVpn`, `WatchVpnState`, `SyncStatus`, `WatchLogs`
- `sealed Failure` с `PlatformFailure` и `VpnStartFailure` — типизация ошибок для маппинга `PlatformException` в data-слое (план 04)
- Доменная изоляция подтверждена: ни один файл `lib/features/*/domain` и `lib/core/error` не импортирует `vpn_api.g.dart`

## Task Commits

Each task was committed atomically. TDD-задача (Task 1) прошла через RED→GREEN:

1. **Task 1 (RED): падающий тест равенства VpnState и LogEntry** - `a4cb150` (test)
2. **Task 1 (GREEN): доменные модели VpnState/VpnConfig/TrafficStats/LogEntry** - `2b85376` (feat)
3. **Task 2: интерфейсы репозиториев, usecases, типизированные Failure** - `35af55f` (feat)

## Files Created/Modified
- `lib/features/vpn_connection/domain/entities/vpn_state.dart` — sealed `VpnState` по Code Example 8
- `lib/features/vpn_connection/domain/entities/vpn_config.dart` — immutable `VpnConfig(host/port/userId/serverName)`
- `lib/features/vpn_connection/domain/entities/traffic_stats.dart` — immutable `TrafficStats(rxBytes/txBytes)`
- `lib/features/vpn_logs/domain/entities/log_entry.dart` — `LogEntry(text/level/time)` + enum `LogLevel`
- `lib/features/vpn_connection/domain/repositories/vpn_repository.dart` — abstract `VpnRepository`
- `lib/features/vpn_connection/domain/usecases/{connect_vpn,disconnect_vpn,watch_vpn_state,sync_status}.dart` — usecases vpn_connection
- `lib/features/vpn_logs/domain/repositories/log_repository.dart` — abstract `LogRepository`
- `lib/features/vpn_logs/domain/usecases/watch_logs.dart` — usecase `WatchLogs`
- `lib/core/error/failures.dart` — sealed `Failure` + `PlatformFailure`/`VpnStartFailure`
- `test/features/vpn_connection/domain/entities/vpn_state_test.dart` — 11 тестов равенства/различия
- `analysis_options.yaml` — добавлен override `one_member_abstracts: false`

## Decisions Made
- Value objects `VpnConfig`/`TrafficStats`/`LogEntry` и `Failure` — полностью immutable, const-конструкторы, полный `props`. Равенство по значению нужно тестам и Bloc-переходам (перерисовка только на реальном изменении статуса)
- Репозитории — `abstract interface class`: явный сигнал контракта для инверсии зависимостей (SOLID). Реализации (`*RepositoryImpl`) появятся в data-слое планов 03/04, presentation про них не знает
- `VpnError.message` (не `description`) соответствует полю контракта pigeon `ErrorMessage.message`, переименованному в 01-01 — маппинг в data-слое ляжет один-в-один
- `VpnStartFailure(code, message)` — позиционные параметры по сигнатуре плана; `PlatformFailure(message)` покрывает общий случай `PlatformException`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Отключение one_member_abstracts под repository-абстракции**
- **Found during:** Task 2 (verify — flutter analyze)
- **Issue:** very_good_analysis 10.3.0 выдавал info `one_member_abstracts` на `LogRepository` (single-method abstract) с рекомендацией заменить интерфейс на top-level функцию. Модификаторы класса (`abstract interface class`) правило не подавляют; `sealed` неприменим — реализация репозитория живёт в другой библиотеке (data-слой), а sealed запрещает имплементацию вне своей библиотеки
- **Fix:** В `analysis_options.yaml` добавлен `one_member_abstracts: false`. Single-method repository-интерфейс — обязательный элемент feature-first Clean Architecture (CONVENTIONS.md: зависимости только через абстракции domain-слоя), а не случайная однометодная абстракция. Аналогично прецеденту 01-01, где VGA-правила переопределялись под форсированную/обязательную структуру
- **Files modified:** analysis_options.yaml
- **Verification:** `flutter analyze` → No issues found (весь проект); `flutter test` → 11 passed
- **Committed in:** `35af55f` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Override линта не расширяет скоуп и не меняет контракт — только снимает конфликт VGA с обязательной архитектурной формой. Границы фазы соблюдены: тронуты только domain-слой, `core/error` и Wave-0 тест; data/presentation/native не затронуты.

## Issues Encountered
- Изначальное предположение о конфликте длинных package-импортов с `lines_longer_than_80_chars` не подтвердилось: правило игнорирует однотокенные URI в директивах импорта, deep-пути feature-first не флагаются. `always_use_package_imports` соблюдён без обходов

## TDD Gate Compliance
Task 1 (`tdd="true"`) прошёл полный цикл: RED-коммит `a4cb150` (`test(01-02)`, тест падал на отсутствии сущностей) → GREEN-коммит `2b85376` (`feat(01-02)`, 11 тестов зелёные). REFACTOR не потребовался — реализация минимальна. Gate-последовательность test→feat присутствует в git-истории.

## User Setup Required
None — чистый Dart-домен, внешней конфигурации не требуется.

## Next Phase Readiness
- CORE-01 закрыт на уровне моделей и тестов: sealed/immutable типы, равенство, типизированные Failure зафиксированы
- Data-слой (планы 03/04) реализует `VpnRepository`/`LogRepository` и маппит `VpnConfigMessage`/`VpnEventMessage`/`ErrorMessage.message` → доменные типы и `Failure`
- Presentation (план 07) строит Bloc поверх usecases `WatchVpnState`/`ConnectVpn`/`DisconnectVpn`/`SyncStatus`/`WatchLogs` через composition root (Code Example 9)
- Границы фазы соблюдены: data/presentation/native/VLESS не тронуты

## Self-Check: PASSED

Все заявленные файлы существуют; коммиты `a4cb150`, `2b85376`, `35af55f` присутствуют в истории; `flutter analyze` и `flutter test` зелёные; домен не импортирует `vpn_api.g.dart`.

---
*Phase: 01-pigeon*
*Completed: 2026-07-13*
