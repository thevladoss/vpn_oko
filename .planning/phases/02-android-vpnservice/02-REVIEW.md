---
phase: 02-android-vpnservice
reviewed: 2026-07-13T20:54:13Z
depth: deep
files_reviewed: 11
files_reviewed_list:
  - android/app/src/main/kotlin/com/example/vpn_oko/MainActivity.kt
  - android/app/src/main/kotlin/com/example/vpn_oko/vpn/OkoVpnService.kt
  - android/app/src/main/kotlin/com/example/vpn_oko/vpn/VpnConnectionState.kt
  - android/app/src/main/kotlin/com/example/vpn_oko/vpn/VpnNotificationFactory.kt
  - android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnEventBus.kt
  - android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnHostApiImpl.kt
  - android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnConsentGateway.kt
  - android/app/src/main/AndroidManifest.xml
  - android/app/build.gradle.kts
  - android/app/src/test/kotlin/com/example/vpn_oko/vpn/VpnConnectionStateTest.kt
  - lib/main.dart
  - lib/app/di.dart
findings:
  blocker: 1
  high: 2
  medium: 1
  low: 7
  total: 11
status: issues_found
---

# Фаза 02: Отчёт code-review (Android VpnService)

**Дата:** 2026-07-13T20:54:13Z
**Глубина:** deep (cross-file: MainActivity → OkoVpnService → VpnEventBus → Pigeon)
**Файлов проверено:** 11 (+ Messages.g.kt, VpnEventListener прочитаны как контекст, не ревьюились)
**Статус:** issues_found

## Summary

Проверил замену echo-заглушки реальным `VpnService`: билдер туннеля, read-loop, 1Гц ticker, teardown, consent-флоу, state-machine и потокобезопасный `VpnEventBus`. Ядро корректно в happy-path: порядок teardown правильный (`running=false` → `close(fd)` → `join`), `startForeground` вызывается до любого `failStart`, canTransition-гейт не роняет lifecycle, консент регистрируется в конструкторе (до `onResume`), POST_NOTIFICATIONS не блокирует старт. Секретов, инъекций, небезопасной десериализации нет.

Главная проблема — управление ресурсами при повторном входе и нештатном уничтожении сервиса. Повторный `onStartCommand` во время активного соединения переустанавливает туннель без teardown и теряет ссылки на прошлый fd/поток/ticker (BL-01). `onDestroy` не вызывает teardown, поэтому при системном kill не-daemon ticker утекает (HI-02). Компаунд-запись `snapshot.copy(...)` под одним `@Volatile` подвержена гонке lost-update между ticker-потоком и main (HI-01) — а это документированный источник истины для `getStatus()`.

## Blocker

### BL-01: Повторный `onStartCommand` во время соединения течёт fd + поток + ticker

**Файл:** `android/app/src/main/kotlin/com/example/vpn_oko/vpn/OkoVpnService.kt:50-70`
**Issue:** `onStartCommand` не проверяет, что сервис уже соединён. `transition(Connecting)` (строка 50) при `state == Connected` отбивается гейтом `canTransition` (Connected → только Disconnecting) — метод логирует «illegal transition» и возвращает Unit, но **код игнорирует результат** и продолжает: `buildTunnel()` → `establish()` создаёт новый fd, `tunnel = descriptor` (строка 66) затирает старый `ParcelFileDescriptor` **без `close()` → утечка TUN fd**; `startReadLoop` перезаписывает `readThread`, `startTrafficTicker` перезаписывает `trafficTicker` — старый `ScheduledExecutorService` (не-daemon) остаётся жить и эмитить `TrafficChanged` вечно. Финальный `transition(Connected(now))` тоже отбивается гейтом, поэтому Flutter вообще не узнаёт о повторе. Сценарий реален: повторный тап «Connect» при активном VPN → `VpnService.prepare` вернёт `null` (уже подготовлено) → `startForegroundService(CONNECT)` → повторный `onStartCommand` на том же singleton-инстансе сервиса.
**Fix:** Гейтить весь connect-путь состоянием, а не только эмит статуса. Например, в начале connect-ветки:
```kotlin
if (state !is VpnConnectionState.Disconnected && state !is VpnConnectionState.Error) {
    VpnEventBus.emit(LogMessage("already active, ignoring connect", System.currentTimeMillis(), "warning"))
    return START_NOT_STICKY
}
```
или вызвать `teardown(...)` перед переустановкой. Плюс проверять успешность перехода: `transition` должен возвращать `Boolean`, и `onStartCommand` обязан прервать установку при `false`.

## High

### HI-01: Гонка lost-update на `VpnEventBus.snapshot` (компаунд-запись под `@Volatile`)

**Файл:** `android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnEventBus.kt:30-48`
**Issue:** `snapshot = snapshot.copy(...)` — это read-modify-write. `@Volatile` гарантирует видимость одиночной записи, но не атомарность связки «прочитать-скопировать-записать». `emit` вызывается конкурентно: ticker-поток шлёт `TrafficChanged` (обновляет `rxBytes/txBytes`), а main/binder-поток — `StatusChanged` (обновляет `status/connectedSince`). При чередовании оба потока читают один и тот же `snapshot`, оба пишут — одно обновление теряется (напр. `DISCONNECTING`-статус затирается ticker-ом, вернувшим устаревший `CONNECTED`). `snapshot` — документированный источник истины: `VpnHostApiImpl.getStatus()` (VpnHostApiImpl.kt:14) отдаёт именно его для replay статуса во Flutter, так что потерянное обновление → неверный статус после ресинка. `lastStatus` в порядке (одиночная volatile-запись), проблема только в компаунд-`copy`.
**Fix:** Сериализовать мутации snapshot. Либо синхронизировать критическую секцию:
```kotlin
@Synchronized
fun emit(event: VpnEventMessage) { ... }
```
либо перейти на `AtomicReference<VpnStatusSnapshotMessage>` с `updateAndGet { it.copy(...) }` (CAS вместо блокировки).

### HI-02: `onDestroy` не делает teardown → утечка ticker и потока при системном kill

**Файл:** `android/app/src/main/kotlin/com/example/vpn_oko/vpn/OkoVpnService.kt:158-162`
**Issue:** `onDestroy` только закрывает `tunnel`. Если сервис уничтожается **минуя** `teardown` (система убивает foreground-сервис, task removed, low-memory), то `running` остаётся `true`, а `trafficTicker` (создан `Executors.newSingleThreadScheduledExecutor()` — не-daemon) **не шатдаунится и продолжает эмитить `TrafficChanged` в `VpnEventBus` вечно**, удерживая поток и ссылки после смерти сервиса. Read-thread здесь daemon и оборвётся на `close(tunnel)` через IOException, но ticker — нет. `teardown` вызывается только из DISCONNECT-ветки `onStartCommand` и из `onRevoke`; штатного уничтожения он не покрывает.
**Fix:** Свести очистку в один идемпотентный путь:
```kotlin
override fun onDestroy() {
    teardown("service destroyed")
    super.onDestroy()
}
```
`teardown` уже идемпотентен (гард `state is Disconnected`), поэтому двойного прогона не будет. Отдельно рассмотреть `ticker` с daemon-фабрикой потоков как defense-in-depth.

## Medium

### ME-01: `state` защищён частично — `@Synchronized` только на teardown, а transition/onStartCommand без синхронизации

**Файл:** `android/app/src/main/kotlin/com/example/vpn_oko/vpn/OkoVpnService.kt:23, 121-134, 136-152`
**Issue:** Поле `state` — обычный `var` (не `@Volatile`). `teardown` помечен `@Synchronized` (сам автор ожидает вызов не с main — из `onRevoke`), но `transition()` и его вызовы из `onStartCommand` (main-поток) синхронизации не имеют. `@Synchronized` даёт взаимное исключение только между `@Synchronized`-методами, а таких больше нет — значит блокировка **не защищает `state`** от конкурентного доступа main-потока (transition в onStartCommand) и потока onRevoke (teardown→transition). Возможны потеря видимости записи и чтение устаревшего `state` в гейте `canTransition`. Confidence: MEDIUM (зависит от того, на каком потоке платформа вызывает `onRevoke`; исторически — binder-поток, что и объясняет `@Synchronized`).
**Fix:** Единая дисциплина блокировки: пометить `transition` (и connect-путь) `@Synchronized` на том же мониторе, что и `teardown`, либо загонять все мутации `state` в один поток (Handler сервиса). Как минимум — `@Volatile var state`, но одной volatile мало для связки check-then-act в `canTransition`.

## Low

### LO-01: `txBytes` захардкожен в `0L` — tx никогда не измеряется

**Файл:** `android/app/src/main/kotlin/com/example/vpn_oko/vpn/OkoVpnService.kt:96`
**Issue:** Ticker шлёт `TrafficChangedMessage(rx.get(), 0L)`. Read-loop считает только rx; tx не считается нигде, поэтому harness (`lib/main.dart:124`) всегда показывает `tx: 0 B`. Для прототипа-заглушки допустимо, но harness заявлен как «readout rx/tx» — tx мёртв.
**Fix:** Либо считать записанные в TUN байты вторым `AtomicLong`, либо честно задокументировать в SUMMARY, что tx=0 by design на этой фазе.

### LO-02: `EXTRA_USER_ID` кладётся, но не читается; `ACTION_CONNECT` не валидируется сервисом

**Файл:** `android/app/src/main/kotlin/com/example/vpn_oko/vpn/OkoVpnService.kt:33-40, 165-170`; `MainActivity.kt:88-91`
**Issue:** `MainActivity` кладёт `EXTRA_USER_ID` (строка 91) и `ACTION_CONNECT` (строка 88), но `onStartCommand` `EXTRA_USER_ID` не читает нигде, а connect-путь принимает **любой** non-null non-DISCONNECT интент (нет проверки `action == ACTION_CONNECT`). При always-on VPN система стартует сервис своим интентом → пустой host → `failStart` (graceful, не краш), но константа `ACTION_CONNECT` де-факто декоративна.
**Fix:** Либо явно гейтить `when (intent?.action) { ACTION_DISCONNECT -> ...; ACTION_CONNECT -> ...; else -> stopSelf() }`, либо убрать неиспользуемый `EXTRA_USER_ID` до момента реального использования.

### LO-03: `FileInputStream` в read-loop не закрывается явно

**Файл:** `android/app/src/main/kotlin/com/example/vpn_oko/vpn/OkoVpnService.kt:77-90`
**Issue:** `FileInputStream(pfd.fileDescriptor)` не оборачивается в `use {}` и не закрывается. Функционально fd освобождается через `tunnel.close()` в teardown (read() ловит IOException, цикл рвётся), но объект потока полагается на этот побочный эффект вместо явного контракта.
**Fix:** `FileInputStream(pfd.fileDescriptor).use { input -> ... }` внутри тела потока — цикл всё равно прервётся по IOException, а закрытие станет явным.

### LO-04: `startService(DISCONNECT)` на уже-отключённом сервисе оставляет висящий инстанс

**Файл:** `android/app/src/main/kotlin/com/example/vpn_oko/vpn/OkoVpnService.kt:33-36, 137-138`
**Issue:** DISCONNECT-ветка вызывает `teardown`, который при `state is Disconnected` возвращается рано — **без `stopSelf()`**. Если `disconnect()` пришёл на свежесозданный (или уже отключённый) сервис, инстанс создаётся, ничего не делает и не останавливается. Не foreground, поэтому система рано или поздно уберёт, но это лишний живой started-service.
**Fix:** В DISCONNECT-ветке `onStartCommand` звать `stopSelf()` после `teardown`, либо в `teardown` при раннем возврате всё равно `stopSelf()`.

### LO-05: `addListener` реплеит `lastStatus` вне синхронизации с `emit` → возможен out-of-order статус новому подписчику

**Файл:** `android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnEventBus.kt:21-24`
**Issue:** `listeners += listener; listener(lastStatus)` — между добавлением и реплеем конкурентный `emit` на ticker-потоке может доставить новому слушателю свежий `StatusChanged`, а следом придёт реплей уже устаревшего `lastStatus`. Один дубликат/устаревший статус свежему подписчику; следующий реальный эмит исправит. Узкое окно, один подписчик (`VpnEventListener`).
**Fix:** Считать `lastStatus` и добавить слушателя под тем же монитором, что и `emit` (см. HI-01), чтобы реплей был согласован с потоком событий.

### LO-06: `VpnNotificationFactory.building()` — вводящее в заблуждение имя

**Файл:** `android/app/src/main/kotlin/com/example/vpn_oko/vpn/VpnNotificationFactory.kt:15`
**Issue:** Функция, возвращающая готовый `Notification`, названа `building` (герундий, будто процесс). Ожидается `build`/`buildNotification`. При запрете комментариев имена — единственный носитель смысла (CLAUDE.md conventions), поэтому точность имён важнее обычного.
**Fix:** Переименовать в `build(text)` или `buildNotification(text)`.

### LO-07: `AppDependencies.dispose()` не вызывается; тест не покрывает часть невалидных переходов

**Файл:** `lib/main.dart:56-59`; `android/app/src/test/kotlin/.../VpnConnectionStateTest.kt:44-48`
**Issue:** (a) `DebugHarness.dispose` отменяет только `_logSubscription`; `widget.dependencies.dispose()` не зовётся нигде — метод `dispose()` в `AppDependencies` мёртв. Для harness с временем жизни = времени жизни приложения приемлемо, но код повисает неиспользованным. (b) `rejectsInvalidTransitions` не проверяет `Connected → Disconnected`, `Disconnecting → Connecting`, `Disconnected → Error?` (последнее валидно) — пробел покрытия state-machine, не баг.
**Fix:** (a) Либо звать `dependencies.dispose()` в `dispose()`, либо убрать неиспользуемый метод. (b) Дополнить негативные кейсы в тесте для полноты матрицы переходов.

---

## Проверено и признано корректным (для контекста ревьюера)

- Порядок teardown: `running=false` → `tunnel.close()` → `readThread.join(500)` — close разблокирует блокирующий `read()`, join не виснет. OK.
- `startForeground` вызывается до любого `failStart` (строки 43-48 раньше валидации host/port). Обязательство foreground при `startForegroundService(CONNECT)` всегда выполняется. OK.
- Консент: `registerForActivityResult` в инициализаторах полей (конструктор, до `onCreate`/`onResume`); `prepare(this)` перед каждым стартом; `RESULT_OK` иначе → `ErrorMessage("consent_denied")` + `StatusChanged(ERROR)`. OK.
- POST_NOTIFICATIONS запрашивается fire-and-forget, не блокирует `prepare`/старт. OK.
- `canTransition`: Error достижим из любого состояния; невалидный переход логируется и не роняет lifecycle. OK (кроме того, что результат игнорируется — см. BL-01).
- `establish()==null` и невалидный host/port → `failStart` без краша. OK.
- Безопасность: секретов нет, инъекций/eval/command-exec нет, сервис `exported=false` + `BIND_VPN_SERVICE`, манифест `systemExempted` согласован с `ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED`. OK.
- `rx` как `AtomicLong`, `running` как `AtomicBoolean` — эти счётчики потокобезопасны. OK.

---

_Reviewed: 2026-07-13T20:54:13Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
