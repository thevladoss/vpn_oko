---
phase: 02-android-vpnservice
plan: 01
subsystem: infra
tags: [kotlin, threadsafe, copyonwritearrayset, volatile, state-machine, sealed-interface, junit, gradle, minsdk]

# Dependency graph
requires:
  - phase: 01-05
    provides: "bridge/VpnEventBus.kt (object: кэш lastStatus/snapshot + emit + replay), Messages.g.kt (VpnStatusMessage UPPER_CASE, sealed VpnEventMessage, StatusChangedMessage, TrafficChangedMessage, VpnStatusSnapshotMessage)"
provides:
  - "bridge/VpnEventBus.kt — потокобезопасная шина: CopyOnWriteArraySet<listener> + @Volatile lastStatus/snapshot; emit безопасен из любого потока"
  - "vpn/VpnConnectionState.kt — sealed interface (Disconnected/Connecting/Connected(sinceEpochMs)/Disconnecting/Error(code)) + toStatusMessage() + public top-level canTransition()"
  - "android/app/build.gradle.kts — minSdk 26, testImplementation junit:junit:4.13.2"
  - "test/.../VpnConnectionStateTest.kt — JUnit-гейт таблицы переходов (4 теста)"
affects: [02-03]

# Tech tracking
tech-stack:
  added: ["junit:junit:4.13.2 (testImplementation)"]
  patterns:
    - "Потокобезопасная шина событий: CopyOnWriteArraySet для listeners + @Volatile для кэш-полей — emit из read-loop/ticker/onRevoke без ConcurrentModificationException"
    - "Чистая (JVM-тестируемая) машина состояний в отдельном файле без Android-импортов — единственный юнит-тестируемый кусок фазы"
    - "canTransition — public top-level рантайм-контракт, сравнение по типу состояния (не по payload), переход в Error разрешён из любого состояния"

key-files:
  created:
    - android/app/src/main/kotlin/com/example/vpn_oko/vpn/VpnConnectionState.kt
    - android/app/src/test/kotlin/com/example/vpn_oko/vpn/VpnConnectionStateTest.kt
  modified:
    - android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnEventBus.kt
    - android/app/build.gradle.kts

key-decisions:
  - "canTransition — public top-level функция (не private, не тестовый хелпер): OkoVpnService.transition() из плана 03 обязан звать её как рантайм-гейт перед каждой сменой состояния"
  - "Сравнение переходов по типу состояния, а не по payload — Connected(sinceEpochMs) и Error(code) матчатся через is, allowlist переходов не зависит от значений"
  - "minSdk поднят до 26 (override дефолта Flutter 24) — безветочные NotificationChannel и startForegroundService для FGS в планах 02/03"

patterns-established:
  - "Шина событий потокобезопасна на уровне коллекции и полей: CopyOnWriteArraySet + @Volatile, публичный API addListener/removeListener/emit/lastStatus/snapshot неизменен — доставка в sink остаётся main-thread в VpnEventListener"
  - "Машина состояний вынесена в vpn/ без Android-зависимостей и покрыта JUnit — таблица допустимых И недопустимых переходов проверяется автогейтом gradle :app:testDebugUnitTest"

requirements-completed: [AND-06]

# Metrics
duration: 3min
completed: 2026-07-13
---

# Phase 2 Plan 01: Потокобезопасная шина + машина состояний Summary

**VpnEventBus укреплён CopyOnWriteArraySet + @Volatile под многопоточный emit, введена чистая Kotlin-машина состояний VpnConnectionState с public canTransition-гейтом и JUnit-таблицей переходов; minSdk поднят до 26, подключён junit**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-07-13T19:55:27Z
- **Completed:** 2026-07-13T19:58:58Z
- **Tasks:** 2 (Task 2 — TDD: RED → GREEN)
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments
- VpnEventBus переведён на `CopyOnWriteArraySet` для listeners и `@Volatile` для `lastStatus`/`snapshot` — emit безопасен из read-loop, 1 Гц ticker и `onRevoke` (не main thread) без `ConcurrentModificationException` и порванного snapshot (Pitfall 5 / T-2-01). Публичный API и логика emit/addListener/removeListener неизменны.
- Введён `sealed interface VpnConnectionState` (Disconnected/Connecting/Connected(sinceEpochMs)/Disconnecting/Error(code)) в отдельном файле без Android-импортов — исполняется на чистом JVM.
- `toStatusMessage()` маппит каждое из пяти состояний в `VpnStatusMessage`; public top-level `canTransition(from, to)` — рантайм-гейт переходов для OkoVpnService (план 03), сравнение по типу состояния, переход в Error разрешён из любого состояния.
- JUnit-автогейт: 4 теста (маппинг статусов + допустимые + переход-в-Error-из-любого + недопустимые переходы), все зелёные через `:app:testDebugUnitTest`.
- minSdk 24→26 в build.gradle.kts, добавлен `testImplementation("junit:junit:4.13.2")`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Потокобезопасный VpnEventBus** - `b27f2a7` (feat)
2. **Task 2: Машина состояний + junit — RED** - `6d133b3` (test)
3. **Task 2: Машина состояний + junit — GREEN** - `82369fc` (feat)

**Plan metadata:** final docs commit (this SUMMARY + STATE + ROADMAP)

_TDD-задача дала два коммита: test (RED) → feat (GREEN)._

## Files Created/Modified
- `android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnEventBus.kt` — listeners → CopyOnWriteArraySet, lastStatus/snapshot → @Volatile (private set сохранён), логика emit/replay неизменна
- `android/app/src/main/kotlin/com/example/vpn_oko/vpn/VpnConnectionState.kt` — sealed interface состояний + toStatusMessage() + public top-level canTransition()
- `android/app/build.gradle.kts` — minSdk = 26, top-level dependencies { testImplementation("junit:junit:4.13.2") }
- `android/app/src/test/kotlin/com/example/vpn_oko/vpn/VpnConnectionStateTest.kt` — 4 JUnit4-теста таблицы переходов и маппинга

## Decisions Made
- `canTransition` объявлена public top-level (не private, не test-only): это рантайм-контракт, а не тестовый хелпер — `OkoVpnService.transition()` из плана 03 обязан звать её перед каждой сменой состояния и отклонять недопустимые переходы.
- Переходы сравниваются по типу состояния, не по payload: `Connected(sinceEpochMs)` и `Error(code)` матчатся через `is`, поэтому allowlist переходов не зависит от значений полей. Переход в `Error` разрешён из любого состояния коротким `if (to is Error) return true`.
- minSdk = 26 зашит числом (override дефолта Flutter `flutter.minSdkVersion` = 24): убирает ветвления `Build.VERSION` вокруг NotificationChannel и startForegroundService — согласуется с требованием «без комментариев/чистый код» и планами FGS 02/03. compileSdk/targetSdk оставлены на дефолтах Flutter (36).

## Deviations from Plan

None - план выполнен ровно как написан. Символы Messages.g.kt (enum VpnStatusMessage UPPER_CASE, sealed VpnEventMessage, конструкторы StatusChangedMessage/VpnStatusSnapshotMessage) сверены по фактическому файлу; VpnEventListener не тронут (main-thread доставка переиспользуется как есть).

## TDD Gate Compliance
Task 2 прошёл полный цикл gate-коммитов:
- **RED** (`6d133b3`, `test`): junit + minSdk + тест-файл; `:app:testDebugUnitTest` падает на `Unresolved reference 'VpnConnectionState'`/`'canTransition'` — тест доказанно проверяет реальные символы.
- **GREEN** (`82369fc`, `feat`): реализация `VpnConnectionState.kt`; `:app:testDebugUnitTest` — 4 теста зелёные (tests=4, failures=0, errors=0).
- REFACTOR не потребовался.

## Issues Encountered
None. Сетевой sandbox (403 на Maven Central из фазы 1) в этот раз не проявился: gradle-компиляция, `:app:testDebugUnitTest` и `flutter build apk --debug` прошли без отключения sandbox.

## User Setup Required
None — внешняя конфигурация сервисов не требуется. junit тянется из Maven Central штатно, в рантайм приложения не входит.

## Next Phase Readiness
- Границы плана соблюдены: тронуты только шина, машина состояний, gradle и junit-тест. Сервис (02-03), манифест/permissions (02-02) и Dart/iOS не изменялись.
- Сервис из плана 03 может безопасно эмитить события из read-loop/ticker/onRevoke через укреплённый `VpnEventBus` и использовать public `canTransition` как рантайм-гейт переходов (`transition()` строит `LogMessage` + `StatusChangedMessage` из `toStatusMessage()`).
- Автогейт `:app:testDebugUnitTest` подключён — последующие изменения таблицы переходов ловятся тестом.
- Полный регресс фазы 1 зелёный: `flutter analyze` без замечаний, `flutter test` — 46 тестов проходят, `flutter build apk --debug` собирается.

## Self-Check: PASSED

Все заявленные файлы существуют (VpnEventBus.kt, VpnConnectionState.kt, VpnConnectionStateTest.kt, build.gradle.kts, 02-01-SUMMARY.md); коммиты `b27f2a7`, `6d133b3`, `82369fc` присутствуют в истории.

---
*Phase: 02-android-vpnservice*
*Completed: 2026-07-13*
