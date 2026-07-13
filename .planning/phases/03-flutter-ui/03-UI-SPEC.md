---
phase: 3
slug: flutter-ui
status: draft
shadcn_initialized: false
preset: none
created: 2026-07-14
---

# Phase 3 — UI Design Contract (Flutter)

> Визуальный и интеракционный контракт экрана Oko VPN. Источник концепции: `.planning/DESIGN.md`. Здесь она развёрнута в исполнимые токены и спеки виджетов для планировщика и исполнителя. Идентификаторы и код английский, прозаические пояснения русские.

Проект Flutter, не web. shadcn/`components.json` не применимы. Дизайн-система строится на Material 3 с явным `ColorScheme` (не `fromSeed`) и кастомным `ThemeExtension` (`OkoTones`). Единственная кастомная графика фазы — ирис-индикатор (`CustomPainter`).

Контракт покрывает: структуру presentation-слоя, Bloc-контракт, темы и токены, спеки восьми виджетов, motion, состояния кнопки, доступность. UI строится поверх уже существующих domain-репозиториев (`watchState` / `watchTraffic` / `watchLogs`, `connect` / `disconnect` / `syncStatus`), их менять не нужно.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (Flutter Material 3, `useMaterial3: true`, явный `ColorScheme`, не `fromSeed`) |
| Preset | not applicable |
| Component library | Material 3 стилизованные виджеты + один `CustomPainter` (iris) |
| Icon library | Material Symbols rounded через встроенный `Icons.*_rounded` (ноль новых зависимостей, репозиторий остаётся лёгким). `lucide_icons` только если конкретного глифа нет |
| Font | `google_fonts`: Space Grotesk (display/цифры), Inter (body/подписи), JetBrains Mono (логи) |
| Theme delivery | `ThemeExtension<OkoTones>` в `lib/core/theme/oko_tones.dart`; виджеты читают токены через `Theme.of(context).extension<OkoTones>()!`, хардкод цветов в виджетах запрещён |
| Theme mode | `MaterialApp(theme: OkoTheme.light, darkTheme: OkoTheme.dark, themeMode: ThemeMode.system)` — обе темы обязательны; тёмная сигнатурная |

Новые зависимости для фазы (исполнитель добавляет в `pubspec.yaml`): `google_fonts`. Остальное (flutter_bloc 9.1.1, equatable, mocktail) уже в проекте.

---

## Presentation-слой: структура файлов

Presentation дополняет уже собранные domain и data слои. Bloc подписывается на стримы репозиториев через usecases из `AppDependencies` (`di.dart`), виджеты держат только `BlocBuilder` / `BlocListener` и разметку.

```
lib/core/theme/
  oko_tones.dart          # ThemeExtension<OkoTones>: все цветовые токены + glow
  oko_theme.dart          # OkoTheme.dark / OkoTheme.light -> ThemeData
  oko_typography.dart     # TextTheme на google_fonts (Space Grotesk / Inter / JetBrains Mono)
  oko_motion.dart         # длительности и кривые как const (единый источник motion)

lib/app/
  app.dart                # OkoApp: MaterialApp с обеими темами + MultiBlocProvider
  di.dart                 # существует; presentation берёт usecases отсюда

lib/features/vpn_connection/presentation/
  bloc/
    vpn_connection_bloc.dart
    vpn_connection_event.dart
    vpn_connection_state.dart
  screens/
    vpn_home_screen.dart
  widgets/
    oko_wordmark.dart         # логотип-слово oko
    status_badge.dart         # текстовый бейдж статуса
    iris_indicator.dart       # публичный виджет + AnimationController
    iris_painter.dart         # CustomPainter геометрии ириса
    connection_timer.dart     # тикающий таймер от connectedSince
    server_card.dart          # карточка сервера
    traffic_panel.dart        # ряд из двух плиток
    traffic_tile.dart         # одна плитка rx или tx
    connect_button.dart       # Connect / Disconnect с блокировкой

lib/features/vpn_logs/presentation/
  bloc/
    logs_cubit.dart
    logs_state.dart
  widgets/
    log_console.dart          # DraggableScrollableSheet + автоскролл + copy-all
    log_line.dart             # одна строка лога с цветом уровня
```

`main.dart` заменяет `DebugHarness` на `OkoApp(dependencies: AppDependencies())`. Вызов `syncStatus()` переезжает из `main` в `VpnConnectionBloc` (событие `VpnStarted`), чтобы восстановление статуса (UI-07) жило в бизнес-логике, а не в точке входа.

---

## Bloc-контракт

### VpnConnectionBloc

Инъекция (конструктор): `WatchVpnState watchVpnState`, `WatchTraffic watchTraffic` (обёртка над `vpnRepository.watchTraffic()`; сейчас доступна как `AppDependencies.watchTraffic()`, для чистоты завести usecase `WatchTraffic`), `ConnectVpn connectVpn`, `DisconnectVpn disconnectVpn`, `SyncStatus syncStatus`, `VpnConfig config` (демо-конфиг из `main`, в Phase 4 заменяется VLESS).

**Events** (`vpn_connection_event.dart`, sealed):

| Event | Триггер | Действие |
|-------|---------|----------|
| `VpnStarted` | `..add(VpnStarted())` при создании Bloc | `syncStatus()` (UI-07), затем `emit.forEach(watchVpnState())` и `emit.forEach(watchTraffic())` |
| `VpnStateReceived(VpnState state)` | внутреннее, из стрима | пересчитать `VpnConnectionState` |
| `VpnTrafficReceived(TrafficStats stats)` | внутреннее, из стрима | обновить rx/tx в state |
| `ConnectRequested` | тап кнопки в Disconnected/Error | гейт: `if (state.isBusy) return;` затем `connectVpn(config)` |
| `DisconnectRequested` | тап кнопки в Connected | гейт `isBusy`, затем `disconnectVpn()` |

**State** (`vpn_connection_state.dart`, один класс `VpnConnectionState extends Equatable`):

| Поле | Тип | Назначение |
|------|-----|-----------|
| `status` | `VpnStatus` (enum: `disconnected`, `connecting`, `connected`, `disconnecting`, `error`) | ведёт ирис, бейдж, кнопку |
| `connectedSince` | `DateTime?` | источник истины таймера (UI-04), переживает пересоздание виджета |
| `rxBytes` / `txBytes` | `int` | плитки трафика (UI-05) |
| `errorMessage` | `String?` | текст ошибки из `VpnError.message` |

Производные геттеры (без хранения): `isBusy => status == connecting || status == disconnecting` (блокировка кнопки, UI-02); `primaryAction => connected ? disconnect : (transitional ? none : connect)`.

Маппинг `VpnState` (domain) → `VpnStatus` (ui): прямой один-к-одному, `VpnConnected.connectedSince` пробрасывается в `connectedSince`, `VpnError.message` в `errorMessage`. При переходе в не-Connected `connectedSince` обнуляется, при переходе из Error в любой другой статус `errorMessage` обнуляется.

Начальное состояние: `VpnConnectionState(status: disconnected)` до первого события стрима (replay репозитория отдаст актуальный статус сразу после подписки).

### LogsCubit

Инъекция: `WatchLogs watchLogs`. При создании подписывается на `watchLogs()`.

**State** (`LogsState extends Equatable`): `List<LogEntry> entries` (кольцевой буфер, cap **500**, при переполнении дропается самый старый), `bool autoScroll` (по умолчанию `true`).

Методы: приём новой записи (append в конец, обрезка головы при cap); `pauseAutoScroll()` / `resumeAutoScroll()` (управляется скролл-нотификациями в `LogConsole`); `String plainText()` для copy-all (форматирует все записи как `HH:mm:ss [LEVEL] text`).

### QA-02: unit-тесты Bloc (обязательны, `bloc_test` через flutter_test + mocktail)

Покрыть переходы и гейты (мокать usecases mocktail):

1. `disconnected -> connecting -> connected`: стрим эмитит три `VpnState`, Bloc даёт три `VpnConnectionState` с верным `status` и `connectedSince` на Connected.
2. `connected -> disconnecting -> disconnected` по `DisconnectRequested`: `disconnectVpn` вызван один раз, `connectedSince` обнулён.
3. `any -> error`: `VpnError('msg')` даёт `status: error`, `errorMessage: 'msg'`.
4. **onRevoke-сценарий**: находясь в `connected`, стрим приносит `VpnDisconnected` без пользовательского `DisconnectRequested` (системный отзыв); Bloc переходит в `disconnected`, `disconnectVpn` НЕ вызывался.
5. **double-tap guard**: два `ConnectRequested` подряд в `connecting` вызывают `connectVpn` ноль раз (гейт `isBusy`); аналогично `DisconnectRequested` в `disconnecting`.
6. `syncStatus` вызван ровно один раз на `VpnStarted`.

---

## Spacing Scale

Сетка кратна 8 (DESIGN). Токены в `EdgeInsets`/`SizedBox`, не магические числа.

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | зазоры иконка-текст, внутренний inline-паддинг бейджа |
| sm | 8px | компактные зазоры внутри плиток, между иконкой и лейблом трафика |
| md | 16px | базовый паддинг экрана по горизонтали, между блоками карточка/трафик |
| lg | 24px | вертикальные разрывы секций, внутренний паддинг карточки сервера |
| xl | 32px | отступ вокруг ириса от соседних блоков |
| 2xl | 48px | крупные разрывы (верхняя safe-зона под AppBar-зоной) |
| 3xl | 64px | резерв, page-level |

Corner radius (отдельная шкала): badge/pill `999`, button/tile `16`, card `20`, log sheet top `24`.

Исключения (фиксированные размеры компонентов, не spacing-токены): высота кнопки Connect `56`; минимальный touch target `48` (иконки copy, chevron); высота плитки трафика `72`; grabber панели логов `4x36`; толщина кольца ириса `min 3` / `max 8` px. Все интерактивные цели ≥48dp. Safe areas через `SafeArea` обязательны (edge-to-edge на Android).

---

## Typography

`google_fonts`, собрано в `oko_typography.dart` как `TextTheme`. Ровно 4 различных кегля (48 / 20 / 15 / 12) и ровно 2 начертания (regular 400, semibold 600). Табличные цифры (`FontFeature.tabularFigures()`) на таймере и трафике, чтобы значения не дёргались.

| Role | Family | Size | Weight | Line Height | Где |
|------|--------|------|--------|-------------|-----|
| Display / Timer | Space Grotesk | 48 (таймер), центр ириса | 600 | 1.0 | таймер `00:00:00` в Connected, крупные числа |
| Title | Space Grotesk | 20 | 600 | 1.2 | wordmark `oko`, заголовки блоков (`Logs`) |
| Body | Inter | 15 | 400 | 1.5 | имя/адрес сервера, подписи трафика, текст ошибки |
| Label | Inter | 12 | 600 | 1.2 | текст бейджа статуса, лейблы `down`/`up` (uppercase, letter-spacing 0.5) |
| Caption | Inter | 12 | 400 | 1.4 | вторичные подписи (время лога) |
| Mono | JetBrains Mono | 12 | 400 | 1.4 | строки логов; уровень маркируется цветом, не начертанием |

Крупные числа трафика (значение плитки) используют Space Grotesk 20 semibold tabular; единица (KB/MB) Inter 12 regular secondary. `FittedBox` на таймере, чтобы Dynamic Type до 200% не ломал вёрстку.

---

## Color

60/30/10 из DESIGN. Значения дублируются в `OkoTones` для dark и light. Виджеты берут акцент состояния через геттер `OkoTones.accentFor(VpnStatus)`, не через switch по хардкоду.

### Тёмная тема (сигнатурная)

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `#0B0F14` | фон экрана (void), поверх радиальный glow состояния |
| Secondary (30%) | `#121821` card / `#1A2230` elevated | карточка сервера, плитки трафика, панель логов |
| Text primary | `#F2F5F9` | заголовки, значения, wordmark |
| Text secondary | `#8B95A5` | подписи, единицы, время лога |
| Accent connected | `#2CE5A7` | Connected: кольцо, glow, «go»-кнопка |
| Accent transitional | `#FFB454` | Connecting/Disconnecting: кольцо, сегмент, progress |
| Accent error | `#FF5C5C` | Error: разомкнутое кольцо, текст ошибки, destructive |
| Accent idle | `#5A6472` | Disconnected: тонкое статичное кольцо |
| Glow | accent состояния @ opacity 0.10–0.16 | радиальный градиент от центра под ирисом |

### Светлая тема

Фон `#F4F6F9`, поверхности белые (`#FFFFFF` card, `#EEF1F5` elevated), text primary `#0B0F14`, secondary `#5A6472`. Акценты затемняются до контраста ≥4.5:1 на светлом фоне (рекомендованные дефолты, исполнитель проверяет пары): connected `#0E9E75`, transitional `#B26A00`, error `#C62828`, idle `#5A6472`. Glow opacity в светлой теме мягче (0.06–0.10).

### Accent reserved for

Акцент состояния применяется только к: (1) кольцу и glow ириса, (2) тексту бейджа статуса, (3) заливке/обводке кнопки Connect/Disconnect, (4) активному индикатору плитки трафика и стрелкам ↓/↑, (5) цветовой маркировке уровня строки лога (info secondary, warning transitional-amber, error coral). Нигде больше акцент не используется: карточки, панель логов, wordmark, вторичный текст остаются нейтральными. Никаких «все интерактивные элементы акцентные».

### Destructive

`#FF5C5C` (совпадает с error-акцентом). Единственное деструктивное действие фазы — Disconnect. Модального подтверждения нет: разрыв мгновенный и обратимый (reconnect в один тап), подтверждение даёт haptic `mediumImpact`. Это осознанное решение контракта, а не упущение.

### Контраст (проверка исполнителем)

| Пара (dark) | Оценка | Порог |
|-------------|--------|-------|
| `#F2F5F9` на `#0B0F14` | ~18:1 | текст 4.5:1 ✓ |
| `#8B95A5` на `#0B0F14` | ~5.5:1 | текст 4.5:1 ✓ |
| `#2CE5A7` / `#FFB454` на `#0B0F14` | ≥8:1 | крупное 3:1 ✓ |
| `#FF5C5C` на `#0B0F14` | ~5:1 | текст ошибки 4.5:1 ✓ |

Статус дублируется словом в бейдже, не только цветом (доступность DESIGN).

---

## Композиция экрана (портрет, phone-only)

`Scaffold` с фоном dominant + `Stack`: слой glow (радиальный градиент состояния) под контентом. Сверху вниз в `SafeArea`:

1. **AppBar-зона** (hard, высота ~56): слева `OkoWordmark` (`oko`, Title), справа `StatusBadge` (слово статуса).
2. **Iris** (стретч, ~40% высоты, `Expanded`/`Flexible`): `IrisIndicator`, в центре `ConnectionTimer` (Connected) либо закрытый зрачок (Disconnected, рисует painter).
3. **ServerCard**: имя сервера, `host:port`, chevron (статичный).
4. **TrafficPanel**: `Row` из двух `TrafficTile` (`↓ down` / `↑ up`), gap `md`.
5. **ConnectButton** (thumb, full-width, высота 56): цвет и лейбл ведёт статус, блокировка в переходных.
6. **LogConsole**: `DraggableScrollableSheet` снизу поверх `Stack` (min 0.12 — видна последняя строка, max 0.70), grabber, заголовок `Logs`, copy-all, моноширинные строки, автоскролл.

Разные масштабы блоков ломают монотонную вертикаль (крупный ирис против компактных плиток). Между блоками отступы по сетке (`lg` вертикально, `md` по горизонтали).

---

## Ключевые виджеты

### OkoWordmark
Текст `oko` (Title, Space Grotesk 20/600, text primary). Опционально акцентная точка над `o` цветом состояния (2px, `accentFor(status)`). Без изображений.

### StatusBadge
Pill (radius 999), фон `accentFor(status)` @ opacity 0.16, текст `accentFor(status)` (Label 12/600, uppercase). Слова: `Disconnected` / `Connecting` / `Connected` / `Disconnecting` / `Error`. Цвет фона кроссфейдит 300ms при смене статуса (см. motion). Semantics сливается с ирисом (см. доступность), избегая двойного озвучивания.

### IrisIndicator + IrisPainter (сигнатурный элемент)

`StatefulWidget` с `AnimationController`ами; `CustomPaint` рисует кольцо-ирис. Один painter, вся геометрия параметризована через анимируемые значения. Реагирует на `VpnStatus` через `BlocBuilder` и на `MediaQuery.disableAnimations`.

Геометрия: центрированный круг, диаметр = `min(constraints) * 0.8`. Кольцо (`PaintingStyle.stroke`), «зрачок» — внутренний круг. Радиальный glow рисуется как `RadialGradient` под кольцом (или отдельным `Stack`-слоем на уровне экрана).

| Статус | Кольцо | Зрачок | Glow | Анимация |
|--------|--------|--------|------|----------|
| Disconnected | тонкое (3px), статичное, `accentIdle` | закрыт (узкая щель/точка) | нет | статика |
| Connecting | среднее (5px), `accentTransitional`; яркий сегмент ~40° бежит по окружности | приоткрыт | слабый amber (0.10) | сегмент вращается 1200ms linear loop; «дыхание» scale 0.97↔1.03 1600ms easeInOut reverse |
| Connected | толстое (8px), `accentConnected`; ровное | раскрыт полностью, внутри таймер | мягкий green glow, дыхание opacity 0.10↔0.16 4000ms | однократный «раскрыв» зрачка 600ms easeOutBack (overshoot) при входе, затем статика + дыхание glow |
| Disconnecting | среднее, `accentTransitional`; сегменты схлопываются | закрывается | amber гаснет | glow fade-out 300ms; зрачок сжимается |
| Error | разомкнутое (разрыв дуги ~30°), `accentError` | закрыт | коротко coral | shake 250ms по X (sin, амплитуда 8px) + `HapticFeedback.heavyImpact` один раз |

Цвет кольца и glow интерполируются 300ms при любой смене статуса (`ColorTween` на контроллере), переходы не «прыгают». При `disableAnimations`: все loop-анимации (сегмент, дыхание, glow-пульс) отключены, рисуется статичный кадр состояния; overshoot и shake заменяются мгновенным финальным кадром.

### ConnectionTimer
`StatefulWidget`, вход `DateTime? connectedSince` из Bloc-state. Держит `Timer.periodic(1s)`, формат `HH:MM:SS` (zero-pad, `Duration = DateTime.now().difference(connectedSince)`). Источник истины `connectedSince`, поэтому пересоздание виджета таймер не сбрасывает (UI-04). Space Grotesk 48/600 tabular, `FittedBox`. Виден только в Connected; в остальных статусах центр ириса пуст/зрачок. При `connectedSince == null` не тикает.

### ServerCard
Container secondary (radius 20, паддинг `lg`), elevated-поверхность. Левая иконка `Icons.dns_rounded` (accent-нейтральная, secondary). Две строки: `serverName` (Body 15/600 primary), `host:port` (Caption 12 secondary). Справа `Icons.chevron_right_rounded` (secondary, статичный, в прототипе не кликается). Никаких одинаковых карточек с одинаковыми отступами: карточка визуально отличается от плиток трафика скруглением и плотностью.

### TrafficPanel + TrafficTile
`Row` двух плиток равной ширины, gap `md`. Плитка (secondary, radius 16, высота 72, паддинг `md`):
- верх: иконка направления + uppercase-лейбл. rx: `Icons.arrow_downward_rounded` + `DOWN` (accentConnected при Connected, иначе secondary). tx: `Icons.arrow_upward_rounded` + `UP`.
- низ: значение (Space Grotesk 20/600 tabular primary) + единица (Inter 12 secondary).

Форматирование байт: авто-единица `B` / `KB` / `MB` / `GB` (делитель 1024), одна десятичная от KB и выше, целое для B. Пример: `12.4 MB`, `812 B`. Данные из `VpnTrafficReceived`. Значения меняются плавно (без layout-jitter благодаря tabular figures).

### ConnectButton
Full-width, высота 56, radius 16. Лейбл, цвет и enabled ведёт статус. Тап шлёт `ConnectRequested` или `DisconnectRequested` в зависимости от статуса; haptic `mediumImpact` на нажатие. В переходных статусах `onPressed: null` (физически невозможен двойной тап на уровне UI; Bloc-гейт `isBusy` — вторая линия защиты).

| VpnStatus | Label | Стиль | Enabled | Контент |
|-----------|-------|-------|---------|---------|
| disconnected | `Connect` | filled `accentConnected`, текст `#0B0F14` | да | leading `Icons.power_settings_new_rounded` |
| connecting | `Connecting…` | filled `accentTransitional` @ opacity 0.6 | нет | inline бегущий сегмент-progress слева |
| connected | `Disconnect` | tonal/outlined на secondary, текст+обводка `accentError` | да | leading `Icons.power_settings_new_rounded` |
| disconnecting | `Disconnecting…` | filled `accentTransitional` @ opacity 0.6 | нет | inline progress |
| error | `Retry` | filled `accentError` tonal | да | leading `Icons.refresh_rounded` |

Смена стиля кнопки кроссфейдит вместе с общим переходом состояния (300ms). Спиннеры запрещены (DESIGN): прогресс в переходных статусах — бегущий сегмент, не `CircularProgressIndicator`.

### LogConsole + LogLine
`DraggableScrollableSheet` (initial 0.12, min 0.12, max 0.70), фон secondary elevated, верхние углы radius 24. Шапка: grabber (4x36, secondary, центр), слева заголовок `Logs` (Title 20/600), справа кнопка copy-all (`Icons.copy_rounded`, touch 48). Тело: `ListView` строк `LogLine`.

`LogLine`: JetBrains Mono 12, формат `HH:mm:ss  text`, цвет ведёт уровень: info → text secondary, warning → `accentTransitional`, error → `accentError` (UI-08). Время лога всегда secondary. 

Автоскролл: при новой записи и `autoScroll == true` контроллер скроллит к концу (`animateTo`, 200ms). Ручная прокрутка вверх ставит `autoScroll = false` (через `NotificationListener<ScrollNotification>`: если пользователь ушёл от `maxScrollExtent` больше чем на порог); возврат к низу возобновляет автоскролл. Опциональный «Jump to latest» chip при `autoScroll == false`.

Copy-all: `Clipboard.setData(ClipboardData(text: LogsCubit.plainText()))`, затем `HapticFeedback.selectionClick` и `SnackBar` `Copied N lines`.

Пустое состояние (буфер пуст на старте): по центру тела иконка `Icons.terminal_rounded` (secondary, 32) + заголовок `Waiting for events` (Body 15 secondary) + строка `Tunnel logs stream here in real time.` (Caption 12 secondary). Не пустой серый прямоугольник.

---

## Copywriting Contract

UI-копирайт английский (соответствует DESIGN: `oko`, `Logs`, слова статусов). Прозаические доки проекта русские, но экранные строки английские и согласованы между собой.

| Element | Copy |
|---------|------|
| Primary CTA (disconnected) | `Connect` |
| Primary CTA (connected) | `Disconnect` |
| Primary CTA (error) | `Retry` |
| Transitional CTA | `Connecting…` / `Disconnecting…` (disabled) |
| Status badge | `Disconnected` / `Connecting` / `Connected` / `Disconnecting` / `Error` |
| Empty state heading (logs) | `Waiting for events` |
| Empty state body (logs) | `Tunnel logs stream here in real time.` |
| Error state | текст из `VpnError.message` (например `Consent denied`); при пустом message фолбэк `Connection failed. Tap Retry.` Показывается как строка под ирисом (Body 15, `accentError`) и в бейдже словом `Error` |
| Copy confirmation | `Copied {n} lines` (SnackBar) |
| Destructive confirmation | Disconnect: подтверждения нет, действие мгновенное и обратимое, обратная связь `HapticFeedback.mediumImpact` |

---

## Motion

Все длительности и кривые как `const` в `oko_motion.dart`, переиспользуются виджетами (единый ритм).

| Переход | Длительность | Кривая | Детали |
|---------|--------------|--------|--------|
| Вход экрана (staggered) | 350ms | `easeOutCubic` | fade+slide снизу; порядок и задержки: iris 0ms, serverCard 60ms, trafficPanel 120ms, connectButton 180ms, logConsole 240ms |
| Смена статуса (цвет+glow) | 300ms | `easeInOut` | `ColorTween` кольца/кнопки/бейджа + opacity glow; без «прыжков» |
| Connected раскрыв зрачка | 600ms | `easeOutBack` | однократно при входе в Connected, лёгкий overshoot |
| Connected дыхание glow | 4000ms cycle | `easeInOut` reverse | opacity 0.10↔0.16, бесконечный |
| Connecting сегмент | 1200ms | `linear` | вращение сегмента по кольцу, бесконечный |
| Connecting дыхание кольца | 1600ms | `easeInOut` reverse | scale 0.97↔1.03 |
| Error shake | 250ms | sin | смещение по X ±8px + `HapticFeedback.heavyImpact` (однократно) |
| Автоскролл логов | 200ms | `easeOut` | `animateTo(maxScrollExtent)` |
| Кнопка press haptic | — | — | `HapticFeedback.mediumImpact` на тап Connect/Disconnect |
| Enter Connected haptic | — | — | `HapticFeedback.lightImpact` (подтверждение успеха) |

`MediaQuery.disableAnimations == true`: все бесконечные loop (сегмент, дыхание кольца/glow) и overshoot/shake отключены; состояния рисуются статичным финальным кадром, кроссфейд статуса сокращается до мгновенного. Haptics остаются (не анимация). Reduce-motion уважается на уровне `oko_motion.dart` (флаг прокидывается в контроллеры).

---

## Accessibility

- **Iris `Semantics`** (единый лейбл состояния, `liveRegion: true` для озвучивания смены): disconnected `VPN disconnected`; connecting `Connecting to {serverName}`; connected `VPN connected, {duration} elapsed`; disconnecting `Disconnecting`; error `Connection error: {message}`. Бейдж помечается `excludeSemantics` внутри общего узла, чтобы не дублировать.
- **ConnectButton `Semantics`**: `label` = действие + статус (`Connect`, `Disconnect`, `Retry`), `button: true`, `enabled` отражает блокировку. Переходные статусы озвучиваются как disabled.
- **TrafficTile `Semantics`**: `Downloaded {value}` / `Uploaded {value}` (человекочитаемо, не «arrow down 12.4 MB»).
- **LogConsole**: заголовок как heading; каждая строка `Semantics(label: '{level}: {text}')`; copy-кнопка `label: 'Copy all logs'`.
- **Дублирование не только цветом**: статус в бейдже словом, уровень лога — цвет плюс различимость (исполнитель может добавить префикс уровня в mono-строке при желании).
- **Контраст**: все текстовые пары ≥4.5:1, крупные/графические ≥3:1 (таблица выше), в обеих темах.
- **Dynamic Type**: тексты через `TextTheme`, `textScaler` уважается; таймер в `FittedBox`, вертикаль под-скроллит при 200% (нет фиксированных высот у текстовых блоков, кроме кнопки 56 с внутренним `FittedBox`). iOS: swipe-back и `CupertinoPageTransition` по умолчанию не переопределять.
- **Touch targets** ≥48dp: copy, chevron, кнопка.

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| not applicable (Flutter, без shadcn/реестров) | — | not required |

Внешних UI-реестров нет. Единственная новая pub-зависимость `google_fonts` — официальный пакет Flutter team, вредоносных паттернов не вносит. Вся кастомная графика (ирис) пишется в проекте.

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS

**Approval:** pending

---

## Requirements coverage

| Req | Где покрыт в контракте |
|-----|------------------------|
| UI-01 | IrisIndicator (5 статусов) + StatusBadge |
| UI-02 | ConnectButton (блокировка в переходных) + Bloc `isBusy` гейт |
| UI-03 | LogConsole (реалтайм, буфер 500, автоскролл с отключением) |
| UI-04 | ServerCard + ConnectionTimer (от `connectedSince`, переживает пересоздание) |
| UI-05 | TrafficPanel/TrafficTile (rx/tx) |
| UI-06 | темы (OkoTones dark+light), ирис CustomPainter, staggered-вход, haptics, motion |
| UI-07 | `VpnStarted` → `syncStatus()` в Bloc |
| UI-08 | LogLine цвет уровня + copy-all |
| QA-02 | Bloc-тесты (переходы, error, onRevoke, double-tap guard) |
