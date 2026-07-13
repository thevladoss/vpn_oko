# Phase 2: Android VpnService — Research

**Researched:** 2026-07-13
**Domain:** Android `VpnService`, Foreground Service (Android 14/15/16), Pigeon-мост Flutter↔Kotlin
**Confidence:** HIGH (ключевые API сверены с официальными доками Android и локальным Flutter SDK в этой сессии; узкие места помечены MEDIUM/ASSUMED)

## Summary

Фаза заменяет echo-реализацию Android из фазы 1 на реальный `VpnService`. Контракт Pigeon и транспорт событий не меняются: `VpnEventBus` + `VpnEventListener` (доставка sink строго с main thread) переиспользуются как есть, echo-логика внутри `VpnHostApiImpl` вырезается и заменяется запуском реального сервиса через consent-флоу. Реальный туннель поднимается `VpnService.Builder.establish()` на узкую тестовую подсеть (интернет устройства живёт в Connected), Foreground Service держит уведомление с типом `systemExempted`, поток чтения TUN считает живые байты и раз в секунду шлёт `trafficChanged`, `onRevoke`/`stopVpn`/`onDestroy` сходятся в один teardown.

Три архитектурных шва определяют качество фазы. Первый: consent-флоу требует `registerForActivityResult`, а он недоступен на текущем `FlutterActivity` — базовый класс `MainActivity` надо сменить на `FlutterFragmentActivity`. Второй: `VpnEventBus` из фазы 1 не потокобезопасен, а в фазе 2 `emit()` начинают дёргать рабочие потоки (read-loop, `onRevoke` не на main thread) — шину надо укрепить (`@Volatile` + потокобезопасная коллекция слушателей), иначе гонки и `ConcurrentModificationException`. Третий: `startForeground` обязан вызываться первой строкой `onStartCommand` с типом `systemExempted`, иначе краш на Android 14+.

**Primary recommendation:** `MainActivity : FlutterFragmentActivity` владеет consent-флоу (два `ActivityResultLauncher`: POST_NOTIFICATIONS и VPN-consent) и запускает/останавливает `OkoVpnService` интентами с action. `OkoVpnService : VpnService` внутри держит state machine, `Builder.establish()` на узкую подсеть `10.111.222.0/24`, `ServiceCompat.startForeground(... FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED)` первой строкой, read-loop с одним переиспользуемым буфером и 1 Гц троттлингом трафика, единый `teardown()`. События идут через укреплённый `VpnEventBus` → `VpnEventListener` (main thread) без изменения Pigeon-контракта.

---

## User Constraints

> CONTEXT.md для фазы 2 не создавался (фаза планируется без discuss-стадии). Ограничения ниже — зафиксированные решения из `.planning/STATE.md`, `.planning/PROJECT.md` и `CLAUDE.md`/`CONVENTIONS.md`. Планировщик обязан их соблюдать наравне с locked-решениями.

### Locked Decisions (из STATE.md / PROJECT.md)

- **Маршрут TUN — узкая тестовая подсеть**, не `0.0.0.0/0`. Интернет устройства должен работать в статусе Connected (VPN-core нет). Счётчики трафика демонстрируются пингом в подсеть туннеля. [CITED: STATE.md Decisions, «Init: Маршрут TUN — узкая тестовая подсеть»]
- **`applicationId` = `com.example.vpn_oko`**; Kotlin-пакет `com.example.vpn_oko`, bridge-код в `com.example.vpn_oko.bridge`. [VERIFIED: android/app/build.gradle.kts, AndroidManifest, существующие .kt]
- **Форвардинг пакетов вне скоупа.** Read-loop честно читает и дропает пакеты, считает байты. Никакого tun2socks/мини-прокси. [CITED: REQUIREMENTS.md Out of Scope]
- **Автопереподключение / always-on вне скоупа.** Reconnect только вручную; это влияет на выбор `START_NOT_STICKY` и на то, что сервис не стартует из фона. [CITED: REQUIREMENTS.md Out of Scope]
- **Kill switch, split tunneling, per-app VPN вне скоупа.** [CITED: REQUIREMENTS.md Out of Scope]
- **VPN-core (Xray/sing-box) вне скоупа** — только точки интеграции в README (фаза 6). `protect()` сокета в прототипе не нужен (нет upstream-сокета). [CITED: REQUIREMENTS.md Out of Scope]

### Claude's Discretion

- Конкретный адрес/маска TUN-интерфейса и тестовой подсети (в рамках приватного диапазона RFC 1918).
- Наличие/отсутствие `addDnsServer` и его значение (AND-02 требует вызова; поведение с узким маршрутом проверить на эмуляторе).
- Способ передачи конфига Activity→Service (Intent extras vs иное).
- Структура state machine (sealed vs enum + таблица переходов).
- Механизм 1 Гц троттлинга трафика (Handler/ScheduledExecutor/coroutine).

### Deferred Ideas (OUT OF SCOPE)

- Реальный VPN-core, форвардинг трафика, скорость B/s поверх счётчиков (v2: EXT-01/02/03).
- Импорт по QR, список серверов (v2: EXT-04).
- Персист конфига, аккаунты, локализация, onboarding.

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **AND-01** | `VpnService.prepare()` перед каждым стартом; отказ → Error + внятный лог | Consent-флоу через `FlutterFragmentActivity` + `registerForActivityResult` (Pattern 1); `prepare()` вызывается на каждый Connect (не кэшируется); `RESULT_CANCELED` → `ErrorMessage("consent_denied")` + `LogMessage` + остаёмся Disconnected |
| **AND-02** | `Builder`: addAddress, addRoute (узкий маршрут), addDnsServer, establish; Connected не убивает интернет | Pattern 3 (Builder на узкую подсеть `10.111.222.0/24`); `establish()==null` → teardown + Error; `protect()` не нужен без core |
| **AND-03** | Foreground Service с уведомлением, `foregroundServiceType=systemExempted`, POST_NOTIFICATIONS на 13+ | Pattern 2 (`ServiceCompat.startForeground` первой строкой + `FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED`); манифест-декларации; runtime-запрос POST_NOTIFICATIONS через launcher |
| **AND-04** | Корректная остановка (закрытие TUN fd, стоп foreground); `onRevoke` доводит Disconnected до Flutter | Pattern 4 (единый `teardown()` из stopVpn/onRevoke/onDestroy); `START_NOT_STICKY`; `pfd.close()` до `join`; onRevoke не на main thread → через `VpnEventBus` |
| **AND-05** | Read-loop TUN считает реальные байты, шлёт `trafficChanged` раз в секунду | Pattern 5 (поток + переиспользуемый буфер + `AtomicLong` + 1 Гц ticker); демонстрация пингом в подсеть маршрута |
| **AND-06** | Все переходы состояний и ключевые действия логируются `logMessage` | State machine эмитит `StatusChanged` + `LogMessage` на каждом переходе; `VpnEventBus` (укреплённый) → `VpnEventListener` (main thread) |

---

## Project Constraints (from CLAUDE.md / CONVENTIONS.md)

Планировщик обязан проверить план на соответствие:

- **Комментарии в коде запрещены** (Dart, Kotlin, Swift). Имена и структура несут смысл. Не добавлять KDoc/inline-комментарии в `OkoVpnService`, `MainActivity` и др. [CITED: CONVENTIONS.md]
- **SOLID + feature-first CA.** Kotlin: `bridge/` знает про Pigeon и Flutter engine, `vpn/` знает только Android SDK + `VpnEventBus`. Сервис тестируется/запускается без Flutter. Зависимости через абстракции (например, интерфейс `VpnConsentGateway`, реализуемый `MainActivity`). [CITED: CONVENTIONS.md, ARCHITECTURE.md «Kotlin: bridge/ отделён от vpn/»]
- **Native — источник истины по статусу VPN.** Статус меняется только событиями из native; Flutter при старте/resume вызывает `getStatus()`. [CITED: CONVENTIONS.md]
- **События native→Flutter только с main thread платформы** (`Handler(Looper.getMainLooper())` / `Dispatchers.Main`). [CITED: CONVENTIONS.md]
- **Ошибки:** `PlatformException`/сбои → доменные ошибки; в лог не выводить сырые креды VLESS/UUID. [CITED: CONVENTIONS.md, PITFALLS.md Security]
- **Именование:** Kotlin по конвенциям платформы; файлы/идентификаторы на английском; доки и commit messages на русском. [CITED: CONVENTIONS.md]
- **Git:** атомарные коммиты по задачам, conventional commits с русским описанием. [CITED: CONVENTIONS.md]
- **Test-as-you-go:** код → тесты → прогон в том же заходе. Оговорка фазы: большинство механик `VpnService` проверяется только на устройстве/эмуляторе (см. Validation Architecture). [CITED: CONVENTIONS.md, global CLAUDE.md]

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| VPN consent (`prepare` + системный диалог) | Activity (`MainActivity`) | — | `prepare()` возвращает `Intent` для системной Activity; результат ловит только компонент с `ActivityResultCaller` (`FlutterFragmentActivity`) |
| Запуск/остановка сервиса | Activity (`MainActivity`) | — | `startForegroundService`/`stopService` требуют `Context` Activity; конфиг стартует отсюда после consent |
| Жизненный цикл туннеля (establish, read-loop, teardown, onRevoke) | Service (`OkoVpnService`) | — | Туннель обязан жить в `VpnService` (переживает Activity); read-loop и fd владеет сервис |
| State machine + логирование переходов | Service (`OkoVpnService`) | `VpnEventBus` | Сервис — источник истины по статусу; каждый переход эмитит status + log |
| Транспорт событий service→Dart | `VpnEventBus` (bridge) | `VpnEventListener` | Внутрипроцессная шина + доставка sink с main thread; переиспользуется из фазы 1 |
| Pigeon HostApi (startVpn/stopVpn/getStatus) | `VpnHostApiImpl` (bridge) | `MainActivity` | Тонкий адаптер: делегирует consent/старт в Activity, `getStatus` отдаёт snapshot шины |
| Foreground-уведомление | Service (`VpnNotificationFactory`) | — | `startForeground` живёт внутри сервиса; канал создаётся до старта |
| POST_NOTIFICATIONS runtime | Activity (`MainActivity`) | — | Runtime-разрешение запрашивается из Activity через launcher |

---

## Standard Stack

Фаза 2 **не добавляет внешних пакетов**. Всё — Android Platform SDK и `androidx.core` (уже транзитивно приходит с Flutter embedding). Ниже — API-поверхность, а не зависимости.

### Core (Android Platform)
| API | Since | Purpose | Note |
|-----|-------|---------|------|
| `android.net.VpnService` | API 14 | Базовый класс сервиса, `prepare()`, `Builder`, `establish()`, `onRevoke()`, `protect()` | [CITED: developer.android.com/reference/android/net/VpnService] |
| `VpnService.Builder` | API 14 | `addAddress`, `addRoute`, `addDnsServer`, `setMtu`, `setSession`, `establish` | `establish()` → `ParcelFileDescriptor?`, null без consent/при revoke [VERIFIED: developer.android.com/develop/connectivity/vpn] |
| `ServiceCompat.startForeground` | androidx.core | FGS-старт с типом, безопасно по версиям API | Разрешает разброс API 26–33 vs 34+ одним вызовом [ASSUMED: поведение systemExempted на 26–33 проверить] |
| `ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED` | API 34 | Тип FGS для VPN-приложений | Значение-константа, компилируется при compileSdk 36 [VERIFIED: fg-service-types doc] |
| `NotificationChannel` / `NotificationManager` | API 26 | Канал уведомления FGS (обязателен с API 26) | minSdk 26 → без ветвления [CITED: STACK.md] |
| `ActivityResultContracts.StartActivityForResult` | androidx.activity | Ловит результат VPN-consent | Требует `FlutterFragmentActivity` [VERIFIED: flutter/flutter#130044] |
| `ActivityResultContracts.RequestPermission` | androidx.activity | Runtime POST_NOTIFICATIONS | API 33+ |
| `java.util.concurrent.atomic.AtomicLong` | JDK | Счётчики rx/tx между read-loop и ticker | — |

### Что переиспользуется из фазы 1 (Kotlin echo-мост)
| Файл | Действие в фазе 2 |
|------|-------------------|
| `bridge/VpnEventBus.kt` | **Переиспользуется + укрепляется потокобезопасностью** (см. Pitfall 5): `emit()` теперь зовут рабочие потоки |
| `bridge/VpnEventListener.kt` | **Переиспользуется как есть** — доставка sink через `Handler(Looper.getMainLooper())` уже валидирована |
| `bridge/Messages.g.kt` | Без изменений (Pigeon-контракт стабилен) |
| `bridge/VpnHostApiImpl.kt` | **Echo-логика заменяется**: `startVpn`→consent+сервис, `stopVpn`→ACTION_DISCONNECT, `getStatus`→`VpnEventBus.snapshot` (без изменений) |
| `MainActivity.kt` | **Меняется базовый класс** `FlutterActivity`→`FlutterFragmentActivity` + consent-флоу + запуск сервиса |

### Что добавляется
| Файл | Purpose |
|------|---------|
| `vpn/OkoVpnService.kt` | `VpnService`: onStartCommand (ACTION_CONNECT/DISCONNECT), Builder, establish, read-loop, teardown, onRevoke, onDestroy |
| `vpn/VpnConnectionState.kt` | sealed-состояния + таблица допустимых переходов |
| `vpn/VpnNotificationFactory.kt` | `NotificationChannel` + `Notification` для startForeground |
| `bridge/VpnConsentGateway.kt` (interface) | Абстракция consent/старта, реализуется `MainActivity`, инъектируется в `VpnHostApiImpl` (SOLID) |
| `AndroidManifest.xml` | permissions + декларация сервиса |
| `android/app/build.gradle.kts` | `minSdk = 26` (override дефолта Flutter 24) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `FlutterFragmentActivity` + `registerForActivityResult` | `FlutterActivity` + `startActivityForResult`/`onActivityResult` (deprecated) | Legacy API работает на текущем базовом классе, но deprecated и хуже читается ревьюером; смена класса — одна строка [VERIFIED: flutter/flutter#130044] |
| `START_NOT_STICKY` | `START_STICKY` | STICKY нужен для always-on (вне скоупа) и роняет NPE при пересоздании без конфига; NOT_STICKY совпадает с «reconnect только вручную» [CITED: PITFALLS.md tech-debt] |
| `foregroundServiceType=systemExempted` | `specialUse` | specialUse требует `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` + ревью Play Console; VPN явно в eligibility systemExempted [VERIFIED: fg-service-types doc] |
| Узкий маршрут `10.111.222.0/24` | `0.0.0.0/0` + read-and-drop | Полный маршрут без core убивает интернет в Connected (плохо на демо); узкий маршрут держит интернет и всё равно даёт живые счётчики пингом [CITED: STATE.md decision, PITFALLS.md P2] |

### Версии / проверка окружения
```bash
flutter --version   # 3.44.5 stable (VERIFIED: локально, 2026-07-06)
# Дефолты Flutter 3.44.5 Android (VERIFIED из FlutterExtension.kt в SDK):
#   compileSdkVersion = 36, targetSdkVersion = 36, minSdkVersion = 24
# → фаза 2 меняет ТОЛЬКО minSdk 24 → 26; compileSdk/targetSdk уже 36 (можно закрепить явно)
```

---

## Package Legitimacy Audit

Фаза не устанавливает внешних пакетов (ни npm/pub, ни новых Gradle-зависимостей): используются Android Platform SDK и `androidx.core`, приходящий транзитивно с Flutter embedding. slopcheck неприменим.

| Package | Registry | Disposition |
|---------|----------|-------------|
| *(none — только Platform SDK + транзитивный androidx.core)* | — | N/A |

**Packages removed / flagged:** none.

---

## Architecture Patterns

### System Architecture Diagram

Поток команды (Connect) и поток событий (native→Flutter):

```
[Flutter: tap Connect]
      │ ConnectVpn usecase → VpnBridge.startVpn(VpnConfigMessage)
      ▼ Pigeon HostApi (binary messenger, main thread)
VpnHostApiImpl.startVpn(config, callback)
      │ delegate → VpnConsentGateway.connect(config)   callback(success) сразу (fire-and-forget)
      ▼
MainActivity (FlutterFragmentActivity)
      │ (API33+) POST_NOTIFICATIONS launcher ─── denied → лог, VPN всё равно стартует
      │ intent = VpnService.prepare(this)
      ├── intent == null ──────────────► startForegroundService(ACTION_CONNECT + config extras)
      └── intent != null ─► vpnConsentLauncher.launch(intent)
                                 │
                     ┌───────────┴───────────┐
              RESULT_CANCELED            RESULT_OK
                     │                        │
        VpnEventBus.emit(                 startForegroundService(ACTION_CONNECT + config)
          Error("consent_denied")             │
          + LogMessage                        ▼
          + StatusChanged(DISCONNECTED))  OkoVpnService.onStartCommand
                                              │ 1) ServiceCompat.startForeground(SYSTEM_EXEMPTED)  ← первой строкой
                                              │ 2) state → CONNECTING (+log)
                                              │ 3) Builder(addAddress, addRoute/24, addDnsServer, setMtu).establish()
                                              │      establish()==null → teardown + Error
                                              │ 4) start read-loop thread + 1Hz traffic ticker
                                              │ 5) state → CONNECTED(connectedSinceEpochMs) (+log)
                                              ▼
                                    ┌──────────────────────────────┐
   [device: ping 10.111.222.1] ───►│ TUN ParcelFileDescriptor      │
                                    │ FileInputStream.read(buf)     │──► rx AtomicLong += n, drop packet
                                    └──────────────────────────────┘
                                              │
   OkoVpnService (любой поток / onRevoke off-main)
      │ VpnEventBus.emit(StatusChanged / LogMessage / TrafficChanged / Error)   ← ШИНА ПОТОКОБЕЗОПАСНА
      ▼
VpnEventListener.onListen  →  mainHandler.post { sink.success(event) }   ← ТОЛЬКО main thread
      ▼ Pigeon EventChannel
vpnEvents(): Stream<VpnEventMessage>  →  VpnBridge демультиплексор  →  repositories → Bloc → UI
```

### Recommended Project Structure (Android delta)
```
android/app/src/main/kotlin/com/example/vpn_oko/
├── MainActivity.kt                 # FlutterFragmentActivity: launchers, consent, старт/стоп сервиса
├── bridge/
│   ├── Messages.g.kt               # (без изменений)
│   ├── VpnEventBus.kt              # (укрепить потокобезопасность)
│   ├── VpnEventListener.kt         # (без изменений)
│   ├── VpnConsentGateway.kt        # NEW: interface { connect(config); disconnect() }
│   └── VpnHostApiImpl.kt           # echo → делегирование в VpnConsentGateway + snapshot
└── vpn/
    ├── OkoVpnService.kt            # NEW: VpnService lifecycle
    ├── VpnConnectionState.kt       # NEW: sealed states + переходы
    └── VpnNotificationFactory.kt   # NEW: channel + notification
```

### Pattern 1: Consent-флоу в `FlutterFragmentActivity` (AND-01)

**What:** Смена базового класса Activity + два `ActivityResultLauncher`, зарегистрированных как поля (регистрация до `STARTED` — идиоматичный паттерн ComponentActivity). `prepare()` вызывается на КАЖДЫЙ Connect. Callback Pigeon завершается сразу; прогресс идёт событиями.
**When to use:** Всегда для VPN-consent из Flutter-хоста.
**Why prepare() каждый раз:** «a person might have set a different app as the VPN service since your app last called the method» — если запускался другой VPN, prepared-статус сброшен. [CITED: developer.android.com/develop/connectivity/vpn]

```kotlin
// Source: developer.android.com/develop/connectivity/vpn + developer.android.com/training/basics/intents/result
class MainActivity : FlutterFragmentActivity(), VpnConsentGateway {

    private var pendingConfig: VpnConfigMessage? = null

    private val vpnConsent =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val config = pendingConfig
            pendingConfig = null
            if (result.resultCode == RESULT_OK && config != null) {
                startVpnService(config)
            } else {
                VpnEventBus.emit(LogMessage("VPN permission denied", System.currentTimeMillis(), "error"))
                VpnEventBus.emit(ErrorMessage("consent_denied", "VPN permission denied by user"))
                VpnEventBus.emit(StatusChangedMessage(VpnStatusMessage.DISCONNECTED))
            }
        }

    private val notifPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { /* лог при отказе, старт не блокируется */ }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        VpnHostApi.setUp(messenger, VpnHostApiImpl(this))          // this = VpnConsentGateway
        VpnEventsStreamHandler.register(messenger, VpnEventListener())
    }

    override fun connect(config: VpnConfigMessage) {
        ensureNotificationPermission()
        val consent = VpnService.prepare(this)
        if (consent == null) startVpnService(config)
        else { pendingConfig = config; vpnConsent.launch(consent) }
    }

    override fun disconnect() {
        startService(Intent(this, OkoVpnService::class.java).setAction(OkoVpnService.ACTION_DISCONNECT))
    }

    private fun startVpnService(config: VpnConfigMessage) {
        val intent = Intent(this, OkoVpnService::class.java)
            .setAction(OkoVpnService.ACTION_CONNECT)
            .putExtra(OkoVpnService.EXTRA_HOST, config.host)
            .putExtra(OkoVpnService.EXTRA_PORT, config.port)
            .putExtra(OkoVpnService.EXTRA_USER_ID, config.userId)
            .putExtra(OkoVpnService.EXTRA_SERVER_NAME, config.serverName)
        startForegroundService(intent)
    }
}
```

`VpnHostApiImpl` становится тонким (echo-цепочка удалена):
```kotlin
class VpnHostApiImpl(private val gateway: VpnConsentGateway) : VpnHostApi {
    override fun startVpn(config: VpnConfigMessage, callback: (Result<Unit>) -> Unit) {
        gateway.connect(config)
        callback(Result.success(Unit))
    }
    override fun stopVpn(callback: (Result<Unit>) -> Unit) {
        gateway.disconnect()
        callback(Result.success(Unit))
    }
    override fun getStatus(): VpnStatusSnapshotMessage = VpnEventBus.snapshot
}
```

### Pattern 2: Foreground Service первой строкой + systemExempted (AND-03)

**What:** `startForeground` вызывается ПЕРВОЙ строкой `onStartCommand` (лимит ~5 сек до `ForegroundServiceDidNotStartInTimeException`), с типом `systemExempted`. Канал уведомления создаётся до старта.
**Why systemExempted:** официальный список eligibility явно включает «VPN apps (configured using Settings > Network & Internet > VPN)»; для не-VPN приложений тот же тип бросает `ForegroundServiceTypeNotAllowedException`. systemExempted НЕ в списке типов, ограниченных на Android 15+ (в отличие от dataSync/mediaPlayback). [VERIFIED: fg-service-types doc, эта сессия]

```kotlin
// Source: developer.android.com/develop/background-work/services/fg-service-types
override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    if (intent?.action == ACTION_DISCONNECT) { teardown("stopped by user"); return START_NOT_STICKY }
    if (intent == null) { stopSelf(); return START_NOT_STICKY }   // защита от рестарта без конфига

    ServiceCompat.startForeground(
        this, NOTIFICATION_ID,
        notificationFactory.building("Connecting…"),
        ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED,
    )
    transition(VpnConnectionState.Connecting)
    connect(intent)                                   // establish + read-loop
    return START_NOT_STICKY
}
```

Манифест:
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<service
    android:name=".vpn.OkoVpnService"
    android:permission="android.permission.BIND_VPN_SERVICE"
    android:foregroundServiceType="systemExempted"
    android:exported="false">
    <intent-filter>
        <action android:name="android.net.VpnService" />
    </intent-filter>
</service>
```

### Pattern 3: Builder на узкую подсеть, интернет жив (AND-02)

**What:** `Builder` конфигурирует туннель на узкую тестовую подсеть. Пакеты к этой подсети уходят в TUN (их читает read-loop), весь остальной трафик идёт мимо VPN — интернет работает.
**Trade-offs:** значок ключа в статус-баре есть, туннель реально поднят, но «полный перехват» не демонстрируется (это осознанное решение, фиксируется в README).

```kotlin
// Source: developer.android.com/develop/connectivity/vpn
private fun buildTunnel(): ParcelFileDescriptor? =
    Builder()
        .setSession("Oko VPN")
        .addAddress("10.0.0.2", 32)          // адрес самого TUN-интерфейса
        .addRoute("10.111.222.0", 24)        // ТОЛЬКО эта подсеть идёт в туннель
        .addDnsServer("1.1.1.1")             // вне маршрута → резолв по реальной сети (проверить на эмуляторе)
        .setMtu(1500)
        .establish()                          // null → нет consent / revoked
```

`establish()` возвращает `null`, если приложение не prepared или разрешение отозвано. [VERIFIED: «The establish() method returns null if your app isn't prepared or somebody revokes the permission», developer.android.com/develop/connectivity/vpn]. Обработка: `null` → `teardown` + `ErrorMessage("establish_failed", …)`.

**Демонстрация счётчиков:** `adb shell ping 10.111.222.1` (или кнопка в приложении). ICMP-пакеты попадают в TUN → read-loop считает байты → `trafficChanged` растёт. Ответа нет (дропаем), пинг таймаутится — байты живые.

**`protect()` не вызывается:** в прототипе нет upstream-сокета к шлюзу. `protect()` нужен только реальному core (чтобы сокет к шлюзу не зациклился через VPN) — это точка интеграции для README. [CITED: developer.android.com/develop/connectivity/vpn]

### Pattern 4: Единый teardown из stopVpn / onRevoke / onDestroy (AND-04)

**What:** Один метод `teardown()` закрывает fd, гасит поток, снимает foreground, эмитит Disconnected + log, зовёт `stopSelf()`. Вызывается из трёх точек. `onRevoke` приходит НЕ на main thread — события идут через `VpnEventBus` (шина + main-thread форвардинг закрывают threading).
**Why:** без единой точки — утечка fd, зависшее уведомление, ложный Connected после revoke. [CITED: PITFALLS.md P7/P8]

```kotlin
// onRevoke: "this call might not happen on the main thread" — developer.android.com/reference/android/net/VpnService
override fun onRevoke() { teardown("revoked by system") }
override fun onDestroy() { tunnel?.close(); tunnel = null; super.onDestroy() }

@Synchronized
private fun teardown(reason: String) {
    if (state is VpnConnectionState.Disconnected) return
    transition(VpnConnectionState.Disconnecting)
    running.set(false)
    tunnel?.close(); tunnel = null           // close ДО join — разблокирует read()
    readThread?.join(500); readThread = null
    trafficTicker?.cancel()
    VpnEventBus.emit(LogMessage(reason, System.currentTimeMillis(), "info"))
    ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
    transition(VpnConnectionState.Disconnected)
    stopSelf()
}
```

### Pattern 5: Read-loop с переиспользуемым буфером + 1 Гц троттлинг (AND-05)

**What:** Выделенный поток читает `FileInputStream(pfd.fileDescriptor)` в один переиспользуемый буфер, копит байты в `AtomicLong`, дропает пакеты. Отдельный 1 Гц ticker эмитит `TrafficChangedMessage`. Остановка: `pfd.close()` разблокирует `read()` (interrupt блокирующий I/O не прерывает). [CITED: PITFALLS.md P8, Performance Traps]

```kotlin
private val rx = AtomicLong(0)
private val running = AtomicBoolean(false)

private fun startReadLoop(pfd: ParcelFileDescriptor) {
    running.set(true)
    readThread = Thread {
        val input = FileInputStream(pfd.fileDescriptor)
        val buffer = ByteArray(32767)                 // один буфер на поток
        try {
            while (running.get()) {
                val n = input.read(buffer)
                if (n <= 0) break
                rx.addAndGet(n.toLong())              // пакет дропается (форвардинга нет)
            }
        } catch (_: IOException) { /* close() при teardown — ожидаемо */ }
    }.also { it.isDaemon = true; it.start() }
}

// 1 Гц ticker (например ScheduledExecutorService, любой поток → шина потокобезопасна)
private fun tickTraffic() {
    VpnEventBus.emit(TrafficChangedMessage(rxBytes = rx.get(), txBytes = 0L))
}
```

Счётчик: байты, прочитанные из TUN, = исходящий трафик устройства в туннель. Кладём в `rxBytes`; `txBytes = 0` (обратной записи нет). В README назвать честно. [Discretion: маппинг rx/tx]

### Anti-Patterns to Avoid
- **`android:process=":vpn"` у сервиса** — ломает Pigeon-мост (шина в другом процессе невидима). Один процесс. [CITED: PITFALLS.md P9]
- **`startForeground` после establish** — краш `DidNotStartInTime`. Первой строкой. [CITED: PITFALLS.md P10]
- **`eventSink.success()` из рабочего потока напрямую** — краш `@UiThread`. Только через `VpnEventBus`→`VpnEventListener`. [CITED: PITFALLS.md P3]
- **`prepare()` один раз / кэширование consent** — `establish()` вернёт null. Каждый Connect. [CITED: PITFALLS.md P1]
- **`thread.interrupt()` для остановки read-loop** — блокирующий read не прерывается. `pfd.close()` первым. [CITED: PITFALLS.md P8]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Версионная развилка `startForeground` (26 vs 29 vs 34) | Свой `if Build.VERSION.SDK_INT` каскад | `androidx.core.app.ServiceCompat.startForeground(...)` | androidx инкапсулирует различия overload'ов и требований типа |
| Ловля результата системной Activity | `startActivityForResult`/`onActivityResult` (deprecated) вручную | `registerForActivityResult` на `FlutterFragmentActivity` | Современный API, без магических requestCode, testable |
| Доставка событий на main thread | Свой thread-hop на каждый вызов | Существующий `VpnEventListener` (`Handler(mainLooper)`) | Уже написан и валидирован в фазе 1 |
| Кэш последнего статуса + replay новому подписчику | Свой буфер | Существующий `VpnEventBus` (lastStatus/snapshot/replay) | Закрывает гонку «событие раньше подписки» (BRG-04) |
| Уведомление FGS | Ручной `Notification.Builder` без канала | `VpnNotificationFactory` с `NotificationChannel` (API 26) | Без канала уведомление не покажется на 26+ |

**Key insight:** почти вся threading/lifecycle-обвязка событий уже написана в фазе 1. Соблазн переписать шину под сервис — ошибка; правильный минимум это (1) укрепить `VpnEventBus` потокобезопасностью и (2) заставить сервис эмитить в ту же шину.

---

## Runtime State Inventory

> Фаза заменяет echo-реализацию на реальный сервис. Это не rename и не миграция данных — но «что переносится из фазы 1» критично для планирования.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | Нет. VPN-конфиг не персистится (in-memory, decision). БД/датастора нет. | none |
| Live service config | Нет внешних сервисов с состоянием (n8n/Datadog/Tailscale отсутствуют). | none |
| OS-registered state | `VpnService` регистрируется в системе как VPN-приложение через consent (`prepare`). Прежний prepared-app сбрасывается при запуске другого VPN. | Обрабатывается в рантайме: `prepare()` на каждый Connect |
| Secrets/env vars | Нет. Демо-конфиг VLESS зашит в код (реальная ссылка в репо не попадает). UUID/creds НЕ логировать. | Проверка в code review |
| Build artifacts / installed | Смена `minSdk` 24→26 в `build.gradle.kts`; смена базового класса `MainActivity` требует пересборки APK. Прежний `app-debug.apk` из фазы 1 устаревает. | `flutter build apk --debug` заново |

**Reuse-инвентарь (in-process, фаза 1 → фаза 2):**
- **Переносится без изменений:** `VpnEventListener`, `Messages.g.kt`, Pigeon-контракт, `getStatus` snapshot-механизм.
- **Переносится с патчем:** `VpnEventBus` (потокобезопасность — обязательна, см. Pitfall 5).
- **Удаляется:** echo-цепочка внутри `VpnHostApiImpl` (`startVpn` эмитил синтетические CONNECTING/CONNECTED).

---

## Common Pitfalls

### Pitfall 1: `registerForActivityResult` не резолвится на `FlutterActivity`
**What goes wrong:** compile-error «Unresolved reference: registerForActivityResult». Текущий `MainActivity : FlutterActivity` (плоский `android.app.Activity`) не реализует `ActivityResultCaller`.
**How to avoid:** сменить базовый класс на `io.flutter.embedding.android.FlutterFragmentActivity`. Регистрировать launcher'ы как поля/в onCreate (до `STARTED`). [VERIFIED: flutter/flutter#130044]
**Warning signs:** билд Kotlin падает на `MainActivity`; альтернатива — deprecated `startActivityForResult` (работает, но грязнее).

### Pitfall 2: `startForeground` не первой строкой → `DidNotStartInTime`
**What goes wrong:** сервис делает establish/prepare до `startForeground`, система убивает через ~5 сек.
**How to avoid:** `ServiceCompat.startForeground(... "Connecting…")` первой строкой `onStartCommand`, обновление текста после establish. [CITED: PITFALLS.md P10]

### Pitfall 3: `foregroundServiceType` не объявлен → краш на API 34+
**What goes wrong:** `MissingForegroundServiceTypeException` на Android 14+ при targetSdk 34+; на API 33 всё «работает», проблему ловят поздно.
**How to avoid:** манифест `android:foregroundServiceType="systemExempted"` + permission `FOREGROUND_SERVICE_SYSTEM_EXEMPTED` + `ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED` в вызове. Прогон обязателен на эмуляторе API 34/35/36. [VERIFIED: fg-service-types doc]

### Pitfall 4: POST_NOTIFICATIONS не запрошен → уведомление молча невидимо (API 33+)
**What goes wrong:** FGS работает, но уведомления нет в шторке; на демо показать нечем. Ошибки нет.
**How to avoid:** `<uses-permission POST_NOTIFICATIONS/>` + runtime-запрос через launcher на первом Connect (одна развилка `Build.VERSION.SDK_INT >= TIRAMISU` — единственная неизбежная при minSdk 26). Канал `IMPORTANCE_LOW`, `setOngoing(true)`. Отказ не блокирует VPN. [CITED: PITFALLS.md P6]

### Pitfall 5: `VpnEventBus` из фазы 1 НЕ потокобезопасен — гонки при emit из рабочих потоков
**What goes wrong:** в фазе 1 `emit()` звали только с платформенного main thread (echo). В фазе 2 `emit()` дёргают read-loop, ticker и `onRevoke` (не main thread). Текущая реализация: `listeners = mutableSetOf(...)` + `var lastStatus/snapshot` без синхронизации. Итог: `ConcurrentModificationException` при `listeners.toList()` во время `addListener`, потерянные/порванные обновления `snapshot`.
**Why it happens:** шина проектировалась под однопоточный echo; сервис вводит многопоточность.
**How to avoid:** listeners → `CopyOnWriteArraySet`/`CopyOnWriteArrayList`; `lastStatus`/`snapshot` → `@Volatile` (или весь `emit`/`addListener` под `@Synchronized`). Доставка в sink остаётся через `Handler(mainLooper)` (`VpnEventListener` уже это делает — его менять не надо).
**Warning signs:** редкие краши/пропуски событий при активном трафике или при revoke; UI «прыгает».
[VERIFIED: android/.../VpnEventBus.kt прочитан в этой сессии — синхронизации нет]

### Pitfall 6: `onRevoke` приходит не на main thread
**What goes wrong:** прямой `sink.success()` из `onRevoke` роняет `@UiThread`; UI остаётся Connected после перехвата туннеля другим VPN.
**How to avoid:** `onRevoke` → `teardown()`; все события через `VpnEventBus` (main-thread форвардинг в `VpnEventListener`). [CITED: developer.android.com/reference/android/net/VpnService «might not happen on the main thread»]

### Pitfall 7: Утечка fd / незакрываемый blocking read
**What goes wrong:** `Thread.interrupt()` не прерывает блокирующий `read()`; fd не закрыт; при повторном Connect копятся зомби-потоки.
**How to avoid:** порядок остановки — `pfd.close()` ПЕРВЫМ (read() вернёт ошибку), потом `join(timeout)`; хранить pfd в одном месте, обнулять после close; каждый `establish()` предварять закрытием предыдущего. [CITED: PITFALLS.md P8]

### Pitfall 8: узкий маршрут + `addDnsServer` может сломать DNS
**What goes wrong:** если Android маршрутизирует ВЕСЬ DNS через VPN-интерфейс при заданном `addDnsServer`, а узкий маршрут его дропает — DNS/браузинг ложится, интернет «умирает» вопреки замыслу.
**How to avoid:** проверить на целевом эмуляторе, что при `addRoute(/24)` + `addDnsServer("1.1.1.1")` браузинг работает. Если ломается: убрать `addDnsServer` (AND-02 всё равно выполнен вызовом в коде, но безопаснее — DNS-сервер, попадающий в реальную сеть) или указать резолвер вне TUN. [ASSUMED — поведение зависит от версии Android; MEDIUM]
**Warning signs:** после Connect сайты не открываются, хотя маршрут узкий.

### Pitfall 9: Android 15/16 background-start FGS ломает старт из фона
**What goes wrong:** на Android 15+/targetSdk 35+ старт foreground-сервиса из фонового контекста блокируется (реальный кейс: Tailscale #18847 — reconnect после чужого VPN). 
**How to avoid:** для нашего скоупа безопасно: сервис стартует ТОЛЬКО по тапу Connect при видимом приложении (разрешённое исключение). Auto-reconnect/always-on вне скоупа, поэтому background-start не задевается. Зафиксировать это ограничение в README. [VERIFIED: Android 15 behavior-changes + tailscale/tailscale#18847; systemExempted не в списке BOOT_COMPLETED-ограничений]

---

## Code Examples

### `VpnNotificationFactory` (канал + уведомление, API 26)
```kotlin
// Source: developer.android.com/develop/ui/views/notifications/channels (API 26 channel)
class VpnNotificationFactory(private val context: Context) {
    fun ensureChannel() {
        val channel = NotificationChannel(CHANNEL_ID, "VPN", NotificationManager.IMPORTANCE_LOW)
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
    fun building(text: String): Notification =
        Notification.Builder(context, CHANNEL_ID)
            .setContentTitle("Oko VPN")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_vpn_ic)
            .setOngoing(true)
            .build()
    companion object { const val CHANNEL_ID = "oko_vpn" }
}
```

### State machine (переходы + логирование, AND-06)
```kotlin
sealed interface VpnConnectionState {
    data object Disconnected : VpnConnectionState
    data object Connecting : VpnConnectionState
    data class Connected(val sinceEpochMs: Long) : VpnConnectionState
    data object Disconnecting : VpnConnectionState
    data class Error(val code: String) : VpnConnectionState
}

private fun transition(next: VpnConnectionState) {
    state = next
    val status = next.toStatusMessage()                 // → VpnStatusMessage.*
    VpnEventBus.emit(LogMessage("state -> $status", System.currentTimeMillis(), "info"))
    VpnEventBus.emit(StatusChangedMessage(status, (next as? VpnConnectionState.Connected)?.sinceEpochMs))
}
```
Каждый переход эмитит `LogMessage` + `StatusChanged` — закрывает AND-06.

### Укреплённый `VpnEventBus` (дельта к фазе 1)
```kotlin
object VpnEventBus {
    private val listeners = java.util.concurrent.CopyOnWriteArraySet<(VpnEventMessage) -> Unit>()
    @Volatile var lastStatus: StatusChangedMessage = StatusChangedMessage(VpnStatusMessage.DISCONNECTED); private set
    @Volatile var snapshot: VpnStatusSnapshotMessage =
        VpnStatusSnapshotMessage(VpnStatusMessage.DISCONNECTED, rxBytes = 0L, txBytes = 0L); private set
    // addListener/removeListener/emit — логика та же, коллекция и поля теперь потокобезопасны
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `startActivityForResult` + `onActivityResult` | `registerForActivityResult` (`ActivityResultCaller`) | AndroidX Activity 1.2 (2021) | Требует `FlutterFragmentActivity`; старый API deprecated |
| `startForeground(id, notification)` | `startForeground(id, notification, type)` + `foregroundServiceType` в манифесте | Android 10 (тип) / Android 14 (обязателен) | Без типа — краш на 14+; для VPN тип `systemExempted` |
| FGS без ограничений | Ограничения background-start FGS | Android 12→15 ужесточение | Старт только из foreground/по тапу; always-on вне скоупа спасает |
| minSdk 21 (старый дефолт Flutter) | Flutter 3.44 дефолт minSdk **24** | Flutter 3.x | Фаза поднимает до 26 ради безветочного FGS/NotificationChannel |

**Deprecated/outdated:**
- `onActivityResult` override — работает, но не рекомендуется; выбор в пользу launcher-API.
- `foregroundServiceType=specialUse` для VPN — избыточно (ревью Play Console); есть точный `systemExempted`.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `addDnsServer("1.1.1.1")` при узком маршруте `/24` не ломает DNS/интернет в Connected | Pattern 3, Pitfall 8 | Интернет «умирает» на демо; лечится удалением `addDnsServer` или сменой резолвера. **Проверить на эмуляторе.** |
| A2 | `ServiceCompat.startForeground` c `FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED` корректно ведёт себя на API 26–33 (константа типа — API 34) | Standard Stack, Pattern 2 | На старых API возможно исключение; демо всё равно на API 34+, риск низкий. Прогнать на минимальном поддерживаемом эмуляторе. |
| A3 | `FlutterFragmentActivity` работает с текущими Flutter-темами (`LaunchTheme`/`NormalTheme`) без правки `styles.xml` | Pattern 1 | Возможен сбой темы; лечится AppCompat/Material-темой. **Проверить сборку/запуск.** |
| A4 | Подсеть `10.111.222.0/24` не пересекается с реальными маршрутами тестового устройства | Pattern 3 | Крайне низкий (приватный диапазон RFC 1918, нетипичный) |
| A5 | Отдача `callback(Result.success)` сразу (fire-and-forget) при отложенном consent совместима с Dart `ConnectVpn` (await startVpn возвращается быстро, прогресс — событиями) | Pattern 1 | Если Dart ждёт финального статуса в ответе startVpn — рассинхрон; фаза 1 echo уже вела себя так (совместимо) |

**Все пять помечены как требующие подтверждения на эмуляторе/устройстве при выполнении фазы (в основном A1–A3).**

---

## Open Questions

1. **DNS при узком маршруте (A1)**
   - Что знаем: узкий маршрут держит интернет; `addDnsServer` требуется AND-02.
   - Что неясно: маршрутизирует ли целевая версия Android весь DNS через TUN.
   - Рекомендация: реализовать с `addDnsServer("1.1.1.1")`, добавить device-check в чеклист; при поломке — fallback (убрать/сменить). Time-box.

2. **Kotlin-тесты state machine — стоит ли настраивать?**
   - Что знаем: таблица переходов — чистый Kotlin, JUnit-тестируема; Android-тестового рига в проекте сейчас нет.
   - Что неясно: окупается ли настройка JUnit в 48-часовом окне против ручной проверки на устройстве.
   - Рекомендация: основной гейт — `flutter build apk --debug` (компиляция) + ручной device-чеклист; JUnit на переходы — опционально (Wave 0, low priority).

3. **Кнопка «ping» в приложении vs `adb shell ping` для демо счётчиков**
   - Что знаем: обе схемы гоняют пакеты в TUN.
   - Рекомендация: для видео-демо достаточно `adb shell ping 10.111.222.1`; in-app кнопка — приятный, но необязательный штрих (не в AND-требованиях).

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Сборка APK, кодоген | ✓ | 3.44.5 stable | — |
| JDK | Gradle/Kotlin | ✓ | OpenJDK 25 (Gradle使用 JVM 17 target) | — |
| Android compile/target SDK 36 | targetSdk 36 | ✓ (дефолт Flutter 3.44.5) | 36 | — |
| `adb` (platform-tools) | Установка APK, `ping`-демо, logcat | ✗ (не в PATH) | — | Через Android Studio; добавить `platform-tools` в PATH |
| `emulator` + AVD API 34/35/36 | Проверка consent/FGS/onRevoke/трафика | ✗ (не в PATH, AVD не перечислены) | — | Создать/запустить AVD API 34+ из Android Studio |

**Missing dependencies with no fallback:** нет блокеров для написания кода. Компиляция (`flutter build apk --debug`) не требует эмулятора.

**Missing dependencies with fallback:**
- `adb`/`emulator` не на PATH: живут под Android Studio SDK. Для phase-gate (ручные проверки на устройстве) нужен запущенный **эмулятор API 34+** (systemExempted и FGS-краш видны только там). Планировщику: заложить checkpoint «поднять AVD API 34/35/36» перед ручным чеклистом.

---

## Validation Architecture

> `workflow.nyquist_validation = true`. Особенность фазы: почти все механики `VpnService` (consent-диалог, establish, видимость уведомления, onRevoke, счётчики) наблюдаемы только на устройстве/эмуляторе. Фиксируем manual-only + phase-gate.

### Test Framework
| Property | Value |
|----------|-------|
| Framework (Dart) | `flutter_test` (SDK) — но в фазе 2 Dart почти не меняется |
| Framework (Kotlin) | Отсутствует (Android-тестового рига нет). Опциональный Wave 0: JUnit на state machine |
| Config file | нет (Kotlin), `analysis_options.yaml` (Dart) |
| Quick run command | `flutter build apk --debug` (компилирует Kotlin — основной автогейт) |
| Full suite command | `flutter analyze && flutter test` (Dart-регресс) + ручной device-чеклист |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AND-01 | Consent-диалог, RESULT_OK/CANCELED | manual-only (device) | — | ❌ manual |
| AND-02 | establish на узкую подсеть, интернет жив | manual-only (device) | — | ❌ manual |
| AND-03 | FGS + уведомление + systemExempted (нет краша на API 34+) | manual-only (эмулятор API 34+) | — | ❌ manual |
| AND-04 | teardown / onRevoke → Disconnected | manual-only (device: включить второй VPN) | — | ❌ manual |
| AND-05 | Счётчики rx растут при ping | manual-only (device + `adb ping`) | — | ❌ manual |
| AND-06 | Переходы логируются | partial: логика — JUnit на переходы; видимость — device | `flutter build apk --debug` (компиляция) | ⚠️ опц. Wave 0 |
| (все) | Kotlin компилируется | smoke | `flutter build apk --debug` | ✅ |
| (регресс) | Dart-контракт цел | unit | `flutter test` | ✅ (из фазы 1) |

### Sampling Rate
- **Per task commit:** `flutter build apk --debug` (Kotlin компилируется без ошибок).
- **Per wave merge:** `flutter analyze && flutter test` (Dart-регресс зелёный).
- **Phase gate (checkpoint:human-verify на эмуляторе API 34+):**
  1. Connect → consent-диалог → RESULT_OK → статус Connected, значок ключа в статус-баре.
  2. В Connected открыть сайт в браузере — интернет работает.
  3. Уведомление FGS видно в шторке (POST_NOTIFICATIONS выдан).
  4. `adb shell ping 10.111.222.1` → счётчик rx растёт в UI.
  5. Cancel в consent-диалоге → статус Error + лог «permission denied».
  6. Включить второй VPN поверх → onRevoke → статус Disconnected + лог.
  7. Цикл Connect→Disconnect→Connect ×3 — стабильно, уведомление снимается, fd не течёт.
  8. Нет краша на старте (проверка `DidNotStartInTime` / `MissingForegroundServiceType`).

### Wave 0 Gaps
- [ ] (опц.) `android/app/src/test/kotlin/.../VpnConnectionStateTest.kt` — таблица переходов (JUnit; чистый Kotlin, без Android). Low priority.
- [ ] Эмулятор AVD API 34/35/36 доступен и запущен для phase-gate.
- [ ] `adb` в PATH для `ping`-демо и logcat.

*(Автотестов на сам `VpnService` нет по природе API — это ожидаемо и честно фиксируется.)*

---

## Security Domain

> `security_enforcement` в config.json отсутствует → трактуется как enabled. Для прототипа большинство ASVS-категорий N/A; релевантен доступ к сервису и утечка кредов.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Аккаунтов нет |
| V3 Session Management | no | Сессий нет |
| V4 Access Control | **yes** | `android:permission="android.permission.BIND_VPN_SERVICE"` на сервисе — только система может биндиться; `android:exported="false"` |
| V5 Input Validation | **yes** | `VpnConfigMessage` (host/port/userId) валидировать перед использованием в `Builder`/Intent extras (демо-конфиг зашит, но код не должен падать на кривом вводе) |
| V6 Cryptography | no | Криптографии/core нет (вне скоупа) |
| V7 Error Handling / Logging | **yes** | Не логировать сырой VLESS URI / UUID в `logMessage`; ошибки — доменные, без утечки внутренностей платформы |

### Known Threat Patterns for Android VpnService
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Произвольное приложение биндится к VPN-сервису | Elevation of Privilege | `BIND_VPN_SERVICE` permission + `exported=false` в манифесте |
| Утечка кредов (UUID) в лог/видео/репозиторий | Information Disclosure | Маскировать UUID в `logMessage`; тестовые ссылки с фейковым UUID; конфиг только in-memory |
| Хранение конфига в plaintext SharedPreferences | Information Disclosure | Держать в памяти; Keystore — продакшн-путь (README) |
| Перехват туннеля другим VPN (`onRevoke`) | Tampering / DoS | Полный `teardown`, статус Disconnected до UI — не оставлять ложный Connected |

---

## Sources

### Primary (HIGH confidence)
- [developer.android.com/develop/connectivity/vpn](https://developer.android.com/develop/connectivity/vpn) — prepare()/establish() null/onRevoke thread/protect()/Builder/foreground (WebFetch, эта сессия)
- [developer.android.com/develop/background-work/services/fg-service-types](https://developer.android.com/develop/background-work/services/fg-service-types) — systemExempted eligibility (VPN явно), permission, startForeground(type), Android 15 BOOT_COMPLETED-ограничения не включают systemExempted (WebFetch, эта сессия)
- [developer.android.com/reference/android/net/VpnService](https://developer.android.com/reference/android/net/VpnService) — «onRevoke might not happen on the main thread», establish null (reference)
- [flutter/flutter#130044](https://github.com/flutter/flutter/issues/130044) — `registerForActivityResult` требует `FlutterFragmentActivity` (WebFetch, эта сессия)
- Локальный Flutter SDK `FlutterExtension.kt` — дефолты compileSdk=36/targetSdk=36/minSdk=24 (Bash grep, эта сессия)
- Кодовая база: `android/.../bridge/*.kt`, `MainActivity.kt`, `AndroidManifest.xml`, `Messages.g.kt`, `build.gradle.kts` (Read, эта сессия)

### Secondary (MEDIUM confidence)
- [developer.android.com/about/versions/15/behavior-changes-15](https://developer.android.com/about/versions/15/behavior-changes-15) + [tailscale/tailscale#18847](https://github.com/tailscale/tailscale/issues/18847) — background-start FGS ограничения для VPN (WebSearch)
- [developer.android.com/training/basics/intents/result](https://developer.android.com/training/basics/intents/result) — паттерн ActivityResult
- `.planning/research/{STACK,ARCHITECTURE,PITFALLS}.md` — фазовая разведка от 2026-07-13 (HIGH, но на дату исследования)

### Tertiary (LOW confidence / to verify)
- Поведение `addDnsServer` при узком маршруте (A1) — не подтверждено официальным источником для конкретной версии; проверять на эмуляторе
- `ServiceCompat.startForeground` + systemExempted на API 26–33 (A2) — вывод из документации androidx, не прогонялось

---

## Metadata

**Confidence breakdown:**
- Standard stack / API-поверхность: HIGH — сверено с официальными доками Android и локальным Flutter SDK в этой сессии
- Architecture (consent-флоу, service lifecycle, reuse шины): HIGH — подтверждено чтением фактического кода фазы 1 + issue #130044
- Pitfalls: HIGH — большинство из фазовой PITFALLS.md, ключевые (потокобезопасность шины, FlutterFragmentActivity) верифицированы против кода/issue в этой сессии
- DNS при узком маршруте / systemExempted на старых API: MEDIUM/ASSUMED — требуют device-проверки (A1, A2)

**Research date:** 2026-07-13
**Valid until:** ~2026-08-13 (Android FGS-правила стабильны в рамках API 34–36; пересмотреть при смене targetSdk или мажора Flutter)
