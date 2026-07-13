---
phase: 02-android-vpnservice
plan: 02
subsystem: infra
tags: [android, manifest, vpnservice, foreground-service, systemexempted, notificationchannel, bind-vpn-service, kotlin]

# Dependency graph
requires:
  - phase: 02-01
    provides: "minSdk 26 (build.gradle.kts) — безветочные NotificationChannel/startForegroundService; vpn/ пакет заведён (VpnConnectionState.kt)"
provides:
  - "AndroidManifest.xml — permissions FOREGROUND_SERVICE / FOREGROUND_SERVICE_SYSTEM_EXEMPTED / POST_NOTIFICATIONS + декларация <service> .vpn.OkoVpnService (BIND_VPN_SERVICE, foregroundServiceType=systemExempted, exported=false, intent-filter android.net.VpnService)"
  - "vpn/VpnNotificationFactory.kt — ensureChannel() (NotificationChannel oko_vpn, IMPORTANCE_LOW) + building(text): Notification (ongoing) для startForeground; companion CHANNEL_ID/NOTIFICATION_ID(1001)"
affects: [02-03, 02-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "FGS-декларация типа systemExempted в манифесте + одноимённый permission — предотвращает MissingForegroundServiceTypeException на Android 14+ (T-2-03)"
    - "Сервис с android:permission=BIND_VPN_SERVICE + exported=false + intent-filter android.net.VpnService — биндится только системный VPN-framework (T-2-02)"
    - "Фабрика уведомления отделена от сервиса: канал (API 26) и ongoing-нотификация строятся до startForeground; NOTIFICATION_ID экспортируется через companion для вызова сервисом плана 03"

key-files:
  created:
    - android/app/src/main/kotlin/com/example/vpn_oko/vpn/VpnNotificationFactory.kt
  modified:
    - android/app/src/main/AndroidManifest.xml

key-decisions:
  - "Манифест ссылается на .vpn.OkoVpnService, класс сервиса появится в плане 02-03; manifest merger не проверяет существование класса, debug-сборка проходит"
  - "android.R.drawable.stat_sys_vpn_ic из RESEARCH-примера не публичный ресурс фреймворка → заменён на android.R.drawable.ic_lock_lock (падлок, проверен по android.jar android-36)"
  - "NOTIFICATION_ID=1001 объявлен в companion — сервис плана 03 передаст его в ServiceCompat.startForeground"

patterns-established:
  - "Платформенная FGS-обвязка (permissions + service + foregroundServiceType) отделена от Kotlin-реализации сервиса; манифест-декларации закрывают T-2-02/T-2-03 ещё до появления кода сервиса"
  - "Уведомление FGS строится через VpnNotificationFactory с явным NotificationChannel (обязателен на API 26+); IMPORTANCE_LOW + setOngoing(true) для непрерывного статуса без звука"

requirements-completed: [AND-03]

# Metrics
duration: 2min
completed: 2026-07-13
---

# Phase 2 Plan 02: Манифест FGS-обвязки + фабрика уведомления Summary

**AndroidManifest декларирует VPN-сервис OkoVpnService (BIND_VPN_SERVICE, foregroundServiceType=systemExempted, exported=false, intent-filter android.net.VpnService) с permissions FGS/systemExempted/POST_NOTIFICATIONS; VpnNotificationFactory строит канал API 26 и ongoing-уведомление для startForeground**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-07-13T20:03:11Z
- **Completed:** 2026-07-13T20:05:55Z
- **Tasks:** 2
- **Files modified:** 2 (1 создан, 1 изменён)

## Accomplishments
- Манифест объявляет три permission (FOREGROUND_SERVICE, FOREGROUND_SERVICE_SYSTEM_EXEMPTED, POST_NOTIFICATIONS) и декларирует `<service>` OkoVpnService с типом FGS systemExempted и intent-filter android.net.VpnService
- Замкнуты угрозы T-2-02 (BIND_VPN_SERVICE + exported=false — биндится только система) и T-2-03 (systemExempted — нет краша startForeground на Android 14+)
- VpnNotificationFactory создаёт NotificationChannel (oko_vpn, IMPORTANCE_LOW) и ongoing-уведомление; NOTIFICATION_ID=1001 готов для startForeground сервиса плана 03

## Task Commits

Каждая задача закоммичена атомарно:

1. **Task 1: Манифест — permissions и декларация VPN-сервиса** - `6ea8c14` (feat)
2. **Task 2: VpnNotificationFactory (канал + ongoing-уведомление)** - `d09e74e` (feat)

**Plan metadata:** финальный docs-коммит (STATE/ROADMAP/REQUIREMENTS/SUMMARY)

## Files Created/Modified
- `android/app/src/main/AndroidManifest.xml` — три uses-permission + `<service>` OkoVpnService (BIND_VPN_SERVICE, foregroundServiceType=systemExempted, exported=false, intent-filter action android.net.VpnService)
- `android/app/src/main/kotlin/com/example/vpn_oko/vpn/VpnNotificationFactory.kt` — ensureChannel() + building(text) + companion CHANNEL_ID/NOTIFICATION_ID

## Decisions Made
- Манифест ссылается на `.vpn.OkoVpnService` до появления класса (план 02-03); manifest merger не резолвит класс — debug-сборка проходит
- `NOTIFICATION_ID=1001` вынесен в companion object для вызова сервисом плана 03

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Несуществующий публичный ресурс иконки в примере RESEARCH**
- **Found during:** Task 2 (VpnNotificationFactory)
- **Issue:** `android.R.drawable.stat_sys_vpn_ic` из code-примера 02-RESEARCH.md — не публичный ресурс фреймворка; компиляция Kotlin падала с `Unresolved reference 'stat_sys_vpn_ic'` (и каскадом `setOngoing` на error-типе цепочки)
- **Fix:** Заменил на публичный `android.R.drawable.ic_lock_lock` (иконка-падлок, семантически подходит VPN); валидность проверена `javap` по `android.jar` (android-36) — `ic_lock_lock` присутствует в `android.R$drawable`
- **Files modified:** android/app/src/main/kotlin/com/example/vpn_oko/vpn/VpnNotificationFactory.kt
- **Verification:** `flutter build apk --debug` собирается; grep-критерии (NotificationChannel, setOngoing(true), IMPORTANCE_LOW, CHANNEL_ID, NOTIFICATION_ID) проходят
- **Committed in:** d09e74e (коммит Task 2)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Фикс обязателен для компиляции; семантика иконки сохранена (падлок вместо VPN-значка). Без scope creep — правка в единственной строке setSmallIcon.

## Issues Encountered
- SDK-хендлеры `state.record-metric` и `state.add-decision` требуют named-флаги (`--phase`, `--plan`, `--duration`, `--summary`), а не позиционные аргументы из шаблона execute-plan; вызовы повторены с флагами — STATE.md обновлён корректно.

## User Setup Required
None — внешняя конфигурация не требуется.

## Next Phase Readiness
- Платформенная FGS-обвязка готова: план 02-03 реализует `OkoVpnService` (класс уже объявлен в манифесте) и вызовет `VpnNotificationFactory.ensureChannel()` + `building()` в `ServiceCompat.startForeground(..., NOTIFICATION_ID, ..., FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED)`
- Визуальная видимость уведомления, отсутствие FGS-краша и runtime POST_NOTIFICATIONS проверяются на эмуляторе API 34+ в phase-gate (план 02-06)

## Self-Check: PASSED
- FOUND: android/app/src/main/AndroidManifest.xml (modified)
- FOUND: android/app/src/main/kotlin/com/example/vpn_oko/vpn/VpnNotificationFactory.kt (created)
- FOUND commit: 6ea8c14 (Task 1)
- FOUND commit: d09e74e (Task 2)

---
*Phase: 02-android-vpnservice*
*Completed: 2026-07-13*
