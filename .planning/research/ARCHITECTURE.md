# Architecture Research

**Domain:** Flutter VPN-прототип с нативной интеграцией (Pigeon bridge, Android VpnService, iOS Network Extension)
**Researched:** 2026-07-13
**Confidence:** HIGH (Pigeon и Flutter-слой: официальный пример flutter/packages, pub.dev; iOS: Apple docs; Android 14 FGS types: developer.android.com, MEDIUM по деталям systemExempted)

## Standard Architecture

### System Overview

```
┌──────────────────────────────── Flutter (Dart) ────────────────────────────────┐
│  PRESENTATION   VpnHomeScreen · LogConsole · ServerCard                        │
│                 VpnConnectionController · VpnLogsController (Notifier)         │
│        │ методы вызова              ▲ AsyncValue / Stream                      │
│  DOMAIN         ConnectVpn · DisconnectVpn · WatchVpnState · ParseVlessUri     │
│                 VpnRepository (interface) · LogRepository (interface)          │
│                 Entities: VpnState, VpnConfig, TrafficStats, LogEntry          │
│        │ interface                  ▲ Stream<VpnState> / Stream<LogEntry>      │
│  DATA           VpnRepositoryImpl · LogRepositoryImpl · mappers (DTO→entity)   │
│                 VpnNativeDatasource → core/bridge/VpnBridge                    │
├───────────────────────────── Pigeon (generated) ───────────────────────────────┤
│  VpnHostApi (Flutter→native) · vpnEvents(): Stream<VpnEventMessage>            │
├──────────────── Android (Kotlin) ────────────┬────────── iOS (Swift) ──────────┤
│  MainActivity:                               │  AppDelegate:                   │
│    VpnHostApiImpl · VpnEventStreamHandler    │    VpnHostApiImpl (NETunnel-    │
│        │ Intent / startForegroundService     │    ProviderManager) · Stream-   │
│        ▼            ▲ VpnEventBus SharedFlow │    Handler (NEVPNStatus notif.) │
│  OkoVpnService (VpnService):                 │        │ startVPNTunnel()       │
│    state machine · Builder.establish()       │        ▼                        │
│    Foreground notification · onRevoke        │  PacketTunnelProvider           │
│                                              │  (extension target, skeleton)   │
│                                              │  App Group: shared defaults     │
└──────────────────────────────────────────────┴─────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Pigeon-контракт (`pigeons/vpn_api.dart`) | Единственный источник истины моста: методы, события, DTO | `@HostApi` + `@EventChannelApi` + sealed-иерархия событий |
| `core/bridge/VpnBridge` | Единственная точка контакта с генерированным кодом; демультиплексирует один event-стрим на типизированные broadcast-стримы | Обёртка над `VpnHostApi` и `vpnEvents()`, синглтон в DI |
| Feature datasource | Адаптирует `VpnBridge` под нужды фичи, переводит DTO в entity | `VpnNativeDatasource`, `LogNativeDatasource` |
| Repository impl (data) | Реализует доменный интерфейс, держит кэш последнего статуса, реплеит его новым подписчикам | `VpnRepositoryImpl` с `StreamController.broadcast` |
| Use cases (domain) | Одно бизнес-действие на класс, без зависимостей на Flutter/Pigeon | `ConnectVpn`, `DisconnectVpn`, `WatchVpnState`, `ParseVlessUri` |
| Controller/Notifier (presentation) | Состояние экрана, блокировка кнопок в переходных статусах, таймер подключения | Riverpod `Notifier`/`AsyncNotifier` (либо Bloc, решает STACK.md) |
| `MainActivity` (Kotlin) | Регистрация Pigeon-реализаций, consent-флоу `VpnService.prepare()`, запуск/остановка сервиса | `configureFlutterEngine` + `registerForActivityResult` |
| `OkoVpnService` (Kotlin) | Жизненный цикл туннеля: state machine, `Builder.establish()`, foreground-уведомление, `onRevoke` | Наследник `android.net.VpnService` |
| `VpnEventBus` (Kotlin) | Транспорт событий service → activity внутри процесса, буфер для событий до подписки Dart | `object` с `MutableSharedFlow(replay = 64)` |
| `VpnHostApiImpl` (Swift) | Управление профилем и туннелем из контейнер-приложения | `NETunnelProviderManager` load/save/startVPNTunnel |
| `PacketTunnelProvider` (Swift, extension) | Skeleton туннеля: `startTunnel`/`stopTunnel`, `NEPacketTunnelNetworkSettings` | Отдельный extension-target, свой процесс и entitlements |

## Recommended Project Structure

### Flutter (`lib/` + `pigeons/`)

```
pigeons/
└── vpn_api.dart                        # Pigeon-контракт: VpnHostApi, VpnEventsApi, DTO, enum

lib/
├── main.dart                           # bootstrap, ProviderScope
├── app/
│   ├── app.dart                        # MaterialApp, тема, маршрут на единственный экран
│   └── di.dart                         # composition root: providers для bridge/repos/usecases
├── core/
│   ├── bridge/
│   │   ├── vpn_api.g.dart              # dartOut Pigeon (генерируется, в git)
│   │   └── vpn_bridge.dart             # обёртка: HostApi + демультиплексор событий
│   ├── error/
│   │   ├── failures.dart               # доменные Failure-типы
│   │   └── vpn_exception.dart          # маппинг PlatformException → typed errors
│   └── theme/
│       └── app_theme.dart
├── features/
│   ├── vpn_connection/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── vpn_state.dart      # sealed: Disconnected/Connecting/Connected/Disconnecting/Error
│   │   │   │   ├── vpn_config.dart
│   │   │   │   └── traffic_stats.dart
│   │   │   ├── repositories/
│   │   │   │   └── vpn_repository.dart # interface: connect/disconnect/watchState/watchTraffic/currentState
│   │   │   └── usecases/
│   │   │       ├── connect_vpn.dart
│   │   │       ├── disconnect_vpn.dart
│   │   │       ├── watch_vpn_state.dart
│   │   │       └── watch_traffic.dart
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── vpn_native_datasource.dart
│   │   │   ├── mappers/
│   │   │   │   └── vpn_event_mapper.dart   # VpnEventMessage → VpnState/TrafficStats
│   │   │   └── repositories/
│   │   │       └── vpn_repository_impl.dart
│   │   └── presentation/
│   │       ├── controllers/
│   │       │   └── vpn_connection_controller.dart
│   │       ├── screens/
│   │       │   └── vpn_home_screen.dart
│   │       └── widgets/
│   │           ├── status_indicator.dart
│   │           ├── connect_button.dart
│   │           ├── connection_timer.dart
│   │           └── traffic_panel.dart
│   ├── vpn_logs/
│   │   ├── domain/
│   │   │   ├── entities/log_entry.dart
│   │   │   ├── repositories/log_repository.dart
│   │   │   └── usecases/watch_logs.dart
│   │   ├── data/
│   │   │   ├── datasources/log_native_datasource.dart
│   │   │   └── repositories/log_repository_impl.dart
│   │   └── presentation/
│   │       ├── controllers/vpn_logs_controller.dart
│   │       └── widgets/log_console.dart
│   └── server_config/
│       ├── domain/
│       │   ├── entities/vless_config.dart
│       │   ├── repositories/config_repository.dart
│       │   └── usecases/parse_vless_uri.dart
│       ├── data/
│       │   ├── parsers/vless_uri_parser.dart
│       │   └── repositories/config_repository_impl.dart
│       └── presentation/
│           ├── controllers/server_config_controller.dart
│           └── widgets/server_card.dart
test/
└── features/server_config/data/parsers/vless_uri_parser_test.dart
```

### Android (`android/app/src/main/kotlin/<pkg>/`)

```
<pkg>/
├── MainActivity.kt                     # configureFlutterEngine: регистрация HostApi + StreamHandler,
│                                       # registerForActivityResult для VpnService.prepare()
├── bridge/
│   ├── Messages.g.kt                   # kotlinOut Pigeon (генерируется)
│   ├── VpnHostApiImpl.kt               # startVpn → consent → startForegroundService; stopVpn; getStatus
│   └── VpnEventStreamHandler.kt        # extends VpnEventsStreamHandler: collect VpnEventBus → sink (Main)
└── vpn/
    ├── OkoVpnService.kt                # VpnService: onStartCommand, Builder, establish, onRevoke, onDestroy
    ├── VpnConnectionStateMachine.kt    # sealed states + допустимые переходы
    ├── VpnEventBus.kt                  # object: MutableSharedFlow<VpnEventMessage>(replay=64) + StateFlow статуса
    └── VpnNotificationFactory.kt       # NotificationChannel + notification для startForeground
```

### iOS (`ios/`)

```
ios/
├── Runner/                             # контейнер-приложение
│   ├── AppDelegate.swift               # регистрация Pigeon-реализаций
│   ├── Bridge/
│   │   ├── Messages.g.swift            # swiftOut Pigeon (генерируется)
│   │   ├── VpnHostApiImpl.swift        # NETunnelProviderManager: loadAllFromPreferences, saveToPreferences,
│   │   │                               # startVPNTunnel / stopVPNTunnel
│   │   └── VpnEventStreamHandler.swift # NEVPNStatusDidChange → PigeonEventSink
│   └── Runner.entitlements             # packet-tunnel-provider + App Group
└── PacketTunnel/                       # отдельный extension-target
    ├── PacketTunnelProvider.swift      # NEPacketTunnelProvider: startTunnel/stopTunnel skeleton
    ├── Info.plist                      # NSExtensionPointIdentifier: com.apple.networkextension.packet-tunnel
    └── PacketTunnel.entitlements       # тот же App Group
```

### Structure Rationale

- **`pigeons/` в корне пакета:** конвенция экосистемы (flutter/packages); контракт лежит вне `lib/`, потому что это исходник кодогенерации, а не runtime-код.
- **Генерированный код в `core/bridge/`, а не в фиче:** мост обслуживает три фичи сразу (статус, логи, трафик). Один `VpnBridge` демультиплексирует поток и отдаёт типизированные стримы; фичи не знают друг о друге и не дублируют подписку на single-subscription стрим Pigeon.
- **`vpn_connection` и `vpn_logs` как отдельные фичи:** у них разные экранные зоны, разные entity и независимые контроллеры; при этом обе питаются от одного `VpnBridge` через свои datasource. Трафик оставлен внутри `vpn_connection` (одна панель на том же экране, отдельная фича избыточна для 48 часов).
- **`server_config` как чистая Dart-фича:** парсер VLESS не трогает мост, тестируется юнитами без платформы, пишется параллельно с нативной частью.
- **Kotlin: `bridge/` отделён от `vpn/`:** `bridge/` знает про Pigeon и Flutter engine, `vpn/` знает только Android SDK и `VpnEventBus`. Сервис можно тестировать и запускать без Flutter.

## Architectural Patterns

### Pattern 1: Pigeon-контракт с DTO-суффиксами + маппинг в data-слое

**What:** Все типы в `pigeons/vpn_api.dart` получают суффикс `Message` (`VpnConfigMessage`, `StatusChangedMessage`). Data-слой маппит их в доменные entity. Domain не импортирует `vpn_api.g.dart` ни в одном файле.
**When to use:** Всегда при кодогенерации: генерированные классы не соответствуют требованиям домена (иммутабельность, sealed-иерархии, value semantics).
**Trade-offs:** Плюс дублирование моделей и ручные мапперы; взамен домен переживает смену версии Pigeon и остаётся тестируемым без моков платформы.

**Example (контракт):**
```dart
@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/core/bridge/vpn_api.g.dart',
  kotlinOut: 'android/app/src/main/kotlin/com/example/vpn_oko/bridge/Messages.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.example.vpn_oko.bridge'),
  swiftOut: 'ios/Runner/Bridge/Messages.g.swift',
  dartPackageName: 'vpn_oko',
))
enum VpnStatusMessage { disconnected, connecting, connected, disconnecting, error }

class VpnConfigMessage {
  late String host;
  late int port;
  late String userId;
  late String serverName;
}

sealed class VpnEventMessage {}

class StatusChangedMessage extends VpnEventMessage {
  late VpnStatusMessage status;
}

class LogMessage extends VpnEventMessage {
  late String text;
  late int timestampMillis;
  late String level;
}

class TrafficChangedMessage extends VpnEventMessage {
  late int rxBytes;
  late int txBytes;
}

class ErrorMessage extends VpnEventMessage {
  late String code;
  late String description;
}

@HostApi()
abstract class VpnHostApi {
  @async
  void startVpn(VpnConfigMessage config);
  @async
  void stopVpn();
  VpnStatusMessage getStatus();
}

@EventChannelApi()
abstract class VpnEventsApi {
  VpnEventMessage vpnEvents();
}
```

Генерация: `dart run pigeon --input pigeons/vpn_api.dart`. Pigeon 27.x поддерживает sealed-иерархии в event channel для Dart/Kotlin/Swift (официальный пример `PlatformEvent` → `IntEvent`/`StringEvent`).

### Pattern 2: Один event channel + демультиплексор в VpnBridge

**What:** Все четыре типа событий (statusChanged, logMessage, trafficChanged, error) идут через один `vpnEvents()` как sealed-иерархия. `VpnBridge` подписывается на генерированный стрим ровно один раз и раздаёт broadcast-стримы по типам.
**When to use:** Когда важен относительный порядок событий (error сразу после statusChanged) и когда несколько фич слушают один источник.
**Trade-offs:** Один общий канал вместо четырёх упрощает lifecycle и сохраняет порядок; минус: switch по типам в одном месте. Четыре отдельных `@EventChannelApi`-метода дали бы независимые подписки, но потеряли бы упорядоченность и удвоили нативный boilerplate.

**Example:**
```dart
class VpnBridge {
  VpnBridge(this._hostApi) {
    _subscription = vpnEvents().listen(_dispatch, onError: _dispatchError);
  }

  final VpnHostApi _hostApi;
  late final StreamSubscription<VpnEventMessage> _subscription;
  final _statusController = StreamController<StatusChangedMessage>.broadcast();
  final _logController = StreamController<LogMessage>.broadcast();
  final _trafficController = StreamController<TrafficChangedMessage>.broadcast();
  final _errorController = StreamController<ErrorMessage>.broadcast();

  Stream<StatusChangedMessage> get statusEvents => _statusController.stream;
  Stream<LogMessage> get logEvents => _logController.stream;
  Stream<TrafficChangedMessage> get trafficEvents => _trafficController.stream;
  Stream<ErrorMessage> get errorEvents => _errorController.stream;

  Future<void> startVpn(VpnConfigMessage config) => _hostApi.startVpn(config);
  Future<void> stopVpn() => _hostApi.stopVpn();
  Future<VpnStatusMessage> getStatus() => _hostApi.getStatus();

  void _dispatch(VpnEventMessage event) {
    switch (event) {
      case StatusChangedMessage():
        _statusController.add(event);
      case LogMessage():
        _logController.add(event);
      case TrafficChangedMessage():
        _trafficController.add(event);
      case ErrorMessage():
        _errorController.add(event);
    }
  }
}
```

### Pattern 3: Native как источник истины + replay последнего статуса

**What:** Текущий статус VPN живёт в нативном слое (сервис переживает пересоздание Activity и hot restart Flutter). Repository при создании вызывает `getStatus()` и кэширует последний `VpnState`; `watchState()` сначала отдаёт кэш, потом broadcast-обновления. На Kotlin-стороне `MutableSharedFlow(replay = 64)` буферизует события, возникшие между стартом сервиса и подпиской Dart.
**When to use:** Любой мост с событиями: broadcast-стрим без replay теряет статус для подписчиков, пришедших позже (например, после навигации или hot restart).
**Trade-offs:** Двойная защита (getStatus-синхронизация + replay-буфер) стоит немного кода, но закрывает все гонки старта.

**Example:**
```dart
class VpnRepositoryImpl implements VpnRepository {
  VpnRepositoryImpl(this._datasource) {
    _datasource.states.listen((state) {
      _last = state;
      _controller.add(state);
    });
  }

  final VpnNativeDatasource _datasource;
  final _controller = StreamController<VpnState>.broadcast();
  VpnState _last = const VpnState.disconnected();

  @override
  Stream<VpnState> watchState() async* {
    yield _last;
    yield* _controller.stream;
  }

  @override
  Future<void> syncStatus() async {
    _last = (await _datasource.currentStatus()).toEntity();
    _controller.add(_last);
  }
}
```

### Pattern 4: Connection state machine внутри Android-сервиса

**What:** `OkoVpnService` владеет sealed-иерархией состояний и таблицей допустимых переходов (`Disconnected → Connecting → Connected → Disconnecting → Disconnected`, из любого — `Error`). Каждый переход публикуется в `VpnEventBus` и обновляет foreground-уведомление. Flutter только отображает состояния и блокирует кнопки в `Connecting`/`Disconnecting`.
**When to use:** Всегда, когда UI и сервис живут в разных мирах: без единой машины состояний появляются рассинхроны (кнопка Connect активна при уже поднятом туннеле).
**Trade-offs:** Немного формализма в прототипе, зато переходы проверяемы и `onRevoke`/ошибки establish ложатся в ту же модель.

**Example (Kotlin, событие в главный поток):**
```kotlin
class VpnEventStreamHandler : VpnEventsStreamHandler() {
    private var sink: PigeonEventSink<VpnEventMessage>? = null
    private var job: Job? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<VpnEventMessage>) {
        this.sink = sink
        job = CoroutineScope(Dispatchers.Main).launch {
            VpnEventBus.events.collect { event -> this@VpnEventStreamHandler.sink?.success(event) }
        }
    }

    override fun onCancel(p0: Any?) {
        job?.cancel()
        sink = null
    }
}
```

Ключевое требование Flutter: события в engine отправляются только из главного потока платформы, иначе crash. Сервис пишет в `SharedFlow` из любого потока, коллектор в `Dispatchers.Main` доставляет в sink.

### Pattern 5: iOS app ↔ extension через NETunnelProviderManager и App Group

**What:** Контейнер-приложение управляет профилем через `NETunnelProviderManager` (load → configure → save → `startVPNTunnel`), extension реализует `NEPacketTunnelProvider.startTunnel/stopTunnel`. Общие данные (конфиг, логи extension) идут через `UserDefaults(suiteName: "group.<bundleId>")`. Статусы приложение читает из `NEVPNStatusDidChange`-нотификаций и транслирует в тот же Pigeon event channel.
**When to use:** Единственная архитектура, которую допускает iOS: код туннеля обязан жить в отдельном extension-процессе.
**Trade-offs:** Для прототипа extension остаётся skeleton (реальный запуск требует entitlement от Apple), но структура таргетов, entitlements и App Group делаются полноценно, и Swift-реализация Pigeon-контракта компилируется. `bundleId` extension обязан быть префиксован `bundleId` приложения; `NSExtensionPrincipalClass` должен указывать на подкласс провайдера.

## Data Flow

### Command Flow (Flutter → native)

```
[Tap Connect]
    ↓
VpnConnectionController.connect()
    ↓
ConnectVpn (use case) ── валидация конфига
    ↓
VpnRepository.connect(config)  (interface)
    ↓
VpnNativeDatasource → VpnBridge.startVpn(VpnConfigMessage)
    ↓ Pigeon HostApi (binary messenger)
Android: VpnHostApiImpl.startVpn
    ↓ VpnService.prepare() == null ? : consent-интент → registerForActivityResult
    ↓ RESULT_OK
startForegroundService(Intent + config extras)
    ↓
OkoVpnService: state → Connecting → Builder(addAddress, addRoute, addDnsServer).establish()
    ↓ tun fd получен
state → Connected
```

iOS-ветка: `VpnHostApiImpl.startVpn` → `NETunnelProviderManager.loadAllFromPreferences` → save профиля → `startVPNTunnel()` → система поднимает extension-процесс → `PacketTunnelProvider.startTunnel` → `setTunnelNetworkSettings` → `completionHandler(nil)`.

### Event Flow (native → Flutter)

```
OkoVpnService (любой поток)
    ↓ VpnEventBus.emit(StatusChangedMessage / LogMessage / TrafficChangedMessage / ErrorMessage)
MutableSharedFlow(replay = 64)
    ↓ collect в Dispatchers.Main (VpnEventStreamHandler)
PigeonEventSink.success(event)          ← ТОЛЬКО главный поток
    ↓ EventChannel → main isolate
vpnEvents(): Stream<VpnEventMessage>    ← single-subscription, слушает только VpnBridge
    ↓ демультиплексирование по sealed-типу
broadcast-стримы VpnBridge
    ↓ datasource → mapper (DTO → entity)
VpnRepositoryImpl (кэш последнего VpnState) / LogRepositoryImpl (ring buffer логов)
    ↓ Stream<VpnState> / Stream<LogEntry>
Controllers → UI (статус, таймер, трафик, консоль логов)
```

### State Management

- Источник истины по статусу туннеля: нативный сервис. Flutter-слой при старте и при `AppLifecycleState.resumed` вызывает `getStatus()` и сверяет кэш.
- Контроллеры держат только экранное состояние: производный `canConnect`/`canDisconnect`, значение таймера, отформатированный трафик.
- Таймер подключения считается во Flutter от момента получения `Connected` (для прототипа достаточно; точный uptime потребовал бы поля в статус-событии).

### Key Data Flows

1. **Consent-флоу Android:** `startVpn` не завершается до результата системного диалога `VpnService.prepare()`. Отказ пользователя возвращается как `ErrorMessage(code: "consent_denied")`, состояние остаётся `Disconnected`.
2. **onRevoke:** другая VPN-программа перехватила туннель → сервис закрывает `ParcelFileDescriptor`, `stopForeground`, эмитит `StatusChanged(disconnected)` + `LogMessage`, `stopSelf()`.
3. **Hot restart / пересоздание Activity:** Dart-подписка пересоздаётся → `onListen` вызывается снова → replay-буфер SharedFlow и `getStatus()` восстанавливают консистентность без участия сервиса.

## Suggested Build Order

Зависимости диктуют порядок; самый рискованный интеграционный шов (мост + сервис) закрывается раньше UI-полировки.

| # | Шаг | Зависит от | Почему здесь |
|---|-----|------------|--------------|
| 1 | Pigeon-контракт + кодоген + пустые нативные реализации (echo) | — | Фундамент: все слои по обе стороны зависят от генерированных типов |
| 2 | Domain-слой всех трёх фич (entities, интерфейсы репозиториев, use cases) | — | Чистый Dart, параллелится с п.1, фиксирует границы |
| 3 | Android: `OkoVpnService` + state machine + `VpnEventBus` + notification + consent-флоу | 1 | Главный критерий «сильного решения»; проверяется руками до готового UI |
| 4 | Data-слой: `VpnBridge`, datasources, mappers, repository impl | 1, 2, 3 | Соединяет домен с мостом; smoke-тест round-trip статусов |
| 5 | Presentation: контроллеры + экран (статусы, кнопки, таймер, трафик, лог-консоль) | 2, 4 | UI можно начинать раньше на fake-репозитории, финалится на реальном |
| 6 | `server_config`: VLESS-парсер + юнит-тесты + отображение сервера | 2 | Чистый Dart, параллелится с 3–5 |
| 7 | iOS: extension-target, entitlements, App Group, `PacketTunnelProvider` skeleton, Swift-реализация Pigeon | 1 | Компилируемость + доки; не блокирует Android-ветку |
| 8 | README (архитектура, запуск, план интеграции VPN-core) + видео | всё | Формат сдачи |

Точки параллелизма: (2, 6) не ждут никого; (3) и (5-на-fake) идут одновременно после (1).

## Scaling Considerations

Для прототипа масштаб — это эволюция кода, не нагрузка.

| Стадия | Architecture Adjustments |
|--------|--------------------------|
| Прототип (текущий скоуп) | Один Pigeon-контракт, один сервис, DI через простые providers; ничего не выносить в пакеты |
| + реальный VPN-core (sing-box / libXray) | Core подключается только внутри `vpn/` (Android .aar через JNI/gomobile) и внутри extension (iOS xcframework); контракт моста и domain не меняются, добавляется адаптер core → state machine |
| + продуктовые фичи (серверы, аккаунты) | Мост выносится в federated plugin-пакет (`packages/vpn_bridge`), фичи остаются в приложении |

### Scaling Priorities

1. **Первое узкое место:** частота `trafficChanged`. Слать не чаще 1 Гц и агрегировать на нативной стороне, иначе канал и UI захлёбываются перерисовками.
2. **Второе:** объём лог-буфера. Ring buffer с лимитом (например, 500 записей) и на Kotlin-стороне (`replay`), и в `LogRepositoryImpl`.

## Anti-Patterns

### Anti-Pattern 1: Domain импортирует генерированный Pigeon-код

**What people do:** Используют `VpnConfigMessage` и `VpnStatusMessage` как доменные модели «чтобы не дублировать».
**Why it's wrong:** Домен привязывается к формату кодогенератора; смена версии Pigeon или контракта ломает use cases и тесты; sealed-паттерны домена не совпадают с ограничениями Pigeon-типов.
**Do this instead:** Суффикс `Message` в контракте, мапперы в `data/mappers/`, доменные entity со своей семантикой (sealed `VpnState` с payload ошибки).

### Anti-Pattern 2: События в sink из фонового потока

**What people do:** Вызывают `eventSink.success(...)` прямо из потока сервиса или из coroutine на `Dispatchers.IO`.
**Why it's wrong:** Каналы платформы требуют главный поток при отправке в engine; приложение падает, причём не всегда сразу.
**Do this instead:** `SharedFlow` как транспорт + коллектор строго на `Dispatchers.Main` (или `Handler(Looper.getMainLooper()).post`).

### Anti-Pattern 3: Статус VPN живёт только во Flutter

**What people do:** Контроллер сам переводит состояние в `Connected` после успешного `await startVpn()`.
**Why it's wrong:** Сервис живёт дольше Activity; после hot restart, сворачивания или `onRevoke` UI показывает ложный статус.
**Do this instead:** Статус меняется только событиями из native; `getStatus()` при старте и resume; replay-буфер на Kotlin-стороне.

### Anti-Pattern 4: Несколько подписок на генерированный стрим

**What people do:** Каждая фича вызывает `vpnEvents()` сама.
**Why it's wrong:** Каждый вызов создаёт подписку на event channel; single-subscription семантика и повторные `onListen`/`onCancel` дают гонки и потерю событий.
**Do this instead:** Ровно одна подписка в `VpnBridge`, дальше broadcast-стримы.

### Anti-Pattern 5: Забытый lifecycle туннеля на Android

**What people do:** Не реализуют `onRevoke`, не закрывают `ParcelFileDescriptor`, не вызывают `stopForeground`, не объявляют `foregroundServiceType`.
**Why it's wrong:** Утечка fd, зависшее уведомление, `MissingForegroundServiceTypeException` на Android 14+ (краш при `startForeground`).
**Do this instead:** `onRevoke` → полная остановка + событие; `close()` fd в `onDestroy`; в манифесте `android:foregroundServiceType="systemExempted"` (VPN-приложения, настроенные через системные VPN-настройки, входят в исключения) с permission `FOREGROUND_SERVICE_SYSTEM_EXEMPTED`; запасной вариант — `specialUse` с обоснованием. На API 33+ запрашивать `POST_NOTIFICATIONS`.

### Anti-Pattern 6: Логика туннеля в контейнер-приложении iOS

**What people do:** Пытаются поднять туннель классом внутри Runner-таргета.
**Why it's wrong:** iOS исполняет туннель только в NetworkExtension-процессе; из приложения доступно лишь управление профилем.
**Do this instead:** Extension-target с `NEPacketTunnelProvider`, приложение общается через `NETunnelProviderManager` и App Group.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Pigeon codegen | `dart run pigeon --input pigeons/vpn_api.dart` | Pigeon 27.1.1; event channels генерируются только для Dart/Kotlin/Swift; генерированные файлы коммитятся |
| Android VpnService | Манифест: `android:permission="android.permission.BIND_VPN_SERVICE"` + intent-filter `android.net.VpnService`; `prepare()` consent через Activity | `establish()` возвращает `ParcelFileDescriptor`; без VPN-core пакеты из tun читаются и дропаются (или не читаются вовсе) |
| iOS Network Extension | Capability Network Extensions (packet-tunnel) на оба таргета + App Groups | Личная команда без Apple-approved entitlement: компилируется, но `saveToPreferences` на устройстве вернёт permission error; фиксируется в README |
| VPN-core (будущее) | Android: .aar (gomobile/JNI) внутри `vpn/`; iOS: xcframework внутри extension | Точки подключения описываются в README, контракт моста не меняется |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| presentation ↔ domain | Вызовы use cases, подписка на `Stream<Entity>` | Контроллеры не знают о data-слое |
| domain ↔ data | Интерфейсы репозиториев (инверсия зависимостей) | Единственная граница, где связываются слои; связывание в `app/di.dart` |
| data ↔ core/bridge | `VpnBridge` (типы Pigeon видны только здесь и в mappers) | Импорт `vpn_api.g.dart` разрешён только в `core/bridge/` и `features/*/data/` |
| Flutter ↔ Kotlin/Swift | Pigeon: HostApi (команды) + один EventChannel (события) | Никаких сырых MethodChannel рядом с Pigeon |
| MainActivity ↔ OkoVpnService | Intent (команды) + `VpnEventBus` SharedFlow (события) | Один процесс; bound service не нужен |
| Runner ↔ PacketTunnel | `NETunnelProviderManager` (управление) + App Group UserDefaults (данные) | Разные процессы; прямых вызовов нет |

## Sources

- [Pigeon — pub.dev](https://pub.dev/packages/pigeon) — версия 27.1.1, аннотации, поддержка event channels (HIGH)
- [Pigeon example README — flutter/packages](https://github.com/flutter/packages/blob/main/packages/pigeon/example/README.md) — `@EventChannelApi`, `PigeonEventSink`, `StreamHandler.register`, sealed-события, `@ConfigurePigeon` (HIGH)
- [Writing custom platform-specific code — docs.flutter.dev](https://docs.flutter.dev/platform-integration/platform-channels) — требование главного потока при отправке в engine (HIGH)
- [Foreground service types — developer.android.com](https://developer.android.com/develop/background-work/services/fgs/service-types) и [FGS types required (Android 14)](https://developer.android.com/about/versions/14/changes/fgs-types-required) — `systemExempted` для VPN-приложений, обязательность типа (MEDIUM: проверено по официальным страницам через поиск)
- [NETunnelProviderManager — Apple Developer](https://developer.apple.com/documentation/networkextension/netunnelprovidermanager) — управление туннелем из контейнер-приложения (HIGH)
- [VPN, Part 2: Packet Tunnel Provider — kean.blog](https://kean.blog/post/packet-tunnel-provider) и [VPN, Part 1: VPN Profiles](https://kean.blog/post/vpn-configuration-manager) — структура app/extension, App Groups, lifecycle `startTunnel` (MEDIUM)
- [flutter_vpn_service — pub.dev](https://pub.dev/packages/flutter_vpn_service), [VPNclient-engine-flutter — GitHub](https://github.com/VPNclient/VPNclient-engine-flutter) — практика разделения платформенных слоёв в VPN-плагинах (LOW, ориентир)

---
*Architecture research for: Flutter VPN-прототип с нативной интеграцией*
*Researched: 2026-07-13*
