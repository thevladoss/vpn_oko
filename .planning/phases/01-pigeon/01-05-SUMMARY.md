---
phase: 01-pigeon
plan: 05
subsystem: infra
tags: [kotlin, pigeon, event-channel, stream-handler, main-thread, android, echo, host-api]

# Dependency graph
requires:
  - phase: 01-01
    provides: "Messages.g.kt — VpnHostApi.setUp, VpnEventsStreamHandler.register, PigeonEventSink, enum VpnStatusMessage UPPER_CASE, DTO/sealed VpnEventMessage"
provides:
  - "android/.../MainActivity.kt — регистрация VpnHostApi.setUp + VpnEventsStreamHandler.register в configureFlutterEngine"
  - "android/.../bridge/VpnEventBus.kt — object: кэш lastStatus + snapshot + emit + replay в addListener"
  - "android/.../bridge/VpnEventListener.kt — VpnEventsStreamHandler: доставка sink с main thread (Handler(Looper.getMainLooper())) + replay"
  - "android/.../bridge/VpnHostApiImpl.kt — echo startVpn/stopVpn/getStatus, level=\"info\""
affects: [01-07, 02]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Централизованный main-thread эмиттер: каждый sink.success через Handler(Looper.getMainLooper()).post"
    - "Native — источник истины: last-status кэш + replay в onListen + snapshot в getStatus"
    - "Контракт уровня лога: level строкой нижнего регистра, совпадающей с именами Dart-enum LogLevel"

key-files:
  created:
    - android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnEventBus.kt
    - android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnEventListener.kt
    - android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnHostApiImpl.kt
  modified:
    - android/app/src/main/kotlin/com/example/vpn_oko/MainActivity.kt

key-decisions:
  - "echo LogMessage.level = \"info\" (нижний регистр) — контракт с маппером 01-03: LogLevel.values.byName требует точного совпадения имён enum"
  - "VpnEventBus как object (singleton) — общий кэш last-status между эмиттером echo и StreamHandler-подписчиком"

patterns-established:
  - "Централизованный main-thread эмиттер: forward = { e -> mainHandler.post { sink?.success(e) } }, прямые вызовы sink из другого потока запрещены"
  - "Двойная защита от гонки старта: replay lastStatus подписчику в addListener + snapshot из кэша в getStatus"

requirements-completed: [BRG-01, BRG-02, BRG-04]

# Metrics
duration: 43min
completed: 2026-07-13
---

# Phase 1 Plan 05: Android echo-мост Summary

**Kotlin echo-мост: регистрация pigeon-реализаций в MainActivity, синтетический эмиттер событий с доставкой строго с main thread через Handler(Looper.getMainLooper()), кэш последнего статуса с replay новому подписчику и снапшотом в getStatus**

## Performance

- **Duration:** ~43 min (большая часть — первый build APK, заблокированный сетевым sandbox; чистое время реализации минуты)
- **Started:** 2026-07-13T15:39:51Z
- **Completed:** 2026-07-13T16:23:08Z
- **Tasks:** 2
- **Files modified:** 4 (3 created, 1 modified)

## Accomplishments
- VpnEventBus (object) кэширует lastStatus и snapshot, emit обновляет кэш на StatusChanged и рассылает listeners; addListener сразу реплеит lastStatus подписчику (закрывает гонку «событие раньше подписки», Pitfall 2)
- VpnEventListener доставляет каждое событие в sink строго с main thread через Handler(Looper.getMainLooper()).post — валидирует главный риск platform channels (@UiThread) на echo, до реального VpnService
- VpnHostApiImpl эмитит синтетическую цепочку startVpn: LogMessage("starting") → CONNECTING → LogMessage("tunnel up") → CONNECTED(connectedSinceEpochMs=now); stopVpn: DISCONNECTING → DISCONNECTED; getStatus() отдаёт snapshot из кэша
- echo LogMessage выставляют level="info" (нижний регистр) — совместимо с LogLevel.values.byName маппера 01-03; guard-grep подтвердил отсутствие "INFO"/"Info"
- MainActivity регистрирует VpnHostApi.setUp и VpnEventsStreamHandler.register в configureFlutterEngine; `flutter build apk --debug` собирается

## Task Commits

Each task was committed atomically:

1. **Task 1: VpnEventBus и main-thread StreamHandler** - `5b4c533` (feat)
2. **Task 2: echo VpnHostApiImpl и регистрация в MainActivity** - `1d93b0c` (feat)

**Plan metadata:** final docs commit

## Files Created/Modified
- `android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnEventBus.kt` — object: кэш lastStatus/snapshot, emit, replay в addListener
- `android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnEventListener.kt` — VpnEventsStreamHandler: доставка sink через Handler(Looper.getMainLooper()), addListener/removeListener на onListen/onCancel
- `android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnHostApiImpl.kt` — echo startVpn/stopVpn/getStatus, level="info"
- `android/app/src/main/kotlin/com/example/vpn_oko/MainActivity.kt` — configureFlutterEngine: VpnHostApi.setUp + VpnEventsStreamHandler.register

## Decisions Made
- echo LogMessage.level = "info" (строковый литерал нижнего регистра): контракт с маппером 01-03, где `LogLevel.values.byName(level)` требует точного совпадения с именами Dart-enum `LogLevel { info, warning, error }`. Верхний/смешанный регистр бросил бы ArgumentError на live-прогоне (Plan 07).
- VpnEventBus реализован как `object` (singleton): единый кэш last-status, общий между echo-эмиттером (VpnHostApiImpl) и подписчиком (VpnEventListener). На фазе реального VpnService (Phase 2) эта же шина переиспользуется сервисом-источником.
- `connectedSinceEpochMs` заполняется `System.currentTimeMillis()` только в CONNECTED; snapshot переносит rx/tx из прежнего значения (счётчики трафика на echo не растут — TrafficChanged не эмитится, это Phase 2).

## Deviations from Plan

None - код плана выполнен ровно как написано. Точные имена символов и порядок полей конструкторов (LogMessage: text, timestampMillis, level; VpnStatusSnapshotMessage: status, connectedSinceEpochMs?, rxBytes, txBytes) сверены по фактическому Messages.g.kt; регистр enum UPPER_CASE подтверждён.

## Issues Encountered
- Первый прогон `:app:compileDebugKotlin` и `flutter build apk --debug` упирались не в код, а в сетевой sandbox: Gradle получал `403 Forbidden` при загрузке `kotlin-build-tools-compat-2.3.20.jar` с Maven Central. Это инфраструктурное ограничение оболочки, не ошибка Kotlin — компиляция дошла до `:app:compileDebugKotlin` и падала только на скачивании тулинга. Перезапуск сборки с доступом в сеть прошёл: `:app:compileDebugKotlin` BUILD SUCCESSFUL, затем `flutter build apk --debug` → `Built build/app/outputs/flutter-apk/app-debug.apk`. Правок в коде не потребовалось.

## User Setup Required
None — внешняя конфигурация сервисов не требуется. VPN-permissions, Foreground Service и OkoVpnService — Phase 2 (граница фазы соблюдена).

## Next Phase Readiness
- Android-сторона echo-моста закрыта на уровне компиляции: HostApi зарегистрирован, синтетические события идут через централизованный main-thread эмиттер, last-status реплеится, snapshot доступен, level echo-логов совместим с Dart-enum. BRG-01/02/04 закрыты на Android.
- Живая end-to-end проверка (эмулятор, echo-Connect, StatusChanged/LogMessage в debug-harness) — Plan 07 (checkpoint:human-verify).
- Phase 2 (реальный VpnService) переиспользует VpnEventBus как шину источника истины и тот же main-thread паттерн доставки; добавит TrafficChanged, permissions, FGS.
- Границы фазы соблюдены: VpnService, BIND_VPN_SERVICE, foregroundServiceType, POST_NOTIFICATIONS и SDK-бампы не тронуты; Dart/iOS-файлы не изменялись.

## Self-Check: PASSED

Все заявленные файлы существуют (VpnEventBus.kt, VpnEventListener.kt, VpnHostApiImpl.kt, MainActivity.kt, 01-05-SUMMARY.md); коммиты `5b4c533` и `1d93b0c` присутствуют в истории.

---
*Phase: 01-pigeon*
*Completed: 2026-07-13*
