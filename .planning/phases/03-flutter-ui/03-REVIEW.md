---
phase: 03-flutter-ui
reviewed: 2026-07-13T23:44:24Z
depth: deep
files_reviewed: 30
files_reviewed_list:
  - lib/core/theme/oko_tones.dart
  - lib/core/theme/oko_typography.dart
  - lib/core/theme/oko_theme.dart
  - lib/core/theme/oko_motion.dart
  - lib/core/theme/vpn_status.dart
  - lib/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart
  - lib/features/vpn_connection/presentation/bloc/vpn_connection_event.dart
  - lib/features/vpn_connection/presentation/bloc/vpn_connection_state.dart
  - lib/features/vpn_connection/domain/usecases/watch_traffic.dart
  - lib/features/vpn_connection/presentation/widgets/iris_painter.dart
  - lib/features/vpn_connection/presentation/widgets/iris_indicator.dart
  - lib/features/vpn_connection/presentation/widgets/connection_timer.dart
  - lib/features/vpn_connection/presentation/widgets/status_badge.dart
  - lib/features/vpn_connection/presentation/widgets/server_card.dart
  - lib/features/vpn_connection/presentation/widgets/traffic_panel.dart
  - lib/features/vpn_connection/presentation/widgets/traffic_tile.dart
  - lib/features/vpn_connection/presentation/widgets/connect_button.dart
  - lib/features/vpn_connection/presentation/widgets/oko_wordmark.dart
  - lib/features/vpn_connection/presentation/formatters/byte_format.dart
  - lib/features/vpn_connection/presentation/formatters/duration_format.dart
  - lib/features/vpn_logs/presentation/bloc/logs_cubit.dart
  - lib/features/vpn_logs/presentation/bloc/logs_state.dart
  - lib/features/vpn_logs/presentation/widgets/log_console.dart
  - lib/features/vpn_logs/presentation/widgets/log_line.dart
  - lib/features/vpn_connection/presentation/screens/vpn_home_screen.dart
  - lib/app/app.dart
  - lib/app/di.dart
  - lib/main.dart
  - pubspec.yaml
  - test/ (bloc, cubit, formatter, widget suites)
findings:
  blocker: 0
  high: 1
  medium: 2
  low: 5
  total: 8
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-07-13T23:44:24Z
**Depth:** deep
**Files Reviewed:** 30
**Status:** issues_found

## Summary

Ревью presentation-слоя Flutter поверх готовых domain/data фаз 1-2. Слой собран
качественно: SOLID и Bloc-паттерн выдержаны (виджеты только `BlocBuilder`/
`BlocListener` + dispatch событий), sealed+equatable без лишнего кодогена,
границы фичи соблюдены. По ключевым Flutter-рискам код чист:

- **Утечки** — все `AnimationController` (4 в `IrisIndicator`, 1 в
  `_RunningSegment`, 1 entrance в `VpnHomeScreen`), `CurvedAnimation`, `Timer`
  (`ConnectionTimer`) и подписки (`VpnConnectionBloc._stateSub`/`_trafficSub`,
  `LogsCubit._sub`) закрыты в `dispose`/`close`. `LogConsole` корректно НЕ
  диспозит чужой `scrollController` из `DraggableScrollableSheet`.
- **Bloc-паттерн** — `.listen → add(internal event)`, отмена в `close()`, нет
  `emit.forEach`, нет двойного emit. QA-02 (сценарии 1-6) покрыт тестами.
- **reduce-motion** — `disableAnimationsOf` читается в `didChangeDependencies`,
  анимации не рестартятся на rebuild.
- **CustomPainter** — `shouldRepaint` в `IrisPainter` и `_SegmentPainter`
  проверяет все поля.
- **copyWith clear-флаги** — `clearConnectedSince`/`clearError` обнуляют nullable
  корректно, clear имеет приоритет над значением.
- **setState/mounted** — `_copyAll` захватывает `messenger` до `await`, context
  после await не трогает.

BLOCKER'ов и уязвимостей нет. Одна HIGH-проблема в автоскролле логов (реальная
регрессия под всплеском событий — ровно в момент подключения) и две MEDIUM в
`VpnConnectionBloc`. Остальное — низкий приоритет и хрупкие места.

## High

### H-01: Автоскролл логов зависает в паузе при всплеске событий

**File:** `lib/features/vpn_logs/presentation/widgets/log_console.dart:35-39, 65-76, 78-90`

**Issue:** `NotificationListener<ScrollNotification>` реагирует на ЛЮБОЕ
скролл-уведомление, не отличая пользовательский drag от программного
`animateTo`. `_followTail` вызывает `controller.animateTo(maxScrollExtent)`, а эта
анимация сама порождает `ScrollUpdateNotification`, которые снова попадают в
`_syncAutoScroll`.

Сценарий поломки при пакетной подаче логов (нативный слой шлёт по несколько строк
за кадр во время connect):
1. Прилетают N строк за один кадр → `maxScrollExtent` вырастает на >
   `_bottomThreshold` (24px) раньше, чем `animateTo` догонит низ.
2. Стартует `animateTo`; первый `ScrollUpdateNotification` при `pixels <
   maxScrollExtent - 24` → `_syncAutoScroll` вызывает `pauseAutoScroll()` →
   `autoScroll = false` посреди программной анимации.
3. Следующая пачка строк до завершения анимации: `listener → _followTail`, но
   теперь `state.autoScroll == false` → follow не выполняется.
4. Автоскролл заклинивает в паузе до ручного возврата к низу.

Дополнительно: `pauseAutoScroll`/`resumeAutoScroll` эмитят новый `LogsState`,
что снова дёргает `listener → _followTail` — лишний churn и потенциальная петля
`resume → animateTo → notification → resume`.

Раздел «особое внимание» прямо требует «Автоскролл логов: не дёргается,
pause/resume корректны», поэтому это регрессия целевого поведения.

**Fix:** Реагировать в `_syncAutoScroll` только на пользовательский скролл.
`animateTo` не порождает `UserScrollNotification` — фильтрация по нему чисто
отделяет ручной drag от программного:

```dart
child: NotificationListener<ScrollNotification>(
  onNotification: (notification) {
    if (notification is UserScrollNotification) {
      _syncAutoScroll(context, scrollController);
    }
    return false;
  },
  ...
```

Альтернатива: выставлять флаг `_suppressSync` вокруг `animateTo` (потребует
перевода `LogConsole` в `StatefulWidget`) и игнорировать уведомления, пока идёт
программная прокрутка.

## Medium

### M-01: rx/tx-счётчики не сбрасываются при переходах статуса

**File:** `lib/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart:71-81, 99-128`

**Issue:** `_onTrafficReceived` применяет `rxBytes`/`txBytes` независимо от статуса,
а `_map` при `VpnDisconnected`/`VpnConnecting`/`VpnDisconnecting` их не
обнуляет. После disconnect в `VpnConnectionState` остаются байты прошлой сессии;
`TrafficPanel` при `active == false` красит их серым, но показывает старые числа.
При новом connect до первого `TrafficChanged` панель покажет цифры прошлой
сессии. Корректность зависит от того, шлёт ли нативный слой нулевой
`TrafficChanged` на разрыв — гарантии нет.

**Fix:** Сбрасывать счётчики на переходах, где сессия закончилась/началась:

```dart
VpnDisconnected() => state.copyWith(
    status: VpnStatus.disconnected,
    rxBytes: 0,
    txBytes: 0,
    clearConnectedSince: true,
    clearError: true,
  ),
VpnConnecting() => state.copyWith(
    status: VpnStatus.connecting,
    rxBytes: 0,
    txBytes: 0,
    clearConnectedSince: true,
    clearError: true,
  ),
```

(либо игнорировать `VpnTrafficReceived`, когда `status != connected`).

### M-02: VpnStarted не идемпотентен — повторный dispatch течёт подписками

**File:** `lib/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart:43-62, 130-135`

**Issue:** `_onStarted` присваивает `_stateSub`/`_trafficSub` без отмены прежних.
Сегодня `VpnStarted` шлётся один раз (`app.dart:37`), но при повторном dispatch
(рефактор, hot-restart-подобный сценарий, повторная инициализация) старые
подписки перезаписываются и текут — `close()` отменит только последние. Тихая
утечка без ошибки.

**Fix:** Отменять прежние подписки перед пересозданием или защититься гвардом:

```dart
await _stateSub?.cancel();
await _trafficSub?.cancel();
_stateSub = watchVpnState().listen((s) => add(VpnStateReceived(s)));
_trafficSub = watchTraffic().listen((t) => add(VpnTrafficReceived(t)));
```

## Low

### L-01: hhmmss некорректно рендерит отрицательную длительность

**File:** `lib/features/vpn_connection/presentation/formatters/duration_format.dart:1-7`

**Issue:** `ConnectionTimer` считает `DateTime.now().difference(since)`
(`connection_timer.dart:57`). Если `connectedSince` окажется в будущем (расхождение
часов native↔Dart), длительность отрицательна. Из-за неотрицательного модуля Dart
(`-1 % 60 == 59`) `hhmmss(Duration(seconds: -1))` вернёт `00:00:59` вместо
`00:00:00`.

**Fix:** Клампить к нулю в начале форматтера:

```dart
String hhmmss(Duration d) {
  if (d.isNegative) d = Duration.zero;
  ...
```

### L-02: AppDependencies.dispose() определён, но никогда не вызывается

**File:** `lib/app/di.dart:50-54`, `lib/main.dart:7-12`

**Issue:** `AppDependencies` создаётся в `main()` и живёт всё время процесса;
`dispose()` (закрывает репозитории, event-стрим моста) не вызывается ниоткуда —
мёртвый код и латентная утечка ресурсов моста. Для одного инстанса на весь
процесс безвредно, но при пересоздании `OkoApp` (тесты с реальным DI,
hot-restart) ресурсы не освобождаются.

**Fix:** Либо вызывать `dispose()` при демонтаже приложения (например, через
`AppLifecycleListener`/обёртку над `OkoApp`), либо убрать метод, если полагаемся
на завершение процесса. Как минимум — зафиксировать намеренность.

### L-03: _onStarted — подписка после await и перехват только Failure

**File:** `lib/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart:47-61`

**Issue:** Два аспекта одного метода:
1. `_stateSub`/`_trafficSub` создаются ПОСЛЕ `await syncStatus()`. Если репозиторий
   эмитит начальный статус/трафик синхронно во время `syncStatus` (до `listen`), а
   стрим не реплеит текущее значение, событие теряется. Работает только при
   broadcast-стриме с текущим значением.
2. `catch` ловит лишь `Failure`; не-`Failure` исключение из `syncStatus` (например
   несмапленный `PlatformException`) уходит в необработанную зону.

**Fix:** Подписываться до `await syncStatus()`; при желании расширить обработку до
generic-исключения с переводом в error-состояние.

### L-04: TrafficTile жёстко завязан на формат вывода formatBytes

**File:** `lib/features/vpn_connection/presentation/widgets/traffic_tile.dart:28-31`

**Issue:** `formatBytes(bytes)` разбирается через `lastIndexOf(' ')` +
`substring(0, split)`/`substring(split + 1)`. Если `formatBytes` когда-нибудь
вернёт строку без пробела, `split == -1` → `substring(0, -1)` кинет
`RangeError`. Сейчас безопасно (вывод всегда «value unit»), но связь хрупкая.

**Fix:** Возвращать структурированный результат (record `(value, unit)`) из
форматтера и не парсить строку в виджете:

```dart
(String, String) formatBytesParts(int bytes) { ... }
```

### L-05: Повсеместный force-unwrap `extension<OkoTones>()!`

**File:** несколько виджетов (напр. `iris_indicator.dart:133`, `log_line.dart:13`,
`traffic_tile.dart:21`, `status_badge.dart:21`, `vpn_home_screen.dart:68`)

**Issue (CONVENTION / recommend-fix):** `Theme.of(context).extension<OkoTones>()!`
кидает, если виджет используется вне `OkoTheme`. Под текущей разводкой (всё под
`OkoApp`/`OkoTheme`, тесты оборачивают в `OkoTheme.dark`) безопасно и идиоматично
для `ThemeExtension`. Deviation: единственная точка отказа размазана по слою.
Рекомендация (не блокер): вынести доступ в единый безопасный хелпер-extension с
понятным `assert`/fallback, например `context.tones`, чтобы централизовать
контракт и упростить переиспользование виджетов вне темы.

---

_Reviewed: 2026-07-13T23:44:24Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
