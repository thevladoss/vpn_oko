# Phase 3: Flutter UI — Research

**Researched:** 2026-07-14
**Domain:** Flutter presentation-слой (flutter_bloc 9.x, CustomPainter/AnimationController, Material 3 темы, google_fonts, bloc_test)
**Confidence:** HIGH

## Summary

Фаза строит presentation-слой поверх готовых domain/data слоёв. Мост, репозитории и usecases уже собраны и покрыты тестами; менять их не нужно. Задача: заменить `DebugHarness` на `VpnHomeScreen` с ирис-индикатором (`CustomPainter`), пятью статусами, кнопкой Connect/Disconnect с блокировкой, живыми логами, карточкой сервера, таймером, трафиком, двумя темами, восстановлением состояния и unit-тестами Bloc.

Главная техническая развилка фазы: как Bloc подписывается на два бесконечных repository-стрима (`watchVpnState()` и `watchTraffic()`). Наивный вариант из UI-SPEC (два `emit.forEach` подряд в одном обработчике `VpnStarted`) не работает: `emit.forEach` ждёт завершения стрима, а стрим статуса бесконечен, поэтому вторая подписка на трафик никогда не стартует. Рабочий паттерн из официальных доков Bloc: подписаться на каждый стрим через `.listen((data) => add(_Internal(data)))`, хранить `StreamSubscription` полями и отменять их в `close()`. Контракт UI-SPEC уже содержит нужные внутренние события (`VpnStateReceived`, `VpnTrafficReceived`) под этот паттерн.

Обе новые зависимости (`google_fonts` runtime, `bloc_test` dev) существуют на pub.dev в актуальных версиях. `google_fonts` по умолчанию тянет шрифты по HTTP при первом запуске; для офлайн-надёжности демо (ревьюер, эмулятор без сети) шрифты бандлятся ассетами в папку `google_fonts/`. slopcheck в окружении недоступен, поэтому обе зависимости помечены как требующие человеко-верификации перед установкой (обе — официальные пакеты команд Flutter/Bloc, риск минимальный).

**Primary recommendation:** Bloc подписывается на стримы через internal-events (`.listen → add`), НЕ через двойной `emit.forEach`; `syncStatus()` вызывается первым в `VpnStarted` (UI-07); ирис рисуется одним `CustomPainter`, управляется несколькими `AnimationController` в `StatefulWidget` с уважением к `MediaQuery.disableAnimationsOf`; таймер держит `connectedSince` в state Bloc (источник истины), а виджет только тикает `Timer.periodic`.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UI-01 | Пять статусов VPN | Прямой маппинг `VpnState` (sealed) → `VpnStatus` (enum) в Bloc; `IrisIndicator` + `StatusBadge` рендерят статус (см. Architecture, Iris CustomPainter) |
| UI-02 | Connect/Disconnect с блокировкой | `ConnectButton` `onPressed: null` в переходных + Bloc-гейт `isBusy` (двойная защита); паттерн ниже |
| UI-03 | Живые логи, буфер, автоскролл с отключением | `LogsCubit` (буфер уже cap 500 в репозитории) + `LogConsole` со `ScrollController` + `NotificationListener<ScrollNotification>` |
| UI-04 | Сервер + таймер от connectedSince | `connectedSince` в Bloc-state; `ConnectionTimer` с `Timer.periodic`, переживает rebuild (источник истины в state) |
| UI-05 | Трафик rx/tx | `VpnTrafficReceived` → `rxBytes`/`txBytes` в state; `TrafficTile` с форматтером байт |
| UI-06 | Дизайн-концепция: ирис, темы, staggered, haptics | `OkoTones` `ThemeExtension`, `CustomPainter`, staggered-вход, `HapticFeedback` |
| UI-07 | Восстановление через getStatus() | `VpnStarted` → `syncStatus()` первым действием в Bloc |
| UI-08 | Уровни логов + copy-all | `LogLine` цвет по `LogLevel`; `Clipboard.setData` + `LogsState.plainText()` |
| QA-02 | Unit-тесты Bloc | `bloc_test` 10.0.0: переходы, error, onRevoke, double-tap guard, syncStatus (6 сценариев UI-SPEC) |
</phase_requirements>

## Project Constraints (from CLAUDE.md / CONVENTIONS.md)

Директивы проекта имеют тот же вес, что locked-решения. Планировщик обязан проверить соответствие:

- **Feature-first clean architecture:** presentation-слой в `lib/features/<feature>/presentation/`; общее (темы) в `lib/core/theme/`, composition root в `lib/app/di.dart`.
- **SOLID + конструкторная инъекция:** Bloc принимает usecases через конструктор; presentation не импортирует data напрямую и не знает про `*.g.dart`. Импорт `*.g.dart` разрешён только в `core/bridge/` и `features/*/data/`.
- **Комментарии в коде запрещены** (Dart/Kotlin/Swift). Имена несут смысл. Примеры кода в этом документе содержат пояснительные комментарии только для читателя-планировщика; в реальный код они не переносятся.
- **State management только Bloc:** бизнес-логика в `Bloc`/`Cubit`, виджеты держат только `BlocBuilder`/`BlocListener`/`BlocSelector` и разметку.
- **Модели через sealed classes + equatable, immutable.** Никакого freezed/json_serializable. `copyWith` пишется руками.
- **Линтер:** `very_good_analysis` 10.3.0 с `public_member_api_docs: false` и `one_member_abstracts: false`. Новый код проходит `flutter analyze` без варнингов (строгие правила VGA: `prefer_const_constructors`, `require_trailing_commas`, `avoid_positional_boolean_parameters`, `lines_longer_than_80_chars` и т.д.).
- **Язык:** идентификаторы/код английский; доки/коммиты русский. Экранные строки английские (см. Copywriting Contract в UI-SPEC).
- **Хардкод цветов в виджетах запрещён** (UI-SPEC): цвета только через `Theme.of(context).extension<OkoTones>()!`.
- **Test-as-you-go:** код → тесты → прогон в том же заходе; перед коммитом весь набор зелёный. `flutter test` должен оставаться зелёным (в проекте уже 6 тестовых файлов).

## Locked Design Contract (03-UI-SPEC.md)

CONTEXT.md для фазы не создавался; роль locked-решений выполняет `03-UI-SPEC.md` — детальный дизайн-контракт с checker sign-off. Планировщик обязан следовать ему как источнику истины по: структуре presentation-слоя, Bloc-контракту (события/state/маппинг), токенам тем (`OkoTones`), спекам восьми виджетов, motion-таблице, доступности. Данный research уточняет **как** реализовать контракт технически и где контракт содержит реализационную ловушку (см. Common Pitfalls, Pitfall 1).

## Architectural Responsibility Map

Приложение одноэкранное, все слои — на клиенте (Flutter). «Тир» здесь означает слой Clean Architecture.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Статус-машина UI (5 статусов) | Presentation/Bloc | Domain (`VpnState` sealed) | Bloc мапит domain `VpnState` в UI `VpnStatus`, хранит производный state |
| Восстановление статуса (UI-07) | Presentation/Bloc | Data (`syncStatus` usecase) | `VpnStarted` дёргает `syncStatus()`; native — источник истины |
| Гейт двойного тапа (UI-02) | Presentation/Bloc | Presentation/Widget | Первичная защита: Bloc `isBusy`; вторичная: `onPressed: null` в кнопке |
| Таймер подключения (UI-04) | Presentation/Bloc (данные) | Presentation/Widget (тик) | `connectedSince` в state (переживает rebuild); `Timer.periodic` в виджете только рисует |
| Буфер логов + cap (UI-03) | Data (`LogRepositoryImpl` cap 500) | Presentation/Cubit | Репозиторий уже кольцевой буфер 500 + replay; Cubit аккумулирует и держит autoScroll-флаг |
| Автоскролл/пауза логов | Presentation/Widget | Presentation/Cubit | `ScrollController` + `NotificationListener` в виджете; флаг `autoScroll` в Cubit |
| Ирис-анимация (UI-06) | Presentation/Widget | — | `StatefulWidget` + `AnimationController` + `CustomPainter`; чистая презентация |
| Темы/токены (UI-06) | Core/Theme | Presentation/Widget | `OkoTones` `ThemeExtension` в `core/theme`; виджеты читают токены |
| Форматирование трафика (UI-05) | Presentation/Widget | — | Чистая функция байт → строка; входные данные из state |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_bloc | ^9.1.1 (в проекте) | State management, `BlocProvider`/`BlocBuilder`/`BlocListener` | Locked-решение пользователя; `on<Event>` API, `emit.onEach`/`emit.forEach`, internal-events [VERIFIED: Context7 /felangel/bloc] |
| bloc | ^9.x (транзитивно через flutter_bloc) | `Bloc`/`Cubit`/`Emitter` | Ядро; `Emitter.onEach`/`forEach` для стримов [CITED: docs.bloclibrary.dev] |
| equatable | ^2.1.0 (в проекте) | Value equality для state/событий | Уже используется в domain; state и события сравниваются по значению [VERIFIED: pubspec] |
| google_fonts | ^8.1.0 | Space Grotesk / Inter / JetBrains Mono | Официальный пакет Flutter team; бандлинг ассетов для офлайн [CITED: pub.dev/packages/google_fonts] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| bloc_test | ^10.0.0 | `blocTest(...)` для QA-02 | Dev-зависимость; совместим с bloc ^9.0.0 [CITED: pub.dev/packages/bloc_test] |
| mocktail | ^1.0.5 (в проекте) | Моки usecases в тестах Bloc | Без кодогена; уже в проекте [VERIFIED: pubspec] |
| flutter_test | SDK | Widget-тесты, golden (опц.) | В SDK; `pumpWidget`, `pump`, `matchesGoldenFile` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| google_fonts runtime-fetch | Ручное бандлинг .ttf в `fonts:` + `TextStyle(fontFamily:)` | Полный контроль/офлайн без пакета, но больше ручной работы и нет единого API. Рекомендация: google_fonts + бандлинг ассетов (лучшее из двух) |
| Ручной `CustomPainter` ириса | rive / lottie | Внешний ассет-пайплайн + новая зависимость; DESIGN явно требует один `CustomPainter`, никаких изображений |
| Ручной staggered-вход (`AnimationController` + `Interval`) | flutter_animate / flutter_staggered_animations | Экономит код, но новая зависимость; UI-SPEC допускает «flutter animate без пакета». Рекомендация: без пакета |
| Golden-тест ириса через `matchesGoldenFile` | golden_toolkit / alchemist | Встроенный `matchesGoldenFile` не требует зависимостей; golden опционален (UI-SPEC), CustomPainter труден для стабильного golden из-за анимации |

**Installation:**
```bash
flutter pub add google_fonts
flutter pub add --dev bloc_test
```

**Version verification:**
- `google_fonts` 8.1.0, опубликован ~2 месяца назад (май 2026) [CITED: pub.dev/packages/google_fonts]
- `bloc_test` 10.0.0, зависит от `bloc ^9.0.0` [CITED: pub.dev/packages/bloc_test]
- `flutter_bloc` 9.1.1, `equatable` 2.1.0, `mocktail` 1.0.5 уже в `pubspec.yaml` [VERIFIED: pubspec]
- Окружение: Flutter 3.44.5 stable, Dart 3.12.2 [VERIFIED: `flutter --version`]

## Package Legitimacy Audit

slopcheck установить не удалось (`pip install slopcheck` недоступен в окружении). Per protocol: новые пакеты помечены `[ASSUMED]`, планировщик обязан поставить `checkpoint:human-verify` перед `flutter pub add`. Существование и версии подтверждены на официальном pub.dev; оба пакета — от команд Flutter (google_fonts) и Bloc (bloc_test, автор felangel), риск slopsquat минимальный.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| google_fonts | pub.dev | ~зрелый (8.x) | very high (Flutter Favorite) | github.com/material-foundation/flutter-packages | unavailable | Approved (human-verify checkpoint) |
| bloc_test | pub.dev | зрелый (10.0.0) | very high | github.com/felangel/bloc | unavailable | Approved (human-verify checkpoint) |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none (slopcheck был недоступен; обе зависимости требуют лёгкого human-verify перед install)

## Architecture Patterns

### System Architecture Diagram

```
[Native VPN service (Android/iOS)]
        │ events: StatusChanged / LogMessage / TrafficChanged / VpnError
        ▼
[VpnBridge] ──demux──► statusEvents / logEvents / trafficEvents / errorEvents  (broadcast)
        │
        ▼
[Datasource] ──map DTO→entity──► states: Stream<VpnState> | traffic: Stream<TrafficStats> | logs: Stream<LogEntry>
        │
        ▼
[Repository]
  watchState():  single-sub stream, REPLAY последнего VpnState при подписке
  watchTraffic(): broadcast, БЕЗ replay
  watchLogs():   single-sub stream, REPLAY буфера (cap 500) при подписке
  syncStatus():  getStatus() снапшот → пушит VpnState в watchState-контроллер
        │  (через usecases: WatchVpnState / WatchTraffic / WatchLogs / ConnectVpn / DisconnectVpn / SyncStatus)
        ▼
┌─────────────────────────── Presentation ───────────────────────────┐
│ VpnConnectionBloc                          LogsCubit                │
│  VpnStarted → syncStatus() → subscribe      subscribe watchLogs()   │
│    watchVpnState().listen(add(StateRecv))    → append + cap + flag  │
│    watchTraffic().listen(add(TrafficRecv))                          │
│  Connect/DisconnectRequested (isBusy-гейт)                          │
│  state: VpnStatus, connectedSince, rx/tx, errorMessage             │
│         │ BlocBuilder / BlocSelector / BlocListener                 │
│         ▼                                                           │
│  VpnHomeScreen                                                      │
│   Wordmark │ StatusBadge │ IrisIndicator(+ConnectionTimer)         │
│   ServerCard │ TrafficPanel │ ConnectButton │ LogConsole           │
└────────────────────────────────────────────────────────────────────┘
```

Reader trace (primary use case «Connect»): тап `ConnectButton` → `add(ConnectRequested)` → гейт `isBusy` → `connectVpn(config)` → native стартует → `StatusChanged(connecting/connected)` приходит стримом → `.listen` → `add(VpnStateReceived)` → state пересчитан → `IrisIndicator` раскрывает зрачок + `ConnectionTimer` тикает от `connectedSince`.

### Recommended Project Structure

Точная структура задана UI-SPEC (следовать буквально). Добавления к дереву UI-SPEC:

```
lib/features/vpn_connection/domain/usecases/
  watch_traffic.dart          # НОВЫЙ usecase-обёртка над vpnRepository.watchTraffic()
lib/features/vpn_connection/presentation/bloc/  # vpn_connection_{bloc,event,state}.dart
lib/features/vpn_logs/presentation/bloc/        # logs_cubit.dart, logs_state.dart
test/features/vpn_connection/presentation/bloc/ # vpn_connection_bloc_test.dart (QA-02)
test/features/vpn_logs/presentation/bloc/       # logs_cubit_test.dart
test/features/vpn_connection/presentation/widgets/ # опц. widget-тесты кнопки/бейджа
```

`AppDependencies` (`di.dart`) нужно расширить: добавить `late final WatchTraffic watchTraffic` (сейчас есть метод `watchTraffic()`, но не usecase-объект) и передать демо-`VpnConfig` в Bloc. Демо-конфиг переезжает из `main.dart` в `di.dart` или прокидывается в `OkoApp`.

### Pattern 1: Bloc подписывается на два стрима через internal-events (РЕКОМЕНДУЕТСЯ)

**What:** В обработчике `VpnStarted` сначала `await syncStatus()` (UI-07), затем подписка на оба бесконечных стрима через `.listen((data) => add(internal))`; подписки хранятся полями и отменяются в `close()`.
**When to use:** Всегда для этой фазы. Обрабатывает N бесконечных стримов, не блокирует друг друга, чисто закрывается.
**Example:**
```dart
// Source: паттерн internal-events из docs.bloclibrary.dev/faqs (Context7 /felangel/bloc)
class VpnConnectionBloc extends Bloc<VpnConnectionEvent, VpnConnectionState> {
  VpnConnectionBloc({
    required WatchVpnState watchVpnState,
    required WatchTraffic watchTraffic,
    required ConnectVpn connectVpn,
    required DisconnectVpn disconnectVpn,
    required SyncStatus syncStatus,
    required VpnConfig config,
  })  : _watchVpnState = watchVpnState,
        _watchTraffic = watchTraffic,
        _connectVpn = connectVpn,
        _disconnectVpn = disconnectVpn,
        _syncStatus = syncStatus,
        _config = config,
        super(const VpnConnectionState(status: VpnStatus.disconnected)) {
    on<VpnStarted>(_onStarted);
    on<VpnStateReceived>(_onStateReceived);
    on<VpnTrafficReceived>(_onTrafficReceived);
    on<ConnectRequested>(_onConnectRequested);
    on<DisconnectRequested>(_onDisconnectRequested);
  }

  StreamSubscription<VpnState>? _stateSub;
  StreamSubscription<TrafficStats>? _trafficSub;

  Future<void> _onStarted(VpnStarted event, Emitter<VpnConnectionState> emit) async {
    await _syncStatus();                       // UI-07, до подписки → replay отдаст снапшот
    _stateSub = _watchVpnState().listen((s) => add(VpnStateReceived(s)));
    _trafficSub = _watchTraffic().listen((t) => add(VpnTrafficReceived(t)));
  }

  void _onStateReceived(VpnStateReceived event, Emitter<VpnConnectionState> emit) {
    emit(_mapState(event.state, state));        // маппинг domain→ui, обнуление connectedSince/errorMessage
  }

  void _onConnectRequested(ConnectRequested event, Emitter<VpnConnectionState> emit) {
    if (state.isBusy) return;                   // UI-02 гейт
    _connectVpn(_config);                        // fire-and-forget; статус придёт стримом
  }

  @override
  Future<void> close() {
    _stateSub?.cancel();
    _trafficSub?.cancel();
    return super.close();
  }
}
```
Важно: `_syncStatus()` в try/catch — при `Failure` эмитить `status: error` (native мог быть недоступен). `syncStatus()` пушит снапшот в контроллер `watchState`, а подписка идёт после `await`, поэтому replay отдаст синхронизированный статус первым событием.

### Pattern 2 (альтернатива): `emit.onEach` в отдельном обработчике на стрим

**What:** Каждый стрим получает свой обработчик-подписку с `emit.onEach`; событие `VpnStarted` добавляет два sub-события (`_StateSubRequested`, `_TrafficSubRequested`).
**When to use:** Если предпочтительнее держать эмиссию внутри `emit.onEach` (официальные туториалы Bloc используют его для одиночного стрима). Требует `transformer` или отдельных обработчиков, чтобы обе подписки жили параллельно.
```dart
// Source: docs.bloclibrary.dev (Context7 /felangel/bloc) — AppBloc emit.onEach
Future<void> _onStateSubRequested(_StateSubRequested e, Emitter<VpnConnectionState> emit) async {
  await emit.onEach<VpnState>(
    _watchVpnState(),
    onData: (s) => emit(_mapState(s, state)),
    onError: (err, st) => addError(err, st),
  );
}
```
Компромисс: два concurrent `emit.onEach` в разных обработчиках работают, но паттерн 1 короче и совпадает с уже объявленными в контракте internal-событиями.

### Pattern 3: State с ручным copyWith и производными геттерами

```dart
class VpnConnectionState extends Equatable {
  const VpnConnectionState({
    required this.status,
    this.connectedSince,
    this.rxBytes = 0,
    this.txBytes = 0,
    this.errorMessage,
  });

  final VpnStatus status;
  final DateTime? connectedSince;
  final int rxBytes;
  final int txBytes;
  final String? errorMessage;

  bool get isBusy =>
      status == VpnStatus.connecting || status == VpnStatus.disconnecting;

  VpnConnectionState copyWith({
    VpnStatus? status,
    DateTime? connectedSince,
    bool clearConnectedSince = false,   // паттерн обнуления nullable-поля через флаг
    int? rxBytes,
    int? txBytes,
    String? errorMessage,
    bool clearError = false,
  }) => VpnConnectionState(
        status: status ?? this.status,
        connectedSince:
            clearConnectedSince ? null : (connectedSince ?? this.connectedSince),
        rxBytes: rxBytes ?? this.rxBytes,
        txBytes: txBytes ?? this.txBytes,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );

  @override
  List<Object?> get props => [status, connectedSince, rxBytes, txBytes, errorMessage];
}
```
Ловушка copyWith с nullable: нельзя обнулить поле через `copyWith(connectedSince: null)` (не отличить от «не передано»). Нужны явные флаги `clearConnectedSince`/`clearError` — при переходе в не-Connected обнулить `connectedSince`, при выходе из Error обнулить `errorMessage` (UI-SPEC требование).

### Pattern 4: LogsCubit с cap и autoScroll-флагом

```dart
class LogsState extends Equatable {
  const LogsState({this.entries = const [], this.autoScroll = true});
  final List<LogEntry> entries;
  final bool autoScroll;
  // copyWith + props
}

class LogsCubit extends Cubit<LogsState> {
  LogsCubit({required WatchLogs watchLogs}) : super(const LogsState()) {
    _sub = watchLogs().listen(_append);   // репозиторий реплеит буфер (до 500) при подписке
  }
  static const _cap = 500;
  late final StreamSubscription<LogEntry> _sub;

  void _append(LogEntry entry) {
    final next = [...state.entries, entry];
    if (next.length > _cap) next.removeRange(0, next.length - _cap);
    emit(state.copyWith(entries: next));
  }

  void pauseAutoScroll() { if (state.autoScroll) emit(state.copyWith(autoScroll: false)); }
  void resumeAutoScroll() { if (!state.autoScroll) emit(state.copyWith(autoScroll: true)); }

  String plainText() => state.entries
      .map((e) => '${_hms(e.time)} [${e.level.name.toUpperCase()}] ${e.text}')
      .join('\n');

  @override
  Future<void> close() { _sub.cancel(); return super.close(); }
}
```
Примечание: репозиторий уже кэширует буфер cap 500 и реплеит его при подписке, поэтому на старте Cubit получит до 500 replay-событий подряд (по одному emit на запись). Для прототипа приемлемо; при желании оптимизировать — собрать первую пачку через `bufferTime`/накопление, но это усложняет без пользы.

### Pattern 5: ThemeExtension<OkoTones> с lerp

```dart
// Source: api.flutter.dev ThemeExtension
@immutable
class OkoTones extends ThemeExtension<OkoTones> {
  const OkoTones({
    required this.accentConnected,
    required this.accentTransitional,
    required this.accentError,
    required this.accentIdle,
    required this.glow,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color accentConnected, accentTransitional, accentError, accentIdle;
  final Color glow, surfaceCard, surfaceElevated, textPrimary, textSecondary;

  Color accentFor(VpnStatus status) => switch (status) {
        VpnStatus.connected => accentConnected,
        VpnStatus.connecting || VpnStatus.disconnecting => accentTransitional,
        VpnStatus.error => accentError,
        VpnStatus.disconnected => accentIdle,
      };

  @override
  OkoTones copyWith({Color? accentConnected, /* ... */}) => OkoTones(/* ... */);

  @override
  OkoTones lerp(ThemeExtension<OkoTones>? other, double t) {
    if (other is! OkoTones) return this;
    return OkoTones(
      accentConnected: Color.lerp(accentConnected, other.accentConnected, t)!,
      // ... Color.lerp для каждого поля
    );
  }

  static const dark = OkoTones(/* значения из UI-SPEC dark */);
  static const light = OkoTones(/* значения из UI-SPEC light */);
}
```
Регистрация в теме: `ThemeData(extensions: [OkoTones.dark])`. Доступ: `Theme.of(context).extension<OkoTones>()!`. `lerp` даёт плавный кроссфейд токенов при системном переключении темы. `accentFor` закрывает требование UI-SPEC «акцент через геттер, не через switch по хардкоду».

### Pattern 6: Iris CustomPainter + AnimationController + reduce-motion

```dart
class IrisIndicator extends StatefulWidget { const IrisIndicator({required this.status, super.key}); final VpnStatus status; ... }

class _IrisIndicatorState extends State<IrisIndicator> with TickerProviderStateMixin {
  late final AnimationController _segment;   // Connecting: сегмент по кольцу (1200ms linear loop)
  late final AnimationController _breath;    // дыхание кольца/glow
  late final AnimationController _pupil;     // Connected раскрыв (600ms easeOutBack, once)
  late final AnimationController _shake;     // Error shake (250ms)
  final _color = ColorTween();               // интерполяция цвета кольца 300ms

  @override
  void initState() {
    super.initState();
    _segment = AnimationController(vsync: this, duration: OkoMotion.segment);
    // ... init остальных
    _applyStatus(widget.status, animate: false);
  }

  @override
  void didUpdateWidget(covariant IrisIndicator old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status) _applyStatus(widget.status, animate: true);
  }

  void _applyStatus(VpnStatus s, {required bool animate}) {
    final reduce = MediaQuery.disableAnimationsOf(context);   // reduce-motion
    if (reduce) { _segment.stop(); _breath.stop(); /* статичный кадр */ return; }
    switch (s) {
      case VpnStatus.connecting: _segment.repeat(); _breath.repeat(reverse: true);
      case VpnStatus.connected:  _segment.stop(); _pupil.forward(from: 0); _breath.repeat(reverse: true);
      case VpnStatus.error:      _shake.forward(from: 0); HapticFeedback.heavyImpact();
      case _:                    _segment.stop(); _breath.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tones = Theme.of(context).extension<OkoTones>()!;
    return AnimatedBuilder(
      animation: Listenable.merge([_segment, _breath, _pupil, _shake]),
      builder: (_, __) => CustomPaint(
        painter: IrisPainter(
          status: widget.status,
          segment: _segment.value, breath: _breath.value,
          pupil: _pupil.value, shake: _shake.value,
          accent: tones.accentFor(widget.status), glow: tones.glow,
        ),
      ),
    );
  }

  @override
  void dispose() { _segment.dispose(); _breath.dispose(); _pupil.dispose(); _shake.dispose(); super.dispose(); }
}
```
`MediaQuery.disableAnimationsOf(context)` — эффективный аксессор (не перестраивает при других изменениях MediaQuery) [CITED: api.flutter.dev/MediaQuery/disableAnimationsOf]. `IrisPainter.shouldRepaint` возвращает `true` при изменении любого анимируемого значения (или использовать `CustomPaint(painter:, ...)` под `AnimatedBuilder`, как выше — тогда repaint управляется rebuild). Все контроллеры диспоузятся. Читать `MediaQuery` в `initState` нельзя (нет контекста-зависимости) — вызывать `_applyStatus` в `didChangeDependencies` или в `build`/`didUpdateWidget`.

### Pattern 7: ConnectionTimer (Timer.periodic от connectedSince)

```dart
class ConnectionTimer extends StatefulWidget { const ConnectionTimer({required this.connectedSince, super.key}); final DateTime? connectedSince; ... }

class _ConnectionTimerState extends State<ConnectionTimer> {
  Timer? _timer;
  @override void initState() { super.initState(); _restart(); }
  @override void didUpdateWidget(covariant ConnectionTimer old) {
    super.didUpdateWidget(old);
    if (old.connectedSince != widget.connectedSince) _restart();
  }
  void _restart() {
    _timer?.cancel();
    if (widget.connectedSince == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }
  @override void dispose() { _timer?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final since = widget.connectedSince;
    if (since == null) return const SizedBox.shrink();
    final d = DateTime.now().difference(since);
    return FittedBox(child: Text(_hhmmss(d), style: /* Space Grotesk 48/600 tabular */));
  }
}
```
Источник истины — `connectedSince` в Bloc-state, поэтому пересоздание виджета (rebuild экрана, смена темы) не сбрасывает таймер: он всегда пересчитывается от `connectedSince` (UI-04). Формат `HH:MM:SS` через zero-pad `Duration`. `FittedBox` защищает от Dynamic Type 200%.

### Pattern 8: LogConsole — DraggableScrollableSheet + автоскролл

```dart
DraggableScrollableSheet(
  initialChildSize: 0.12, minChildSize: 0.12, maxChildSize: 0.70,
  builder: (context, scrollController) {   // ВАЖНО: этот controller управляет и листом, и позицией
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        final atBottom = scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 24;
        if (!atBottom) context.read<LogsCubit>().pauseAutoScroll();
        else context.read<LogsCubit>().resumeAutoScroll();
        return false;
      },
      child: BlocConsumer<LogsCubit, LogsState>(
        listener: (context, s) {
          if (s.autoScroll && scrollController.hasClients) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (scrollController.hasClients) {
                scrollController.animateTo(
                  scrollController.position.maxScrollExtent,
                  duration: OkoMotion.autoscroll, curve: Curves.easeOut);
              }
            });
          }
        },
        builder: (context, s) => ListView.builder(
          controller: scrollController,   // тот самый sheet-controller
          itemCount: s.entries.length,
          itemBuilder: (_, i) => LogLine(entry: s.entries[i]),
        ),
      ),
    );
  },
)
```
Тонкость: `DraggableScrollableSheet` отдаёт свой `ScrollController`, который надо отдать `ListView` и использовать для `animateTo`. Свой отдельный контроллер заводить нельзя (конфликт). `animateTo` только после layout (`hasClients` + `addPostFrameCallback`), иначе `maxScrollExtent` недоступен.

### Anti-Patterns to Avoid
- **Два `emit.forEach` подряд в одном обработчике** (как буквально написано в UI-SPEC): второй никогда не стартует, трафик мёртв. См. Pitfall 1.
- **Хранить `Emitter` в поле и звать после завершения обработчика:** бросает `StateError`. Эмиссию из стрима делать через `emit.onEach`/`emit.forEach` (пока обработчик жив) или через `add(internalEvent)` (Pattern 1).
- **Хардкод `Color(0xFF...)` в виджетах:** запрещён UI-SPEC. Только `OkoTones`.
- **`CircularProgressIndicator`/спиннеры:** запрещены DESIGN; прогресс в переходных статусах — бегущий сегмент.
- **`setState` в виджетах для бизнес-логики:** запрещено CONVENTIONS. `setState` допустим только для локального тика анимации/таймера (ConnectionTimer, IrisIndicator), не для VPN-состояния.
- **Свой ScrollController поверх DraggableScrollableSheet:** конфликт контроллеров.
- **`textScaleFactor`:** устарел; в 3.44 использовать `MediaQuery.textScalerOf(context)` / `TextScaler`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Подписка Bloc на стрим + эмиссия | Ручной `StreamSubscription` + `emit` в поле | `emit.onEach`/`emit.forEach` или `.listen → add` | Ручной `emit` вне обработчика бросает `StateError`; фреймворк даёт lifecycle |
| Кроссфейд токенов темы | Ручная интерполяция цветов в build | `ThemeExtension.lerp` + `Color.lerp` | Flutter сам лерпит расширения при смене темы |
| Плавная анимация цвета кольца | Ручной таймер + setState | `ColorTween` на `AnimationController` / `AnimatedContainer` | Встроенные твины, curves, dispose из коробки |
| Загрузка шрифтов | Ручной `FontLoader` + сеть | `google_fonts` (+ бандлинг ассетов) | Кеш, лицензии, единый API |
| Тестирование Bloc-переходов | Ручной сбор `stream.toList()` + сравнение | `blocTest(build/act/expect/verify)` | Управляет lifecycle, `wait`, `seed`, `errors` |
| Форматирование Duration | Ручные конкатенации | `Duration` + zero-pad хелпер | Тривиально, но вынести в чистую функцию под unit-тест |
| Копирование в буфер | Платформенный канал | `Clipboard.setData(ClipboardData(text:))` | Встроено в `flutter/services` |
| Тактильная отдача | Платформенный канал | `HapticFeedback.mediumImpact()` и т.д. | Встроено в `flutter/services` |

**Key insight:** Почти всё в этой фазе — стандартные виджеты Flutter + Bloc-паттерны. Единственная кастомная графика — ирис (`CustomPainter`). Соблазн «сам подпишусь на стрим и буду звать emit» — главная ошибка: она ломается на lifecycle Bloc. Используйте документированные `emit.onEach`/internal-events.

## Common Pitfalls

### Pitfall 1: Двойной `emit.forEach` в `VpnStarted` (ловушка самого UI-SPEC)
**What goes wrong:** UI-SPEC описывает `VpnStarted` как «syncStatus(), затем `emit.forEach(watchVpnState())` и `emit.forEach(watchTraffic())`». Написанные последовательно, они не работают: `emit.forEach` возвращает Future, завершающийся только когда стрим закрыт. `watchVpnState()` бесконечен, поэтому первый `await emit.forEach` висит вечно, а `emit.forEach(watchTraffic())` не выполняется. Трафик (UI-05) не обновляется.
**Why it happens:** `emit.forEach`/`onEach` семантически = «пока стрим жив, эмить»; на два бесконечных стрима в одном обработчике не рассчитан.
**How to avoid:** Pattern 1 (`.listen → add(internal)` для обоих стримов, `syncStatus` до подписки) ИЛИ Pattern 2 (два отдельных обработчика, каждый со своим `emit.onEach`). Не смешивать.
**Warning signs:** Статус меняется, но плитки трафика всегда 0; либо наоборот, если поменять порядок.

### Pitfall 2: `Emitter` использован после завершения обработчика
**What goes wrong:** `Bad state: Cannot emit new states after calling super.close` или `Emitter is no longer active`.
**Why it happens:** Сохранили `emit` в поле и вызвали из колбэка стрима вне жизни обработчика.
**How to avoid:** Эмитить только внутри активного обработчика (`emit.onEach` держит обработчик живым) или через `add(internalEvent)` → эмиссия в обработчике этого события.
**Warning signs:** Исключение при первом же событии стрима после старта.

### Pitfall 3: AnimationController не диспоузится / читает MediaQuery в initState
**What goes wrong:** Утечка тикера, лог `AnimationController was disposed with an active ticker` или `dependOnInheritedWidgetOfExactType in initState`.
**Why it happens:** Забыли `dispose()`; или прочитали `MediaQuery.of(context)` в `initState` (контекст ещё без зависимостей).
**How to avoid:** `TickerProviderStateMixin`, диспоуз всех контроллеров; чтение `MediaQuery.disableAnimationsOf` в `didChangeDependencies`/`build`/`didUpdateWidget`.
**Warning signs:** Красные ошибки в консоли при уходе с экрана или на старте.

### Pitfall 4: Таймер сбрасывается при rebuild
**What goes wrong:** Таймер прыгает на 00:00:00 при смене темы/перестройке экрана.
**Why it happens:** Отсчёт хранится в локальном стейте виджета, а не в `connectedSince`.
**How to avoid:** Всегда считать `DateTime.now().difference(connectedSince)`; `connectedSince` — в Bloc-state. `didUpdateWidget` перезапускает `Timer` только при смене `connectedSince` (UI-04).
**Warning signs:** Таймер обнуляется при повороте/смене темы/скролле логов.

### Pitfall 5: google_fonts падает офлайн при первом запуске
**What goes wrong:** На устройстве/эмуляторе без сети шрифты не грузятся, текст в дефолтном шрифте (или исключение в логах).
**Why it happens:** По умолчанию google_fonts тянет .ttf по HTTP и кеширует; первый запуск требует сети.
**How to avoid:** Скачать нужные начертания с fonts.google.com, положить в папку `google_fonts/`, объявить `assets: - google_fonts/` в `pubspec.yaml`. Пакет приоритизирует бандл над сетью [CITED: pub.dev/packages/google_fonts]. Плюс зарегистрировать лицензии OFL в `LicenseRegistry`.
**Warning signs:** Демо-видео на эмуляторе без сети показывает дефолтный Roboto вместо Space Grotesk.

### Pitfall 6: `animateTo` до layout логов
**What goes wrong:** `ScrollController not attached to any scroll views` / `position` недоступна.
**Why it happens:** Автоскролл вызван до того, как список получил размеры (`maxScrollExtent` неизвестен).
**How to avoid:** `scrollController.hasClients` + `WidgetsBinding.instance.addPostFrameCallback` перед `animateTo`.
**Warning signs:** Исключение при первом логе или пустом списке.

### Pitfall 7: shouldRepaint возвращает false при анимации
**What goes wrong:** Ирис «замерзает», сегмент не бежит.
**Why it happens:** `CustomPainter.shouldRepaint` сравнивает не те поля / возвращает `false`, а `CustomPaint` не подписан на контроллер.
**How to avoid:** Либо оборачивать `CustomPaint` в `AnimatedBuilder(animation: controller)`, либо передать `CustomPaint(painter:, ...)` с `shouldRepaint`, сравнивающим все анимируемые значения (или `repaint: controller` в конструкторе painter).
**Warning signs:** Статичный ирис в статусах connecting/connected.

### Pitfall 8: Гонка replay при подписке после syncStatus
**What goes wrong:** UI кратко мигает `disconnected` перед восстановленным статусом, либо восстановленный статус теряется.
**Why it happens:** Порядок `syncStatus()` vs подписки. `watchState()` реплеит `_last` при подписке; `syncStatus()` обновляет `_last`.
**How to avoid:** `await syncStatus()` до `.listen(...)`. Тогда `_last` уже синхронизирован, и первое replay-событие — верный статус. Начальный state Bloc `disconnected` до первого события корректен.
**Warning signs:** На холодном старте при активном туннеле экран стартует в Disconnected и переключается с задержкой.

## Code Examples

### Форматирование байт (UI-05)
```dart
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  if (bytes < 1024) return '$bytes ${units[0]}';
  var value = bytes.toDouble();
  var i = 0;
  while (value >= 1024 && i < units.length - 1) { value /= 1024; i++; }
  return '${value.toStringAsFixed(1)} ${units[i]}';   // 12.4 MB, 812 B
}
```

### Форматирование таймера HH:MM:SS (UI-04)
```dart
String hhmmss(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return '${two(h)}:${two(m)}:${two(s)}';
}
```

### Tabular figures в TextTheme (google_fonts)
```dart
// Source: pub.dev/packages/google_fonts + api.flutter.dev FontFeature
TextStyle timerStyle(BuildContext c) => GoogleFonts.spaceGrotesk(
  fontSize: 48, height: 1.0, fontWeight: FontWeight.w600,
  fontFeatures: const [FontFeature.tabularFigures()],   // цифры не дёргаются
);
TextTheme okoTextTheme(Brightness b) => TextTheme(
  displayLarge: GoogleFonts.spaceGrotesk(fontSize: 48, fontWeight: FontWeight.w600),
  titleMedium:  GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w600),
  bodyMedium:   GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400),
  labelSmall:   GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
  // Mono (логи): GoogleFonts.jetBrainsMono(fontSize: 12)
);
```

### MultiBlocProvider в app.dart (замена harness)
```dart
class OkoApp extends StatelessWidget {
  const OkoApp({required this.dependencies, super.key});
  final AppDependencies dependencies;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Oko VPN',
    theme: OkoTheme.light, darkTheme: OkoTheme.dark, themeMode: ThemeMode.system,
    home: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => VpnConnectionBloc(
          watchVpnState: dependencies.watchVpnState,
          watchTraffic: dependencies.watchTraffic,   // usecase, добавить в di
          connectVpn: dependencies.connectVpn,
          disconnectVpn: dependencies.disconnectVpn,
          syncStatus: dependencies.syncStatus,
          config: dependencies.demoConfig,
        )..add(const VpnStarted())),                  // событие один раз при create
        BlocProvider(create: (_) => LogsCubit(watchLogs: dependencies.watchLogs)),
      ],
      child: const VpnHomeScreen(),
    ),
  );
}
```
`..add(VpnStarted())` в `create` (не в `build` виджета) гарантирует единственный вызов `syncStatus()` (QA-02 сценарий 6). `syncStatus()` уходит из `main.dart` в Bloc (UI-07).

### blocTest для QA-02 (6 сценариев UI-SPEC)
```dart
// Source: pub.dev/packages/bloc_test (blocTest signature) + mocktail
class _MockConnect extends Mock implements ConnectVpn {}
// аналогично для остальных usecases; watchVpnState/watchTraffic возвращают Stream

blocTest<VpnConnectionBloc, VpnConnectionState>(
  'disconnected -> connecting -> connected, connectedSince на Connected',
  setUp: () {
    when(() => syncStatus()).thenAnswer((_) async {});
    when(() => watchTraffic()).thenAnswer((_) => const Stream.empty());
    when(() => watchVpnState()).thenAnswer((_) => Stream.fromIterable([
      const VpnConnecting(),
      VpnConnected(connectedSince: DateTime(2026)),
    ]));
  },
  build: () => makeBloc(),
  act: (b) => b.add(const VpnStarted()),
  expect: () => [
    isA<VpnConnectionState>().having((s) => s.status, 'status', VpnStatus.connecting),
    isA<VpnConnectionState>()
      .having((s) => s.status, 'status', VpnStatus.connected)
      .having((s) => s.connectedSince, 'connectedSince', DateTime(2026)),
  ],
);

blocTest<VpnConnectionBloc, VpnConnectionState>(
  'onRevoke: VpnDisconnected из стрима без DisconnectRequested; disconnectVpn НЕ вызван',
  setUp: () { /* стрим эмитит VpnConnected затем VpnDisconnected */ },
  build: () => makeBloc(),
  act: (b) => b.add(const VpnStarted()),
  verify: (_) => verifyNever(() => disconnectVpn()),
);

blocTest<VpnConnectionBloc, VpnConnectionState>(
  'double-tap guard: два ConnectRequested в connecting → connectVpn 0 раз',
  seed: () => const VpnConnectionState(status: VpnStatus.connecting),
  build: () => makeBloc(),
  act: (b) => b..add(const ConnectRequested())..add(const ConnectRequested()),
  verify: (_) => verifyNever(() => connectVpn(any())),
);
```
Остальные три сценария (error-маппинг, connected→disconnecting→disconnected по DisconnectRequested, syncStatus вызван ровно раз) строятся аналогично через `expect`/`verify`. Для стримов, живущих дольше `act`, использовать `wait: Duration(...)` или `StreamController`, который тест закрывает в конце.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `mapEventToState` + `yield` (bloc 7-) | `on<Event>(handler)` + `emit` | bloc 8.0 | Весь Bloc на `on<Event>`; `mapEventToState` удалён |
| Ручной `StreamSubscription` в Bloc | `emit.onEach` / `emit.forEach` | bloc 8.0 | Lifecycle-safe эмиссия из стрима |
| `MediaQuery.of(context).textScaleFactor` | `MediaQuery.textScalerOf(context)` (`TextScaler`) | Flutter 3.16 | `textScaleFactor` deprecated |
| `MediaQuery.of(context).disableAnimations` | `MediaQuery.disableAnimationsOf(context)` | Flutter 3.x | Точечная подписка, меньше rebuild'ов |
| `ThemeData` кастомных цветов через subclass | `ThemeExtension<T>` + `lerp` | Flutter 3.0 | Типобезопасные токены + плавный кроссфейд |

**Deprecated/outdated:**
- `textScaleFactor` (числовой) → `TextScaler`.
- `bloc` `Transition`/`mapEventToState` синтаксис → `on<Event>`.
- `RaisedButton`/`FlatButton` → `FilledButton`/`OutlinedButton`/`TextButton` (Material 3).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `google_fonts` ^8.1.0 — актуальная версия и офлайн-бандлинг через папку `google_fonts/` работает как описано | Standard Stack, Pitfall 5 | Если API бандлинга изменился, офлайн-демо покажет дефолтный шрифт; проверить README при установке (slopcheck был недоступен) |
| A2 | `bloc_test` ^10.0.0 совместим с bloc 9.x проекта | Supporting | Если несовместим, тесты не соберутся; резолвится `flutter pub add --dev bloc_test` (pub сам подберёт версию) |
| A3 | Демо-`VpnConfig` можно перенести из `main.dart` в `di.dart`/`AppDependencies` без нарушения locked-решения «зашитый демо-конфиг» | Structure, Code Examples | Низкий: решение касается наличия конфига в коде, а не его местоположения |
| A4 | Снапшот `syncStatus` (rxBytes/txBytes) не пробрасывается в UI-трафик; rx/tx восстанавливаются в течение ~1с первым `trafficChanged` | Open Questions | Низкий: на холодном старте при активном туннеле плитки ~1с показывают 0. Приемлемо для прототипа; при желании расширить снапшот-маппинг |
| A5 | slopcheck-верификация google_fonts/bloc_test пропущена (инструмент недоступен) | Package Legitimacy Audit | Оба — официальные пакеты; риск минимальный, но планировщик ставит human-verify checkpoint |

## Open Questions

1. **Восстановление rx/tx на холодном старте (UI-07 vs UI-05)**
   - Что известно: `syncStatus()` мапит снапшот в `VpnState`, который несёт только `connectedSince`. Снапшот имеет `rxBytes`/`txBytes`, но они не доходят до UI (маппер их роняет).
   - Что неясно: нужно ли показывать накопленный трафик сразу при восстановлении, или достаточно дождаться следующего `trafficChanged` (раз в секунду при Connected).
   - Рекомендация: для прототипа достаточно дождаться `trafficChanged` (~1с). Если критично — расширить `VpnState`/маппинг снапшота или сидировать rx/tx в Bloc из снапшота. Планировщику: не блокер, отметить как nice-to-have.

2. **Golden-тест ириса (QA-02 упоминает «опционально»)**
   - Что известно: встроенный `matchesGoldenFile` не требует зависимостей; анимированный `CustomPainter` даёт нестабильные golden (зависят от кадра).
   - Что неясно: стоит ли тратить бюджет 48ч на golden при риске флейков.
   - Рекомендация: golden только для статичных кадров (disconnected/connected при `disableAnimations`) через `pumpWidget` с фиксированным `MediaQuery(disableAnimations: true)`; иначе пропустить. Приоритет — bloc_test (обязательно) и widget-тесты кнопки/бейджа.

3. **`WatchTraffic` usecase vs метод `AppDependencies.watchTraffic()`**
   - Что известно: сейчас в `di.dart` есть метод `watchTraffic()`, но нет объекта-usecase (в отличие от `WatchVpnState`).
   - Рекомендация: завести `WatchTraffic` usecase (симметрия с остальными, чистая инъекция в Bloc). UI-SPEC это прямо предлагает.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | вся фаза | ✓ | 3.44.5 stable | — |
| Dart SDK | вся фаза | ✓ | 3.12.2 | — |
| google_fonts (pub) | шрифты (UI-06) | ✗ (не установлен) | целевая ^8.1.0 | Бандлинг .ttf ассетами; при офлайн — обязательно |
| bloc_test (pub) | QA-02 | ✗ (не установлен) | целевая ^10.0.0 | `flutter test` + ручной сбор стрима (хуже) |
| Сеть (fonts.google.com) | первый рантайм-fetch шрифтов | зависит от устройства | — | Бандлинг ассетов (Pitfall 5) снимает зависимость |
| Устройство/эмулятор Android | визуальная проверка ирис/haptics/тем | не проверялось здесь | — | Golden-тесты частично; финальная проверка на устройстве |

**Missing dependencies with no fallback:** нет (обе pub-зависимости ставятся `flutter pub add`).
**Missing dependencies with fallback:** сеть для google_fonts → бандлинг ассетов.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) + bloc_test ^10.0.0 + mocktail ^1.0.5 |
| Config file | `analysis_options.yaml` (very_good_analysis 10.3.0); тест-конфига нет (дефолт flutter_test) |
| Quick run command | `flutter test test/features/vpn_connection/presentation/bloc/vpn_connection_bloc_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| QA-02 / UI-01 | disconnected→connecting→connected, connectedSince | unit (bloc) | `flutter test .../vpn_connection_bloc_test.dart` | ❌ Wave 0 |
| QA-02 / UI-02 | double-tap guard: ConnectRequested×2 в connecting → connectVpn 0 | unit (bloc) | `flutter test .../vpn_connection_bloc_test.dart` | ❌ Wave 0 |
| QA-02 | any→error: VpnError('msg') → status error, errorMessage='msg' | unit (bloc) | `flutter test .../vpn_connection_bloc_test.dart` | ❌ Wave 0 |
| QA-02 | onRevoke: VpnDisconnected из стрима, disconnectVpn НЕ вызван | unit (bloc) | `flutter test .../vpn_connection_bloc_test.dart` | ❌ Wave 0 |
| UI-07 | syncStatus вызван ровно раз на VpnStarted | unit (bloc) | `flutter test .../vpn_connection_bloc_test.dart` | ❌ Wave 0 |
| UI-03 | LogsCubit: append + cap 500 + pause/resume autoScroll | unit (cubit) | `flutter test .../logs_cubit_test.dart` | ❌ Wave 0 |
| UI-08 | plainText() форматирует `HH:mm:ss [LEVEL] text` | unit (cubit) | `flutter test .../logs_cubit_test.dart` | ❌ Wave 0 |
| UI-05 | formatBytes: 812 B / 12.4 MB / границы 1024 | unit (pure) | `flutter test .../format_bytes_test.dart` | ❌ Wave 0 |
| UI-04 | hhmmss: zero-pad, часы >0 | unit (pure) | `flutter test .../timer_format_test.dart` | ❌ Wave 0 |
| UI-02 | ConnectButton onPressed==null в connecting/disconnecting | widget | `flutter test .../connect_button_test.dart` | ❌ Wave 0 (опц.) |
| UI-01 | StatusBadge показывает слово статуса | widget | `flutter test .../status_badge_test.dart` | ❌ Wave 0 (опц.) |
| UI-06 | Iris статичный кадр при disableAnimations | golden (опц.) | `flutter test --update-goldens` | ❌ опционально |

### Sampling Rate
- **Per task commit:** `flutter analyze` + целевой тест-файл задачи (`flutter test <file>`).
- **Per wave merge:** `flutter test` (весь набор).
- **Phase gate:** `flutter analyze` без варнингов + `flutter test` зелёный до `/gsd:verify-work`; визуальная проверка обеих тем и пяти статусов на устройстве/эмуляторе.

### Wave 0 Gaps
- [ ] `test/features/vpn_connection/presentation/bloc/vpn_connection_bloc_test.dart` — QA-02, UI-01, UI-02, UI-07
- [ ] `test/features/vpn_logs/presentation/bloc/logs_cubit_test.dart` — UI-03, UI-08
- [ ] `test/features/vpn_connection/presentation/format_bytes_test.dart` — UI-05 (чистая функция)
- [ ] `test/features/vpn_connection/presentation/timer_format_test.dart` — UI-04 (чистая функция)
- [ ] `flutter pub add --dev bloc_test` — фреймворк для bloc-тестов (после human-verify)
- [ ] Тест-хелперы: моки usecases (`_MockConnectVpn` и т.д.) или fake-usecases по образцу `test/helpers/`
- [ ] (опц.) widget-тесты `connect_button_test.dart`, `status_badge_test.dart`

## Security Domain

`security_enforcement` в `.planning/config.json` не задан явно (по умолчанию enabled). Фаза — клиентский Flutter UI без сети/аутентификации/крипто/приёма недоверенного ввода. Большинство категорий ASVS неприменимо.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | В фазе нет аутентификации |
| V3 Session Management | no | Нет сессий/токенов |
| V4 Access Control | no | Один экран, нет ролей |
| V5 Input Validation | minimal | Пользовательский ввод в фазе отсутствует; логи приходят из собственного native-сервиса (не из внешней сети). `Text` в Flutter не интерпретирует разметку → нет инъекции |
| V6 Cryptography | no | Крипто в фазе нет (VLESS/ключи — Phase 4) |
| V7 Error Handling / Logging | yes | Логи не должны утекать секреты; `VpnConfig.userId` уже не логируется native-слоем (решение 02-03). UI показывает логи как есть — не добавлять в них токены/UUID |

### Known Threat Patterns for Flutter UI
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Утечка чувствительных данных в логи/буфер обмена | Information Disclosure | Не логировать `userId`/секреты; copy-all копирует только видимые строки логов (не конфиг) |
| Отображение непроверенной строки ошибки | Tampering/Info Disclosure | `VpnError.message` — из собственного native; показывать как текст, `Text` не исполняет разметку |

## Sources

### Primary (HIGH confidence)
- Context7 `/felangel/bloc` — `emit.onEach`/`emit.forEach`, internal-events (`.listen → add`), `on<Event>` handler, `close()` cleanup
- api.flutter.dev — `ThemeExtension<T>`/`lerp`, `MediaQuery.disableAnimationsOf`, `CustomPainter`/`AnimationController`, `FontFeature.tabularFigures`, `Clipboard`/`HapticFeedback`
- Кодовая база проекта — репозитории (`watchState` replay, `watchTraffic` broadcast, `watchLogs` буфер 500), usecases, `AppDependencies`, существующие тесты и хелперы
- `flutter --version` — Flutter 3.44.5, Dart 3.12.2

### Secondary (MEDIUM confidence)
- pub.dev/packages/google_fonts — версия 8.1.0, офлайн-бандлинг через папку `google_fonts/`, лицензии OFL
- pub.dev/packages/bloc_test — версия 10.0.0, сигнатура `blocTest`, зависимость `bloc ^9.0.0`
- `.planning/research/STACK.md`, `03-UI-SPEC.md`, `DESIGN.md`, `CONVENTIONS.md` — locked-решения и контракт

### Tertiary (LOW confidence)
- slopcheck-верификация недоступна (инструмент не установился) — обе новые pub-зависимости требуют human-verify перед install

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — версии подтверждены на pub.dev + `flutter --version`; flutter_bloc/equatable/mocktail уже в проекте
- Architecture (Bloc-стрим паттерн): HIGH — подтверждён Context7 официальными доками Bloc; ловушка двойного `emit.forEach` выведена из семантики API
- Pitfalls: HIGH для Bloc/анимации/таймера (framework-поведение); MEDIUM для google_fonts офлайн (README, не проверено на устройстве)
- Тесты: HIGH — bloc_test сигнатура подтверждена; сценарии заданы UI-SPEC

**Research date:** 2026-07-14
**Valid until:** 2026-08-13 (стабильный стек; проверить версии google_fonts/bloc_test при установке)
