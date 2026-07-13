---
phase: 01-pigeon
reviewed: 2026-07-13T21:10:00Z
depth: deep
files_reviewed: 32
files_reviewed_list:
  - pigeons/vpn_api.dart
  - lib/core/bridge/vpn_bridge.dart
  - lib/core/error/failures.dart
  - lib/core/error/vpn_exception.dart
  - lib/features/vpn_connection/domain/entities/vpn_state.dart
  - lib/features/vpn_connection/domain/entities/vpn_config.dart
  - lib/features/vpn_connection/domain/entities/traffic_stats.dart
  - lib/features/vpn_connection/domain/repositories/vpn_repository.dart
  - lib/features/vpn_connection/domain/usecases/connect_vpn.dart
  - lib/features/vpn_connection/domain/usecases/disconnect_vpn.dart
  - lib/features/vpn_connection/domain/usecases/sync_status.dart
  - lib/features/vpn_connection/domain/usecases/watch_vpn_state.dart
  - lib/features/vpn_connection/data/mappers/vpn_event_mapper.dart
  - lib/features/vpn_connection/data/datasources/vpn_native_datasource.dart
  - lib/features/vpn_connection/data/repositories/vpn_repository_impl.dart
  - lib/features/vpn_logs/domain/entities/log_entry.dart
  - lib/features/vpn_logs/domain/repositories/log_repository.dart
  - lib/features/vpn_logs/domain/usecases/watch_logs.dart
  - lib/features/vpn_logs/data/mappers/log_mapper.dart
  - lib/features/vpn_logs/data/datasources/log_native_datasource.dart
  - lib/features/vpn_logs/data/repositories/log_repository_impl.dart
  - lib/app/di.dart
  - lib/app/app.dart
  - lib/main.dart
  - android/app/src/main/kotlin/com/example/vpn_oko/MainActivity.kt
  - android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnEventBus.kt
  - android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnEventListener.kt
  - android/app/src/main/kotlin/com/example/vpn_oko/bridge/VpnHostApiImpl.kt
  - ios/Runner/AppDelegate.swift
  - ios/Runner/Bridge/VpnHostApiImpl.swift
  - ios/Runner/Bridge/VpnEventListener.swift
  - ios/Runner/SceneDelegate.swift
findings:
  blocker: 0
  high: 1
  medium: 3
  low: 6
  total: 10
status: issues_found
---

# Фаза 01 (pigeon): отчёт код-ревью

**Проверено:** 2026-07-13T21:10:00Z
**Глубина:** deep (пофайлово + кросс-файловые цепочки: di → bridge → repository → mapper)
**Файлов проверено:** 32 (сгенерированные `*.g.dart`/`Messages.g.*` исключены по заданию)
**Статус:** issues_found

## Резюме

Echo-мост работает по счастливому пути: события с native доставляются через main-thread/main-queue,
демультиплекс sealed-событий в `VpnBridge` разделяет потоки корректно, маппер уровня лога терпим к
регистру и неизвестным значениям без `ArgumentError`, replay последнего статуса реализован на обеих
платформах и в репозитории. Blocker-ов нет: краши по main-thread и `ArgumentError` в этой фазе не
воспроизводятся, секретов и инъекций в скоупе нет.

Слабые места лежат в области, помеченной как «особое внимание». Маппинг `PlatformException → Failure`
сделан только для `connect`, а `disconnect` и `syncStatus` пропускают платформенную ошибку в domain/UI
сырой (H-01). Стрим ошибок `errorEvents` объявлен, но нигде не потребляется, из-за чего `VpnError`
всегда несёт `'unknown'`, а `ErrorMessage` с native молча теряется (M-02). Replay-then-subscribe в
`watchState`/`watchLogs` имеет узкое окно гонки с потерей события (M-01). Репозитории не диспоузятся —
их broadcast-контроллеры не закрываются (M-03).

Тесты присутствуют для моста, мапперов, состояний и репозитория соединения — это соответствует
test-as-you-go. Не покрыты: ring buffer `LogRepositoryImpl`, ветки `disconnect`/`syncStatus` с
`PlatformException`.

## Narrative Findings (AI reviewer)

> Схема тиров под задание: `blocker` (эквивалент Critical) / `high` / `medium` / `low`. Blocker-ов нет.

## High

### H-01: `disconnect()` и `syncStatus()` не оборачивают `PlatformException` в typed Failure

**Файлы:** `lib/features/vpn_connection/data/repositories/vpn_repository_impl.dart:54-55`, `:57-61`
**Issue:** Конвенция проекта прямо требует: «Ошибки: PlatformException → typed Failure в data-слое; UI
получает доменные ошибки, не строки платформы». `connect()` это делает (`try/catch` →
`mapPlatformException`), но `disconnect()` (`Future<void> disconnect() => _ds.stop();`) и `syncStatus()`
пропускают исключение сырым. На iOS `getStatus()` объявлен `throws`, а `stopVpn` может завершиться
ошибкой на реальном слое — тогда сырой `PlatformException` дойдёт до domain/UI. В `main()` вызов
`unawaited(dependencies.syncStatus())` (`lib/main.dart:20`) превратит такую ошибку в unhandled async
error. Асимметрия с уже реализованным `connect` делает это явным дефектом, а не пробелом дизайна.
**Fix:**
```dart
@override
Future<void> disconnect() async {
  try {
    await _ds.stop();
  } on PlatformException catch (exception) {
    throw mapPlatformException(exception);
  }
}

@override
Future<void> syncStatus() async {
  try {
    _last = snapshotToEntity(await _ds.currentStatus());
    _controller.add(_last);
  } on PlatformException catch (exception) {
    throw mapPlatformException(exception);
  }
}
```

## Medium

### M-01: Гонка replay-then-subscribe в `watchState()`/`watchLogs()` — окно потери события

**Файлы:** `lib/features/vpn_connection/data/repositories/vpn_repository_impl.dart:30-33`, `lib/features/vpn_logs/data/repositories/log_repository_impl.dart:29-34`
**Issue:** Оба генератора отдают снапшот, затем подписываются на broadcast-контроллер:
`yield _last; yield* _controller.stream` (и аналогично буфер логов). Между `yield` снапшота и точкой
`yield* _controller.stream` есть граница микротаска. Если ровно в этом окне придёт событие
(`_onState`/`_onLog` вызовет `_controller.add(...)`), broadcast-контроллер без активной подписки
отбросит его. Для логов это безвозвратная потеря записи, для статуса — пропуск промежуточного перехода
(финальное состояние восстановится из `_last` при следующем событии, но переход `CONNECTING` может
исчезнуть). Тесты избегают окна через `pumpEventQueue()` до эмиссии, поэтому дефект скрыт. Это прямо
попадает в помеченную зону «race событие раньше подписки». В текущей проводке риск низкий (подписчики
цепляются на init до событий), но пул тонкий.
**Fix:** Подписаться на контроллер до отдачи снапшота (собирать входящие во время дренажа в очередь и
слить их перед `yield*`), либо перейти на `rxdart` `BehaviorSubject` (для статуса) и `ReplaySubject`
(для логов), где seed/replay и live-поток атомарны.

### M-02: `errorEvents` не потребляется — ошибки native теряются, `VpnError` всегда `'unknown'`

**Файлы:** `lib/core/bridge/vpn_bridge.dart:21-22`, `:27`, `:43-44`; `lib/features/vpn_connection/data/mappers/vpn_event_mapper.dart:15`
**Issue:** `VpnBridge` маршрутизирует `ErrorMessage` в контроллер `_errors` и отдаёт его через геттер
`errorEvents`, но по всему `lib/` нет ни одного подписчика (`grep errorEvents` даёт только объявление).
`VpnRepositoryImpl` слушает лишь `_ds.states`, поэтому любой `ErrorMessage(code, message)` с native
уходит в никуда. Параллельно маппер статуса жёстко возвращает `VpnError('unknown')` для
`VpnStatusMessage.error`, так как `StatusChangedMessage` не несёт текста. Итог: детали ошибки с native
недоступны через `watchState()`. В echo-фазе ошибки не эмитятся, но канал ошибок мёртв уже сейчас.
**Fix:** Слить `errorEvents` в поток статусов репозитория (например, `Rx.merge` статусов и
`errorEvents.map((e) => VpnError(e.message))`), прокидывая `code`/`message` в доменный `VpnError`.

### M-03: Репозитории не диспоузятся — broadcast-контроллеры не закрываются

**Файлы:** `lib/app/di.dart:39`; `lib/features/vpn_connection/data/repositories/vpn_repository_impl.dart:63-66`; `lib/features/vpn_logs/data/repositories/log_repository_impl.dart:36-39`
**Issue:** `AppDependencies.dispose()` зовёт только `_bridge.dispose()`. `dispose()` у
`VpnRepositoryImpl` и `LogRepositoryImpl` существует на реализации, но не объявлен в интерфейсах
`VpnRepository`/`LogRepository`, а поля хранятся под типом интерфейса — вызвать `dispose()` из
composition root нельзя без каста. В результате `_controller` обоих репозиториев никогда не
закрывается. Подписки `_subscription` частично спасает каскад done при закрытии `_bridge`, но
контроллеры остаются открытыми. Попадает в помеченную зону «утечки StreamController/подписок». На
завершении процесса ОС всё вернёт, поэтому severity medium, а не выше.
**Fix:** Хранить в `AppDependencies` конкретные типы реализаций (или отдельные disposable-ссылки) и
закрывать их в `dispose()` до `_bridge.dispose()`; либо добавить `dispose()` в контракт репозитория.

## Low

### L-01: `PlatformFailure` объявлен, но нигде не используется — мёртвый код

**Файл:** `lib/core/error/failures.dart:10-17`
**Issue:** `grep` по `lib/` находит `PlatformFailure` только в объявлении. `mapPlatformException`
возвращает исключительно `VpnStartFailure`. Неиспользуемый тип-ошибка.
**Fix:** Удалить `PlatformFailure` либо задействовать его как результат маппинга ошибок не-start
операций (`disconnect`/`getStatus`) — это заодно снимает L-05.

### L-02: Kotlin-снапшот не обновляет `rxBytes`/`txBytes` из `TrafficChangedMessage`, Swift обновляет

**Файлы:** `android/.../bridge/VpnEventBus.kt:27-38`; `ios/Runner/Bridge/VpnEventListener.swift:20-30`
**Issue:** В Swift `emit` при `TrafficChangedMessage` пишет `rxBytes`/`txBytes`, и `snapshot()` их
отдаёт. В Kotlin `VpnEventBus.emit` пересобирает `snapshot` только на `StatusChangedMessage`, всегда
сохраняя старые `rxBytes`/`txBytes` — обновления трафика в снапшот не попадают. Межплатформенное
расхождение поведения `getStatus()`. В echo-фазе трафик не эмитится, дефект латентный, но выстрелит в
следующей фазе.
**Fix:** В Kotlin-ветке `emit` добавить обработку `TrafficChangedMessage` с обновлением `rxBytes`/
`txBytes` в `snapshot`, симметрично Swift.

### L-03: Маппер уровня лога кладёт алиас `warn` в `info`, теряя severity

**Файл:** `lib/features/vpn_logs/data/mappers/log_mapper.dart:6-9`
**Issue:** Сверка идёт с полными именами enum (`info`/`warning`/`error`). Требование терпимости
выполнено (неизвестное → `info`, без `ArgumentError`), но частый алиас `warn` (и `err`) попадёт в
`info` и потеряет уровень.
**Fix:** Нормализовать распространённые алиасы перед сопоставлением (`warn` → `warning`, `err` →
`error`), затем искать по имени enum.

### L-04: `connect`/`syncStatus` запускаются через `unawaited` без обработки ошибок

**Файлы:** `lib/main.dart:20`, `:77-78`, `:84-85`
**Issue:** `unawaited(dependencies.syncStatus())` и `unawaited(widget.dependencies.connectVpn(...))` в
debug harness глотают возвращаемый future. При реальном throw (после H-01 это будет typed `Failure`,
сейчас — сырой `PlatformException`) получится unhandled async error. В echo native не бросает, поэтому
low; но harness не переживёт переход на реальный слой.
**Fix:** Обернуть вызовы в `try/catch` (или `.catchError`) и показать ошибку в UI harness.

### L-05: `mapPlatformException` всегда возвращает `VpnStartFailure`

**Файл:** `lib/core/error/vpn_exception.dart:4-7`
**Issue:** Имя типа привязано к запуску. Как только `disconnect`/`getStatus` начнут пользоваться этим
маппером (см. H-01), ошибка остановки/статуса приедет как `VpnStartFailure` — вводит в заблуждение по
типу.
**Fix:** Ввести отдельные типы (`VpnStartFailure`/`VpnStopFailure`/`PlatformFailure`) или общий
`PlatformFailure` (тогда закрывается L-01) и маппить по контексту вызова.

### L-06: `CONNECTED` с `connectedSinceEpochMs == null` молча даёт эпоху 0 (1970)

**Файл:** `lib/features/vpn_connection/data/mappers/vpn_event_mapper.dart:9-13`
**Issue:** `DateTime.fromMillisecondsSinceEpoch(connectedSinceEpochMs ?? 0)` при `CONNECTED` без метки
времени подставит 1970-01-01 вместо явной ошибки/текущего времени. Native в echo всегда шлёт метку,
поэтому латентно, но UI-таймер «connected since» в следующей фазе покажет мусор.
**Fix:** Для `CONNECTED` при `null` подставлять `DateTime.now()` (native — источник истины, но fallback
разумнее эпохи) или логировать некорректный контракт.

---

_Reviewed: 2026-07-13T21:10:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
