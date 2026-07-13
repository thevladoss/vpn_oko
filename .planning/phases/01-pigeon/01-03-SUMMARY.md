---
phase: 01-pigeon
plan: 03
subsystem: data
tags: [bridge, event-channel, demux, sealed, mapper, datasource, mocktail, tdd, clean-architecture]

# Dependency graph
requires:
  - "01-01: сгенерированный vpn_api.g.dart — VpnHostApi, sealed VpnEventMessage (StatusChangedMessage/LogMessage/TrafficChangedMessage/ErrorMessage), VpnConfigMessage/VpnStatusSnapshotMessage, top-level vpnEvents(); поле ErrorMessage.message"
  - "01-02: доменные entity — sealed VpnState (5 подтипов), TrafficStats, LogEntry + enum LogLevel {info, warning, error}"
provides:
  - "lib/core/bridge/vpn_bridge.dart — VpnBridge: единственная подписка на Stream<VpnEventMessage>, exhaustive switch по sealed, четыре broadcast-стрима, проксирование VpnHostApi, dispose"
  - "lib/features/vpn_connection/data/mappers/vpn_event_mapper.dart — statusToEntity (5 статусов), trafficToEntity"
  - "lib/features/vpn_logs/data/mappers/log_mapper.dart — logToEntity (LogLevel case-insensitive + fallback info, без byName)"
  - "lib/features/vpn_connection/data/datasources/vpn_native_datasource.dart — states/traffic (доменные стримы), currentStatus/start/stop"
  - "lib/features/vpn_logs/data/datasources/log_native_datasource.dart — logs (Stream<LogEntry>)"
  - "test/helpers/mock_vpn_host_api.dart — MockVpnHostApi (mocktail) для всех планов фазы"
affects: [01-04, 01-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Единственный владелец подписки на event channel (VpnBridge); фичи читают broadcast-стримы, а не вызывают vpnEvents() (анти-паттерн 4)"
    - "Демультиплекс через exhaustive switch по sealed VpnEventMessage (полнота проверяется компилятором, без default)"
    - "Инициализирующий формал private-поля через named-параметр (required this._hostApi) — публичное имя hostApi, снимает prefer_initializing_formals без inline-ignore"
    - "Толерантный резолв enum: LogLevel.values.firstWhere(name==toLowerCase, orElse: info) вместо byName"

key-files:
  created:
    - lib/core/bridge/vpn_bridge.dart
    - lib/features/vpn_connection/data/mappers/vpn_event_mapper.dart
    - lib/features/vpn_logs/data/mappers/log_mapper.dart
    - lib/features/vpn_connection/data/datasources/vpn_native_datasource.dart
    - lib/features/vpn_logs/data/datasources/log_native_datasource.dart
    - test/core/bridge/vpn_bridge_test.dart
    - test/features/vpn_connection/data/mappers/vpn_event_mapper_test.dart
    - test/features/vpn_logs/data/mappers/log_mapper_test.dart
    - test/helpers/mock_vpn_host_api.dart
  modified: []

key-decisions:
  - "VpnBridge принимает Stream и VpnHostApi через конструктор (инъекция) — vpnEvents() подставляется в composition root (план 04), тесты подают StreamController + MockVpnHostApi; платформа не нужна"
  - "Тест единственной подписки использует single-subscription StreamController: повторный listen источника бросает StateError — прямая проверка T-1-04 (бридж — единственный consumer)"
  - "Конструктор через required this._hostApi (initializing formal): публичное имя параметра остаётся hostApi, контракт composition root цел, prefer_initializing_formals снят без комментария-ignore"
  - "logToEntity резолвит уровень firstWhere+orElse (T-1-09): 'INFO'/'Info' → info, 'debug'/'' → info fallback, ArgumentError исключён; голый byName не используется (guard = 0)"
  - "currentStatus() отдаёт VpnStatusSnapshotMessage (DTO) — маппинг снапшота отложен в репозиторий (Code Example 6, план 04); реактивные стримы (states/traffic/logs) уже отдают чистые entity"

requirements-completed: [BRG-02, BRG-03]

# Metrics
duration: 5min
completed: 2026-07-13
---

# Phase 1 Plan 03: Мост VpnBridge, мапперы DTO→entity и датасорсы Summary

**Единственная подписка на event channel с демультиплексом по sealed VpnEventMessage и мапперы, изолирующие домен от кодогена; маппер уровня лога устойчив к регистру и неизвестным значениям**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-07-13T16:38:46Z
- **Completed:** 2026-07-13T16:43:18Z
- **Tasks:** 2 (обе TDD, RED→GREEN)
- **Files modified:** 9 (9 created)

## Accomplishments
- `VpnBridge` — единственный владелец подписки на `Stream<VpnEventMessage>`: один `listen`, `_dispatch` через exhaustive `switch` по sealed (четыре ветки, без default), четыре broadcast-стрима `statusEvents/logEvents/trafficEvents/errorEvents`, проксирование `startVpn/stopVpn/getStatus` в `VpnHostApi`, `dispose` отменяет подписку и закрывает контроллеры
- Демультиплекс проверен: каждый тип события попадает только в свой стрим, порядок внутри стрима сохраняется, повторная подписка на источник бросает `StateError` (T-1-04 — единственный consumer)
- Мапперы `statusToEntity` (пять статусов, `connected` с epoch из `connectedSinceEpochMs`, null → epoch 0), `trafficToEntity`, `logToEntity` (уровень case-insensitive с fallback на `info`)
- Датасорсы `VpnNativeDatasource`/`LogNativeDatasource` адаптируют мост под фичи: реактивные геттеры `states/traffic/logs` отдают доменные entity через `.map(mapper)`, DTO в реактивный путь не протекает
- Общий хелпер `MockVpnHostApi` (mocktail) — вход для планов 04/07; 17 тестов зелёные, `flutter analyze` по проекту чист

## Task Commits

Обе задачи — TDD, прошли полный цикл RED→GREEN:

1. **Task 1 (RED): падающие тесты demux и проксирования VpnBridge** - `e8e0a0f` (test)
2. **Task 1 (GREEN): VpnBridge — одна подписка, demux, прокси HostApi** - `7da94bd` (feat)
3. **Task 2 (RED): падающие тесты мапперов DTO→entity** - `3e2a366` (test)
4. **Task 2 (GREEN): мапперы и датасорсы обеих фич** - `57980bb` (feat)

## Files Created/Modified
- `lib/core/bridge/vpn_bridge.dart` — `VpnBridge` (Code Example 5): инъекция stream+hostApi, exhaustive switch, четыре broadcast-контроллера, dispose
- `lib/features/vpn_connection/data/mappers/vpn_event_mapper.dart` — `statusToEntity`/`trafficToEntity`
- `lib/features/vpn_logs/data/mappers/log_mapper.dart` — `logToEntity` (firstWhere+orElse, не byName)
- `lib/features/vpn_connection/data/datasources/vpn_native_datasource.dart` — `states/traffic` + `currentStatus/start/stop`
- `lib/features/vpn_logs/data/datasources/log_native_datasource.dart` — `logs`
- `test/core/bridge/vpn_bridge_test.dart` — demux, порядок, единственная подписка, проксирование через verify
- `test/features/vpn_connection/data/mappers/vpn_event_mapper_test.dart` — пять статусов + null-connectedSince + traffic
- `test/features/vpn_logs/data/mappers/log_mapper_test.dart` — три уровня, верхний регистр, неизвестный уровень
- `test/helpers/mock_vpn_host_api.dart` — `MockVpnHostApi extends Mock implements VpnHostApi`

## Decisions Made
- Инъекция `Stream<VpnEventMessage>` + `VpnHostApi` в конструктор — реальный `vpnEvents()` связывается в composition root (план 04), unit-тест подаёт `StreamController` и `MockVpnHostApi`, платформа не требуется
- Тест единственной подписки использует single-subscription `StreamController` (не `.broadcast()`): повторный `source.stream.listen` бросает `StateError` — прямое подтверждение того, что бридж держит ровно одну подписку (T-1-04). Демультиплекс при этом раздаётся через собственные broadcast-контроллеры бриджа
- `logToEntity` резолвит уровень `LogLevel.values.firstWhere((l) => l.name == m.level.toLowerCase(), orElse: () => LogLevel.info)` — заложено планом поверх Code Example 7 (там был `byName`) под контракт echo-эмиттеров 01-05/01-06 (T-1-09)
- `currentStatus()` отдаёт снапшот-DTO без маппинга — по Code Example 6 репозиторий вызовет `.toEntity()` (план 04). Реактивные стримы уже чисто доменные

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Инициализирующий формал вместо initializer-list под prefer_initializing_formals**
- **Found during:** Task 1 (GREEN — flutter analyze)
- **Issue:** конструктор `VpnBridge({required VpnHostApi hostApi, ...}) : _hostApi = hostApi` давал info `prefer_initializing_formals` (very_good_analysis). Классическое `this._hostApi` для private-поля предполагалось невозможным в named-параметре
- **Fix:** проверено на Dart 3.44 — named initializing formal `required this._hostApi` компилируется, а публичное имя параметра на call-site выводится без подчёркивания (`hostApi:`), что совпадает с контрактом composition root. Конструктор переписан на `required this._hostApi`; строка сигнатуры разбита под лимит 80
- **Files modified:** lib/core/bridge/vpn_bridge.dart
- **Verification:** `flutter analyze` → No issues found; 6 тестов бриджа зелёные; call-site `hostApi:` в тестах не изменился
- **Committed in:** `7da94bd` (Task 1 GREEN)

### Test-design note

**2. [Rule 1 - Test rigor] single-subscription источник вместо `.broadcast()` в тесте бриджа**
- **Found during:** Task 1 (написание теста)
- **Issue:** action плана предлагал подать `StreamController.broadcast()`, но behavior требует подтвердить «не создаётся вторая подписка». Broadcast-источник этого не ловит (повторный listen допустим)
- **Fix:** источник в тесте — single-subscription `StreamController`; тест `bridge is the single consumer` проверяет `throwsStateError` на повторный listen. Demux/порядок/проксирование покрыты без изменений. Прямое подтверждение T-1-04
- **Files modified:** test/core/bridge/vpn_bridge_test.dart
- **Verification:** 6 тестов зелёные

### Convention note

**3. Язык per-task коммитов**
- Per-task коммиты (`test`/`feat`) написаны по-английски; глобальное правило пользователя предполагает русские commit messages. Финальный docs-коммит — на русском. История per-task не переписывалась (rebase на main рискован)

---

**Total deviations:** 1 auto-fixed (blocking), 1 test-design note, 1 convention note
**Impact on plan:** контракт и границы сохранены — VpnBridge, мапперы, датасорсы соответствуют интерфейсам плана; тронуты только data/bridge + Wave-0 тесты, domain/native/presentation не затронуты

## Known Stubs
- `statusToEntity(status == error)` → `VpnError('unknown')` (по Code Example 7). `StatusChangedMessage` не несёт текста ошибки — детальное сообщение приходит отдельным событием `ErrorMessage` через `errorEvents` (поле `message`). Реконсиляция статуса и текста ошибки — задача репозитория (план 04). Плейсхолдер намеренный, до UI в этой фазе не доходит

## Threat Model Compliance
- **T-1-04 (двойная подписка):** ровно один `events.listen` в конструкторе; тест `throwsStateError` на повторный listen источника
- **T-1-09 (парсинг level):** `firstWhere`+`orElse: info`, `byName` отсутствует (guard `grep -c byName == 0`); тесты на верхний регистр и неизвестный уровень зелёные, ArgumentError исключён
- **T-1-01 (утечка секретов):** маппер не логирует и не трансформирует текст лога, только переносит; секреты не вводятся

## User Setup Required
None — чистый Dart-модуль, тесты идут без платформы и внешней конфигурации.

## Next Phase Readiness
- BRG-02 (демультиплекс типизированных стримов) и BRG-03 (изоляция домена мапперами) закрыты на уровне Dart-модуля и unit-тестов
- План 04 связывает `VpnBridge(hostApi: VpnHostApi(), events: vpnEvents())` в composition root, реализует `VpnRepositoryImpl`/`LogRepositoryImpl` поверх датасорсов, добавляет маппинг снапшота (`VpnStatusSnapshotMessage.toEntity()`)
- Границы соблюдены: domain/native/presentation/VLESS не тронуты

## Self-Check: PASSED

Все девять заявленных файлов и SUMMARY существуют на диске; коммиты `e8e0a0f`, `7da94bd`, `3e2a366`, `57980bb` присутствуют в истории; 17 тестов зелёные, `flutter analyze` по проекту — No issues found.

---
*Phase: 01-pigeon*
*Completed: 2026-07-13*
