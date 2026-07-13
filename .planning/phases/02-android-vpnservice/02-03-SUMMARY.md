---
phase: 02-android-vpnservice
plan: 03
subsystem: vpn
tags: [android, vpnservice, foreground-service, tun, read-loop, teardown, onrevoke, state-machine, systemexempted, kotlin]

# Dependency graph
requires:
  - phase: 02-01
    provides: "vpn/VpnConnectionState.kt (sealed + toStatusMessage + public canTransition); bridge/VpnEventBus.kt потокобезопасен (CopyOnWriteArraySet + @Volatile); minSdk 26"
  - phase: 02-02
    provides: "vpn/VpnNotificationFactory.kt (ensureChannel + building + CHANNEL_ID/NOTIFICATION_ID=1001); манифест <service> OkoVpnService (BIND_VPN_SERVICE, foregroundServiceType=systemExempted, intent-filter android.net.VpnService)"
  - phase: 01-01
    provides: "bridge/Messages.g.kt (StatusChangedMessage, LogMessage, TrafficChangedMessage, ErrorMessage, VpnStatusMessage)"
provides:
  - "vpn/OkoVpnService.kt — VpnService: onStartCommand (ACTION_CONNECT/DISCONNECT), startForeground(systemExempted) первой строкой, Builder.establish на узкую подсеть 10.111.222.0/24, read-loop с подсчётом rx, 1 Гц traffic-ticker, единый @Synchronized teardown, onRevoke/onDestroy"
  - "companion ACTION_CONNECT/ACTION_DISCONNECT/EXTRA_HOST/EXTRA_PORT/EXTRA_USER_ID/EXTRA_SERVER_NAME — контракт Intent для запуска сервиса из MainActivity (план 02-04)"
affects: [02-04, 02-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "startForeground(systemExempted) первой строкой onStartCommand через ServiceCompat — до establish, иначе краш DidNotStartInTime/MissingForegroundServiceType на API 34+"
    - "transition() рантайм-гейтит смену состояния через canTransition: недопустимый переход → error-лог + ранний return без смены state; допустимый → LogMessage(info) + StatusChangedMessage (AND-06)"
    - "Read-loop в daemon-потоке: FileInputStream(TUN) → переиспользуемый ByteArray(32767) → rx (AtomicLong), пакеты дропаются (форвардинг вне скоупа); 1 Гц ScheduledExecutorService шлёт TrafficChanged"
    - "Единый @Synchronized teardown из stopVpn/onRevoke/onDestroy: close(fd) ДО join потока (разблокирует блокирующий read), идемпотентность по Disconnected"

key-files:
  created:
    - android/app/src/main/kotlin/com/example/vpn_oko/vpn/OkoVpnService.kt
  modified: []

key-decisions:
  - "buildTunnel маршрутит только узкую подсеть 10.111.222.0/24 (addRoute), не 0.0.0.0/0 — интернет устройства жив в Connected; счётчики демонстрируются пингом в подсеть туннеля (locked decision STATE.md)"
  - "establish()==null и невалидный host/port → терминальный Error (не Disconnected): LogMessage(error) + ErrorMessage(code) + transition(Error) + stopForeground + stopSelf; кривой ввод не роняет сервис (T-2-04)"
  - "userId/UUID не читается из extras и не попадает в LogMessage — логируются только переходы состояний и причины остановки (T-2-05)"
  - "1 Гц ticker — ScheduledExecutorService (scheduleAtFixedRate); rx в AtomicLong разделён между read-loop и ticker без блокировок"

patterns-established:
  - "Сервис — единственный владелец fd, read-потока и ticker; все три гасит один teardown в фиксированном порядке (running=false → close(fd) → join → shutdown ticker)"
  - "Каждый допустимый переход = LogMessage(info) + StatusChangedMessage; каждый отклонённый = LogMessage(error) без смены state — lifecycle виден в логах для отладки"

requirements-completed: [AND-02, AND-04, AND-05, AND-06]

# Metrics
duration: 6min
completed: 2026-07-13
---

# Phase 2 Plan 03: OkoVpnService — реальный туннель, foreground-lifecycle, live-счётчики Summary

**OkoVpnService поднимает реальный TUN через Builder.establish на узкую подсеть 10.111.222.0/24, стартует foreground'ом (systemExempted) первой строкой, считает живой rx в read-loop и шлёт TrafficChanged раз в секунду; каждый путь остановки (Disconnect/onRevoke/onDestroy) сходится в единый teardown с доведением Disconnected, а каждый переход гейтится canTransition**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-07-13T20:08Z
- **Completed:** 2026-07-13T20:14Z
- **Tasks:** 2
- **Files modified:** 1 (создан)

## Accomplishments
- `class OkoVpnService : VpnService()` создан в `com.example.vpn_oko.vpn`: `onStartCommand` разбирает `ACTION_CONNECT`/`ACTION_DISCONNECT`, вызывает `ServiceCompat.startForeground(..., NOTIFICATION_ID, ..., FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED)` ПЕРВОЙ строкой (до establish) — закрывает Pitfall 2/3.
- `buildTunnel` конфигурирует `Builder` на узкую тестовую подсеть (`addRoute("10.111.222.0", 24)`, `addAddress("10.0.0.2", 32)`, `addDnsServer("1.1.1.1")`, `setMtu(1500)`) — интернет устройства жив в Connected; `0.0.0.0` в файле отсутствует.
- `transition()` рантайм-гейтит каждую смену состояния через `canTransition(state, next)` из плана 01: недопустимый переход → `LogMessage(level="error")` + ранний `return` без смены `state`; допустимый → `LogMessage(info)` + `StatusChangedMessage` (AND-06).
- `establish()==null` и невалидный host/port ведут в терминальный `Error` (не Disconnected) с `ErrorMessage` + снятием foreground + `stopSelf()` — сервис не падает на кривом вводе (T-2-04).
- Read-loop в daemon-потоке читает `FileInputStream(pfd.fileDescriptor)` в один `ByteArray(32767)`, копит rx в `AtomicLong`, дропает пакеты; `IOException` при close() в teardown проглатывается.
- 1 Гц `ScheduledExecutorService` шлёт `TrafficChangedMessage(rx, 0L)` через потокобезопасную шину; `txBytes=0` честно (обратной записи нет).
- Единый `@Synchronized teardown(reason)` из `ACTION_DISCONNECT`/`onRevoke`/косвенно `onDestroy`: идемпотентен по `Disconnected`, `close(fd)` ДО `join(500)` (разблокирует блокирующий read, Pitfall 7), гасит ticker, снимает foreground, доводит `Disconnected`.
- `onRevoke()` (приходит не на main thread) → `teardown` → события через `VpnEventBus` (доставка в Dart на main thread переиспользована из фазы 1, T-2-03).

## Task Commits

Каждая задача закоммичена атомарно:

1. **Task 1: Lifecycle — startForeground, establish, гейт переходов** - `6278bc8` (feat)
2. **Task 2: Read-loop, 1 Гц ticker, единый teardown, onRevoke** - `18f9b96` (feat)

**Plan metadata:** финальный docs-коммит (этот SUMMARY + STATE + ROADMAP + REQUIREMENTS)

## Files Created/Modified
- `android/app/src/main/kotlin/com/example/vpn_oko/vpn/OkoVpnService.kt` — VpnService: lifecycle, `buildTunnel` (узкая подсеть), `transition` (canTransition-гейт), read-loop + AtomicLong rx, 1 Гц ticker, `@Synchronized teardown`, `onRevoke`, `onDestroy`, companion с ACTION_*/EXTRA_* (172 строки, без комментариев)

## Decisions Made
- Узкий маршрут `10.111.222.0/24` вместо `0.0.0.0/0` — locked decision STATE.md: интернет устройства работает в Connected, счётчики демонстрируются пингом в подсеть туннеля.
- `establish()==null` и невалидный host/port → `Error` (терминальный), не `Disconnected`: отделяет сбой поднятия от штатной остановки; `ErrorMessage(code)` даёт Dart-стороне типизированную причину.
- `userId`/UUID не читается из Intent и не логируется — в `LogMessage` идут только имена переходов и причины остановки (T-2-05).
- `setSession` берёт `serverName` из extras (fallback `"Oko VPN"`) — единственное использование серверных данных в Builder; host/port только валидируются.
- Механизм 1 Гц — `ScheduledExecutorService.scheduleAtFixedRate` (Discretion research): один поток-планировщик, `rx` через `AtomicLong` без блокировок между read-loop и ticker.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing validation] Валидация host/port и терминальный Error на кривой ввод**
- **Found during:** Task 1
- **Issue:** План требует «host/port провалидировать на непустоту/диапазон перед использованием (T-2-04)», но не задаёт код-путь для невалидного ввода отдельно от establish-null
- **Fix:** Добавлен `failStart(code, reason)`: при `host.isBlank()` или `port !in 1..65535` эмитит `LogMessage(error)` + `ErrorMessage("invalid_config")` + `transition(Error)` + `stopForeground` + `stopSelf`; тот же путь переиспользован для `establish_failed`
- **Files modified:** android/app/src/main/kotlin/com/example/vpn_oko/vpn/OkoVpnService.kt
- **Verification:** `flutter build apk --debug` собирается; grep-критерии (Error-статус, отсутствие 0.0.0.0, canTransition) проходят
- **Committed in:** 6278bc8 (Task 1)

---

**Total deviations:** 1 auto-fixed (1 missing validation, T-2-04 mitigation)
**Impact on plan:** Замыкает угрозу T-2-04 из threat register плана; без scope creep — единственный приватный метод, переиспользуемый establish-null путём.

## Threat Model Coverage
- **T-2-04 (Tampering, host/port в Builder):** mitigated — валидация host на непустоту + port в диапазоне 1..65535 до `buildTunnel`; кривой ввод → `Error`, не краш.
- **T-2-05 (Information Disclosure, userId в logMessage):** mitigated — `EXTRA_USER_ID` не читается; `LogMessage` содержит только переходы и причины.
- **T-2-03 (Tampering/DoS, onRevoke → ложный Connected):** mitigated — `onRevoke` → единый `teardown` → `StatusChangedMessage(DISCONNECTED)` до UI через потокобезопасную шину.

## Issues Encountered
None. `flutter build apk --debug` собирается на обоих коммитах (Kotlin компилируется без ошибок); сетевой sandbox 403 на Maven Central не проявился.

## User Setup Required
None — внешняя конфигурация не требуется. Реальные механики туннеля (consent, интернет-в-Connected, видимость уведомления, рост rx при ping, onRevoke) наблюдаемы только на эмуляторе API 34+ — проверяются в плане 02-06 (manual-only по природе VpnService API).

## Next Phase Readiness
- Границы плана соблюдены: тронут только `vpn/OkoVpnService.kt`. `VpnHostApiImpl`, `MainActivity`, Dart, манифест не изменялись.
- План 02-04 свяжет старт сервиса: `MainActivity` (consent-флоу) построит `Intent(this, OkoVpnService::class.java).setAction(ACTION_CONNECT).putExtra(EXTRA_HOST/PORT/USER_ID/SERVER_NAME, ...)` и вызовет `startForegroundService`; `ACTION_DISCONNECT` — для остановки. Все константы уже в companion.
- Автогейт `flutter build apk --debug` зелёный; Dart-контракт не тронут (регресс фазы 1 не затронут).

## Self-Check: PASSED
- FOUND: android/app/src/main/kotlin/com/example/vpn_oko/vpn/OkoVpnService.kt
- FOUND commit: 6278bc8 (Task 1)
- FOUND commit: 18f9b96 (Task 2)

---
*Phase: 02-android-vpnservice*
*Completed: 2026-07-13*
