---
phase: 02-android-vpnservice
plan: 04
subsystem: vpn
tags: [android, kotlin, vpnservice, consent, registerForActivityResult, flutterfragmentactivity, post-notifications, pigeon, foreground-service]

# Dependency graph
requires:
  - phase: 02-01
    provides: "bridge/VpnEventBus.kt потокобезопасен (snapshot/lastStatus); vpn/VpnConnectionState.kt"
  - phase: 02-03
    provides: "vpn/OkoVpnService.kt + companion ACTION_CONNECT/ACTION_DISCONNECT/EXTRA_HOST/EXTRA_PORT/EXTRA_USER_ID/EXTRA_SERVER_NAME — Intent-контракт для старта/стопа сервиса"
  - phase: 01-01
    provides: "bridge/Messages.g.kt (VpnConfigMessage, StatusChangedMessage, LogMessage, ErrorMessage, VpnStatusMessage, VpnHostApi.setUp, VpnEventsStreamHandler.register)"
provides:
  - "bridge/VpnConsentGateway.kt — interface { connect(config); disconnect() }: абстракция consent/старта, реализуется MainActivity, потребляется VpnHostApiImpl (SOLID: bridge-слой не тянет Activity)"
  - "bridge/VpnHostApiImpl.kt — тонкий адаптер: startVpn→gateway.connect, stopVpn→gateway.disconnect, getStatus→VpnEventBus.snapshot; echo-цепочка вырезана"
  - "MainActivity.kt — FlutterFragmentActivity + VpnConsentGateway: VpnService.prepare() на каждый Connect, два registerForActivityResult (VPN-consent + POST_NOTIFICATIONS), старт/стоп OkoVpnService интентами"
affects: [02-05, 02-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Consent-флоу через FlutterFragmentActivity + registerForActivityResult (launcher'ы как поля, регистрация до STARTED); prepare() на КАЖДЫЙ connect — чужой VPN сбрасывает prepared-статус"
    - "VpnConsentGateway разрывает зависимость bridge→Activity: VpnHostApiImpl потребляет интерфейс, MainActivity его реализует (инъекция this в конструктор)"
    - "Отказ consent (RESULT_CANCELED) → терминальный статус ERROR + error-log в шину напрямую (не Disconnected) — AND-01 / Roadmap SC#1"
    - "POST_NOTIFICATIONS запрашивается только на API 33+ (единственная развилка Build.VERSION_CODES.TIRAMISU); отказ логируется warning'ом, старт VPN не блокирует"

key-files:
  created:
    - android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnConsentGateway.kt
  modified:
    - android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnHostApiImpl.kt
    - android/app/src/main/kotlin/com/example/vpn_oko/MainActivity.kt

key-decisions:
  - "RESULT_CANCELED → StatusChangedMessage(VpnStatusMessage.ERROR) + ErrorMessage(consent_denied) + LogMessage(error), не DISCONNECTED — план/Roadmap SC#1/AND-01 переопределяют устаревший пример RESEARCH Pattern 1"
  - "callback(Result.success(Unit)) отдаётся сразу (fire-and-forget): прогресс идёт событиями шины, Dart ConnectVpn совместим (echo фазы 1 вёл себя так же, A5)"
  - "styles.xml не менялся — контингенция A3 не сработала: FlutterFragmentActivity (FragmentActivity) работает с текущими Theme.Light.NoTitleBar, сборка зелёная; AppCompat/Material-тема не потребовалась"
  - "POST_NOTIFICATIONS: ContextCompat.checkSelfPermission — запрос только если не выдан и API>=33; отказ не блокирует старт (Pitfall 4)"

patterns-established:
  - "MainActivity владеет consent/стартом сервиса, VpnHostApiImpl остаётся тонким — граница Activity/bridge держится через VpnConsentGateway"
  - "userId проходит в Intent extra в сервис, но НЕ логируется в MainActivity — в LogMessage идут только причины (permission denied / notifications denied), T-2-05"

requirements-completed: [AND-01, AND-03, AND-06]

# Metrics
duration: 2min
completed: 2026-07-13
---

# Phase 2 Plan 04: Consent-флоу и Pigeon-делегирование в реальный сервис Summary

**Тап Connect из Flutter проходит системный VpnService.prepare() на каждый вызов через FlutterFragmentActivity + registerForActivityResult; согласие поднимает OkoVpnService (startForegroundService + EXTRA_*), отказ доводит терминальный ERROR с логом, а VpnHostApiImpl схлопнут в тонкий адаптер над интерфейсом VpnConsentGateway**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-07-13T20:21:08Z
- **Completed:** 2026-07-13T20:23Z
- **Tasks:** 2
- **Files modified:** 3 (1 создан, 2 переписаны)

## Accomplishments
- `interface VpnConsentGateway { connect(config); disconnect() }` создан в `bridge` — абстракция разрывает зависимость bridge→Activity (SOLID): `VpnHostApiImpl` потребляет интерфейс, `MainActivity` его реализует.
- `VpnHostApiImpl` переписан в тонкий адаптер `VpnHostApiImpl(private val gateway: VpnConsentGateway)`: `startVpn`→`gateway.connect` + мгновенный `callback(success)`, `stopVpn`→`gateway.disconnect`, `getStatus`→`VpnEventBus.snapshot`; вся синтетическая echo-эмиссия (starting/tunnel up, CONNECTING/CONNECTED) вырезана — источник статусов теперь реальный сервис.
- `MainActivity` переведён с `FlutterActivity` на `io.flutter.embedding.android.FlutterFragmentActivity` и реализует `VpnConsentGateway` — `registerForActivityResult` резолвится (Pitfall 1 закрыт).
- Два launcher'а полями: VPN-consent (`StartActivityForResult`) и POST_NOTIFICATIONS (`RequestPermission`), регистрация до `STARTED`.
- `connect(config)`: `VpnService.prepare(this)` на КАЖДЫЙ вызов (не кэшируется); `null` → сразу `startVpnService`, иначе `pendingConfig=config; vpnConsent.launch(consent)`.
- RESULT_OK → `startForegroundService(Intent(ACTION_CONNECT) + EXTRA_HOST/PORT/USER_ID/SERVER_NAME)`; `EXTRA_PORT` через `putExtra(key, config.port)` (Long).
- RESULT_CANCELED → `LogMessage("VPN permission denied", error)` + `ErrorMessage("consent_denied", …)` + `StatusChangedMessage(VpnStatusMessage.ERROR)` — терминальный Error, не Disconnected (AND-01 / Roadmap SC#1).
- POST_NOTIFICATIONS запрашивается только на API 33+ (`Build.VERSION_CODES.TIRAMISU`) и только если не выдан (`ContextCompat.checkSelfPermission`); отказ → `LogMessage(warning)`, старт VPN не блокируется.
- `disconnect()` → `startService(Intent(ACTION_DISCONNECT))`; регистрация Pigeon (`VpnHostApi.setUp(messenger, VpnHostApiImpl(this))` + `VpnEventsStreamHandler.register(messenger, VpnEventListener())`) пережила смену базового класса.

## Task Commits

Каждая задача закоммичена атомарно:

1. **Task 1: VpnConsentGateway + тонкий VpnHostApiImpl** - `7bcbec4` (feat)
2. **Task 2: MainActivity → FlutterFragmentActivity + consent-флоу** - `733e2d3` (feat)

**Plan metadata:** финальный docs-коммит (этот SUMMARY + STATE + ROADMAP + REQUIREMENTS)

## Files Created/Modified
- `android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnConsentGateway.kt` — новый interface `VpnConsentGateway` с `connect(config)`/`disconnect()` (без комментариев).
- `android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnHostApiImpl.kt` — тонкий адаптер над gateway, echo-цепочка удалена, `getStatus`→snapshot.
- `android/app/src/main/kotlin/com/example/vpn_oko/MainActivity.kt` — `FlutterFragmentActivity`, `VpnConsentGateway`, два launcher'а, `prepare()` на каждый connect, старт/стоп сервиса интентами, POST_NOTIFICATIONS на API 33+ (без комментариев).

## Decisions Made
- **RESULT_CANCELED → ERROR, не DISCONNECTED:** план (строка 120) / Roadmap SC#1 / AND-01 переопределяют устаревший пример RESEARCH Pattern 1 (там был `DISCONNECTED`). Отказ consent — терминальный сбой с типизированной причиной `consent_denied`, а не штатная остановка.
- **fire-and-forget callback:** `callback(Result.success(Unit))` отдаётся сразу после делегирования в gateway — прогресс приходит событиями шины. Совместимо с Dart `ConnectVpn` (echo фазы 1 вёл себя так же, A5).
- **styles.xml не тронут:** контингенция A3 не сработала. `FlutterFragmentActivity` наследует `androidx.fragment.app.FragmentActivity` (не `AppCompatActivity`), которая работает с платформенными темами `Theme.Light.NoTitleBar`; `flutter build apk --debug` зелёный без правки темы. Правка отложена — реальный запуск проверяется на эмуляторе в плане 02-06.
- **POST_NOTIFICATIONS-запрос идемпотентен по факту выдачи:** `ContextCompat.checkSelfPermission` перед `launch` — не спамим диалог, если разрешение уже есть (Pitfall 4).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Build-гейт Task 1 перенесён на Task 2 (сцепка компиляции через конструктор)**
- **Found during:** Task 1 (VpnConsentGateway + VpnHostApiImpl)
- **Issue:** Смена `VpnHostApiImpl()` → `VpnHostApiImpl(gateway: VpnConsentGateway)` ломает вызов `VpnHostApiImpl()` в старом `MainActivity`; изолированная сборка Task 1 не могла быть зелёной, а gateway у `MainActivity` появляется только в Task 2. Хуков нет — промежуточный некомпилирующийся коммит механически возможен.
- **Fix:** Task 1 закоммичен по grep-критериям (интерфейс, конструктор, отсутствие echo, snapshot); `flutter build apk --debug` прогнан после Task 2, где связка `VpnHostApiImpl(this)` + `FlutterFragmentActivity, VpnConsentGateway` компилируется как единое целое.
- **Files modified:** — (сцепка планирования, не изменение файлов сверх плана)
- **Verification:** `flutter build apk --debug` → `✓ Built build/app/outputs/flutter-apk/app-debug.apk` после Task 2.
- **Committed in:** 7bcbec4 (Task 1) + 733e2d3 (Task 2)

---

**Total deviations:** 1 (Rule 3 — сцепка сборки двух связанных тасков)
**Impact on plan:** Границы файлов соблюдены, никакого scope creep. Оба Kotlin-файла компилируются как один связный рефактор; wave-level гейт (`flutter build apk --debug`) зелёный.

## Threat Model Coverage
- **T-2-06 (Spoofing/EoP, старт VPN без согласия):** mitigated — `VpnService.prepare(this)` вызывается на КАЖДЫЙ `connect`, не кэшируется; при отсутствии согласия сервис не стартует, `establish()` в 02-03 вернёт null.
- **T-2-05 (Information Disclosure, userId в логах):** mitigated — `EXTRA_USER_ID` кладётся в Intent, но в `LogMessage` из `MainActivity` попадают только причины (`VPN permission denied`, `notifications denied`); creds не логируются.

## Issues Encountered
None. `flutter build apk --debug` собирается зелёным после Task 2. Реальный consent-диалог, RESULT_OK→Connected, Cancel→Error, видимость уведомления и запуск с новой темой (A1–A3) наблюдаемы только на эмуляторе API 34+ — проверяются в плане 02-06.

## Known Stubs
None — заглушек/плейсхолдеров/TODO нет; consent-флоу и делегирование реализованы полностью.

## User Setup Required
None — внешняя конфигурация не требуется. Ручная проверка на эмуляторе API 34+ (consent-диалог, POST_NOTIFICATIONS, тема FlutterFragmentActivity) вынесена в план 02-06 по природе VpnService API.

## Next Phase Readiness
- Границы плана соблюдены: тронуты только `bridge/VpnConsentGateway.kt`, `bridge/VpnHostApiImpl.kt`, `MainActivity.kt`. `OkoVpnService` (02-03), `VpnEventBus`/state (02-01), Dart harness (02-05) не менялись; `styles.xml` не тронут.
- Команда Connect замкнута на реальный сервис через системный consent; план 02-05 (Dart harness / интеграция UI) и 02-06 (эмулятор-чеклист) готовы к запуску.
- Автогейт `flutter build apk --debug` зелёный; Pigeon-контракт и регресс фазы 1 не затронуты (изменения — чистый Kotlin).

## Self-Check: PASSED
- FOUND: android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnConsentGateway.kt
- FOUND: android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnHostApiImpl.kt
- FOUND: android/app/src/main/kotlin/com/example/vpn_oko/MainActivity.kt
- FOUND commit: 7bcbec4 (Task 1)
- FOUND commit: 733e2d3 (Task 2)

---
*Phase: 02-android-vpnservice*
*Completed: 2026-07-13*
