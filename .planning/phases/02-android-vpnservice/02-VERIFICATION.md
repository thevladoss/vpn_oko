---
phase: 02-android-vpnservice
verified: 2026-07-13T20:53:38Z
status: passed
score: 10/10 must-haves verified
has_blocking_gaps: false
overrides_applied: 0
re_verification:
  previous_status: none
  note: initial verification
---

# Phase 2: Android VpnService — Verification Report

**Phase Goal:** Реальный VPN-туннель на Android поднимается через consent-флоу (VpnService.prepare), живёт в Foreground Service, шлёт живые события статусов/логов/трафика во Flutter. Заменяет echo-реализацию Android из фазы 1, сохраняя Pigeon-контракт.
**Verified:** 2026-07-13T20:53:38Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

Цель достигнута. Все 5 success criteria ROADMAP и все 6 требований AND-01..06 подтверждены кодом, зелёными автогейтами (сборка Kotlin, `flutter analyze`, `flutter test`, JUnit state-machine) и живым device-чеклистом на эмуляторе API 36. Стабов, debt-маркеров и комментариев в коде нет.

### Observable Truths

| #  | Truth | Status | Evidence |
| -- | ----- | ------ | -------- |
| 1  | Connect вызывает `VpnService.prepare`; RESULT_OK → Connected + значок VPN, RESULT_CANCELED → **Error** (не Disconnected) + внятный лог (SC1 / AND-01) | ✓ VERIFIED | `MainActivity.connect()` зовёт `VpnService.prepare(this)` на каждый Connect; `consent==null` → сразу `startVpnService`; RESULT_OK → `startForegroundService(ACTION_CONNECT)`; else-ветка эмитит `LogMessage("VPN permission denied","error")` + `ErrorMessage("consent_denied",…)` + `StatusChangedMessage(ERROR)`. Device: consent OK → Connected + 🔑, Cancel → Error + лог |
| 2  | Builder поднимает туннель на узкую подсеть 10.111.222.0/24 (нет 0.0.0.0), интернет жив; `establish()==null` обработан (SC2 / AND-02) | ✓ VERIFIED | `OkoVpnService.buildTunnel`: `addAddress("10.0.0.2",32)`, `addRoute("10.111.222.0",24)`, `addDnsServer("1.1.1.1")`, `setMtu(1500)`, `establish()`. grep: `0.0.0.0` в kotlin отсутствует. `establish()==null` → `failStart("establish_failed",…)`. Device: `Routes: 10.111.222.0/24 -> tun0` |
| 3  | FGS-уведомление с Connecting; манифест BIND_VPN_SERVICE + intent-filter `android.net.VpnService` + systemExempted + permissions; POST_NOTIFICATIONS на 13+; startForeground первым действием connect-пути; NotificationChannel (API 26); нет краша API 34+ (SC3 / AND-03) | ✓ VERIFIED | Manifest: 3 permissions (FOREGROUND_SERVICE, FOREGROUND_SERVICE_SYSTEM_EXEMPTED, POST_NOTIFICATIONS), `<service android:name=".vpn.OkoVpnService" android:permission="…BIND_VPN_SERVICE" android:foregroundServiceType="systemExempted">` + intent-filter `android.net.VpnService`. `onStartCommand` после гардов DISCONNECT/null первым делом `ensureChannel()` + `ServiceCompat.startForeground(… SYSTEM_EXEMPTED)` с текстом "Connecting…". `MainActivity.ensureNotificationPermission()` рантайм-запрос на TIRAMISU+. Device API 36: `id=1001 channel=oko_vpn`, краша нет |
| 4  | TUN read-loop считает реальные rx; 1Гц ticker шлёт TrafficChanged (SC4 / AND-05) | ✓ VERIFIED | `startReadLoop`: `FileInputStream(pfd.fileDescriptor).read(buffer)` → `rx.addAndGet(read)`. `startTrafficTicker`: `scheduleAtFixedRate(… TrafficChangedMessage(rx.get(),0L), 1,1,SECONDS)`. Device: UI `rx: 200 B` (реальные байты из tun0). tx=0 честно (нет write-пути без core) |
| 5  | Disconnect и onRevoke сходятся в единый `teardown()` → Disconnected (close fd до join); каждый переход = logMessage (SC5 / AND-04) | ✓ VERIFIED | `ACTION_DISCONNECT` → `teardown`; `onRevoke()` → `teardown`. `teardown`: `running.set(false)` → `tunnel?.close()` → `readThread?.join(500)` (fd закрыт ДО join) → `shutdownNow` ticker → `stopForeground` → transition Disconnecting→Disconnected → `stopSelf`. `@Synchronized`. Device: Disconnect → Disconnected, переходы в логах. onRevoke live не триггерился (нет 2-го VPN), покрыт кодом — тот же teardown, симметричен проверенному Disconnect |
| 6  | `transition()` гейтит через `canTransition` + логирует каждый переход; недопустимый отклоняется (ранний return + error-лог), state не меняется (AND-06) | ✓ VERIFIED | `transition()`: `if(!canTransition(state,next)){ emit LogMessage("illegal transition…","error"); return }` — state не меняется; иначе `state=next` + `LogMessage("state -> …","info")` + `StatusChangedMessage`. JUnit 4/4: valid/invalid/error-from-any/mapping зелёные |
| 7  | `VpnEventBus.emit` вызывается из рабочих потоков без ConcurrentModificationException; события уходят на main thread | ✓ VERIFIED | `VpnEventBus`: `CopyOnWriteArraySet` listeners, `@Volatile lastStatus/snapshot`, `emit` итерирует `listeners.toList()`. `VpnEventListener` форвардит через `Handler(Looper.getMainLooper()).post{ sink.success }`. Device: 3 цикла без FATAL/ConcurrentModification |
| 8  | `VpnHostApiImpl` делегирует в `VpnConsentGateway`, `getStatus` → snapshot шины; MainActivity — FlutterFragmentActivity (AND-01, SOLID) | ✓ VERIFIED | `VpnHostApiImpl(gateway)`: `startVpn→gateway.connect`, `stopVpn→gateway.disconnect`, `getStatus→VpnEventBus.snapshot`. `MainActivity : FlutterFragmentActivity(), VpnConsentGateway`; регистрация `VpnHostApi.setUp` + `VpnEventsStreamHandler.register` |
| 9  | Debug-harness показывает живые rx/tx из trafficChanged (AND-05) | ✓ VERIFIED | `di.dart`: `watchTraffic()=>vpnRepository.watchTraffic()`. `main.dart`: `StreamBuilder<TrafficStats>` рендерит `rx: ${stats?.rxBytes} B  tx: ${stats?.txBytes} B` из `_trafficStream = widget.dependencies.watchTraffic()` — реальный поток native→Flutter |
| 10 | minSdk 26; Kotlin компилируется; Dart-регресс зелёный; JUnit state-machine зелёный | ✓ VERIFIED | `build.gradle.kts`: `minSdk = 26`, `testImplementation("junit:junit:4.13.2")`. `flutter build apk --debug` → BUILD SUCCESS. `flutter analyze` → No issues. `flutter test` → 46 passed. `./gradlew :app:testDebugUnitTest` → 4 tests, 0 failures |

**Score:** 10/10 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `android/.../bridge/VpnEventBus.kt` | Потокобезопасная шина CopyOnWriteArraySet + @Volatile | ✓ VERIFIED | `CopyOnWriteArraySet`, `@Volatile lastStatus/snapshot`, replay в addListener |
| `android/.../vpn/VpnConnectionState.kt` | sealed-состояния + таблица переходов + toStatusMessage | ✓ VERIFIED | `sealed interface VpnConnectionState`, `canTransition`, `toStatusMessage()→VpnStatusMessage` |
| `android/.../test/.../VpnConnectionStateTest.kt` | JUnit покрытие переходов/маппинга | ✓ VERIFIED | 4 @Test, все зелёные |
| `android/.../AndroidManifest.xml` | permissions + декларация сервиса | ✓ VERIFIED | 3 permissions, service systemExempted + BIND_VPN_SERVICE + intent-filter |
| `android/.../vpn/VpnNotificationFactory.kt` | NotificationChannel + Notification.Builder | ✓ VERIFIED | `ensureChannel()` (API 26 канал), `building()` ongoing-уведомление |
| `android/.../vpn/OkoVpnService.kt` | VpnService: lifecycle, establish, read-loop, ticker, teardown, onRevoke | ✓ VERIFIED | 172 строки, все механики присутствуют и связаны |
| `android/.../bridge/VpnConsentGateway.kt` | Интерфейс абстракции consent/старта | ✓ VERIFIED | `interface VpnConsentGateway { connect/disconnect }` |
| `android/.../bridge/VpnHostApiImpl.kt` | Тонкий адаптер → gateway, getStatus → snapshot | ✓ VERIFIED | Делегирование в gateway, snapshot из шины |
| `android/.../MainActivity.kt` | FlutterFragmentActivity: launchers, prepare, старт/стоп | ✓ VERIFIED | prepare + два launcher'а + startForegroundService |
| `lib/app/di.dart` | Поток TrafficStats в harness | ✓ VERIFIED | `watchTraffic()` |
| `lib/main.dart` | StreamBuilder<TrafficStats> rx/tx readout | ✓ VERIFIED | StreamBuilder рендерит живые rx/tx |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| VpnConnectionState.kt | Messages.g.kt (VpnStatusMessage) | `toStatusMessage()` | ✓ WIRED | 5 `VpnStatusMessage.*` ссылок |
| AndroidManifest.xml | vpn/OkoVpnService | `android:name=".vpn.OkoVpnService"` | ✓ WIRED | Декларация найдена |
| OkoVpnService.kt | bridge/VpnEventBus | `VpnEventBus.emit(...)` | ✓ WIRED | 7 emit-вызовов (Status/Log/Traffic/Error) |
| OkoVpnService.kt | vpn/VpnConnectionState | `transition()→canTransition()` | ✓ WIRED | canTransition-гейт присутствует |
| OkoVpnService.kt | TUN ParcelFileDescriptor | `FileInputStream(pfd.fileDescriptor)` | ✓ WIRED | read-loop подключён к TUN fd |
| MainActivity.kt | OkoVpnService (ACTION_CONNECT + EXTRA_*) | `startForegroundService(...)` | ✓ WIRED | Intent с action + 4 extras |
| VpnHostApiImpl.kt | bridge/VpnConsentGateway | `gateway.connect/disconnect` | ✓ WIRED | Оба вызова найдены |
| MainActivity.kt | android VpnService.prepare | `VpnService.prepare(this)` | ✓ WIRED | consent-флоу подключён |
| lib/main.dart | vpnRepository.watchTraffic() | StreamBuilder traffic-поток | ✓ WIRED | gsd-sdk: pattern found |

> Примечание: `gsd-sdk query verify.key-links` вернул "Source file not found" для Kotlin-ссылок из-за укороченных путей в PLAN (`vpn/OkoVpnService.kt`), которые SDK не резолвит в полный `android/app/src/main/kotlin/...`. Это ограничение резолва путей инструмента, а не разрыв связи — все 8 связей подтверждены прямым grep по исходникам.

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| lib/main.dart | `_trafficStream` (TrafficStats) | `vpnRepository.watchTraffic()` ← TrafficChanged из native TUN read-loop | Yes | ✓ FLOWING (rx: 200 B на device) |
| OkoVpnService (rx) | `rx` (AtomicLong) | `FileInputStream(tun).read()` в read-loop | Yes | ✓ FLOWING (реальные байты tun0) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Kotlin компилируется | `flutter build apk --debug` | `✓ Built app-debug.apk` (exit 0) | ✓ PASS |
| Dart-линт чист | `flutter analyze` | `No issues found!` (exit 0) | ✓ PASS |
| Dart-регресс | `flutter test` | `All tests passed!` — 46 tests | ✓ PASS |
| State-machine JUnit | `./gradlew :app:testDebugUnitTest` | 4 tests, 0 failures, 0 errors | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| AND-01 | 02-04 | prepare() на каждый старт; отказ → Error + лог | ✓ SATISFIED | Truth 1, 8; device consent OK/Cancel |
| AND-02 | 02-03 | Builder addAddress/addRoute/addDnsServer/establish; узкий маршрут | ✓ SATISFIED | Truth 2; route 10.111.222.0/24, нет 0.0.0.0 |
| AND-03 | 02-02, 02-04 | FGS + уведомление + systemExempted + POST_NOTIFICATIONS | ✓ SATISFIED | Truth 3; manifest + device id=1001 без краша |
| AND-04 | 02-03 | teardown (close fd, stop foreground); onRevoke → Disconnected | ✓ SATISFIED | Truth 5; teardown из stop/onRevoke, close fd до join |
| AND-05 | 02-03, 02-05 | read-loop считает байты, trafficChanged раз в секунду | ✓ SATISFIED | Truth 4, 9; rx из TUN, 1Гц ticker, harness |
| AND-06 | 02-01, 02-03 | все переходы логируются logMessage | ✓ SATISFIED | Truth 6; transition() + JUnit + device-логи |

Все 6 требований, замапленных на Phase 2 в REQUIREMENTS.md, заявлены в планах — orphaned-требований нет.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| — | — | Debt-маркеры (TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER) | ℹ️ None | grep по 10 файлам — 0 совпадений |
| — | — | Комментарии в Kotlin (запрещены конвенцией) | ℹ️ None | grep по всем hand-written Kotlin — 0 |
| — | — | Стабы (return null/[]/{}, not implemented) | ℹ️ None | Пустых реализаций нет |

### Informational Observations (не блокеры)

- **Error без кода в статусе.** При отказе consent `StatusChangedMessage(ERROR)` эмитится без кода, UI показывает «Error: unknown», хотя `ErrorMessage("consent_denied",…)` и `LogMessage` несут внятную причину. AND-01/SC1 удовлетворён (Error + внятный лог). Улучшение — задача Phase 3 UI (показывать сообщение, а не код). Зафиксировано в 02-06-SUMMARY.
- **tx всегда 0.** Write-путь в TUN не реализован (нет VPN-core) — честно. AND-05/SC4 требует роста rx из реального read-loop, что выполнено.
- **onDestroy vs teardown.** `onDestroy()` делает только `tunnel?.close()` (safety-net при системном kill), не зовёт полный `teardown()`. Голево-значимые пути SC5 (Disconnect, onRevoke) идут через `teardown()`; `teardown→stopSelf→onDestroy` даёт no-op close (tunnel уже null). Разрыва цели нет.
- **onRevoke live не триггерился.** Требует второго VPN-приложения, которого нет в окружении. Ветка покрыта кодом (тот же `teardown`, симметрична проверенному Disconnect) и доставляет событие через потокобезопасную шину + main-thread listener. Зафиксировано честно в 02-06-SUMMARY.

### Human Verification Required

Нет открытых пунктов. Device-чеклист (02-VALIDATION.md, 8 пунктов) прогнан вживую оркестратором на эмуляторе API 36 и задокументирован в 02-06-SUMMARY с доказательствами (logcat/dumpsys/screencap): consent OK→Connected, Cancel→Error, узкий маршрут tun0, FGS-уведомление, rx из TUN, teardown, 3 стабильных цикла, логирование переходов. Единственный не воспроизведённый вживую сценарий — onRevoke через второй VPN — покрыт кодом и зафиксирован.

### Gaps Summary

Гэпов нет. Цель фазы достигнута: реальный Android VpnService поднимается через consent-флоу `VpnService.prepare`, живёт в Foreground Service с systemExempted-уведомлением, считает трафик из реального TUN read-loop и шлёт живые статусы/логи/трафик во Flutter через сохранённый Pigeon-контракт. Echo-реализация Android из фазы 1 заменена. Все автогейты зелёные, код чист (без комментариев, стабов, debt-маркеров), потокобезопасность подтверждена кодом и 3 циклами на устройстве.

---

_Verified: 2026-07-13T20:53:38Z_
_Verifier: Claude (gsd-verifier)_
