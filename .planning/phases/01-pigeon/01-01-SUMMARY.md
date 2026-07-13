---
phase: 01-pigeon
plan: 01
subsystem: infra
tags: [pigeon, codegen, flutter_bloc, equatable, mocktail, very_good_analysis, event-channel, host-api, kotlin, swift, dart]

# Dependency graph
requires: []
provides:
  - "pigeons/vpn_api.dart — единый контракт моста (@HostApi VpnHostApi + @EventChannelApi VpnEventsApi поверх sealed VpnEventMessage)"
  - "lib/core/bridge/vpn_api.g.dart — Dart-клиент VpnHostApi + top-level Stream<VpnEventMessage> vpnEvents()"
  - "android/.../bridge/Messages.g.kt — Kotlin interface VpnHostApi (companion setUp), abstract VpnEventsStreamHandler, PigeonEventSink<T>"
  - "ios/Runner/Bridge/Messages.g.swift — Swift protocol VpnHostApi, class VpnHostApiSetup.setUp, VpnEventsStreamHandler, PigeonEventSink<ReturnType>"
  - "Утверждённый стек: flutter_bloc 9.1.1, equatable 2.1.0, pigeon 27.1.1, mocktail 1.0.5, very_good_analysis 10.3.0"
  - "analysis_options.yaml на very_good_analysis (public_member_api_docs:false, exclude **/*.g.dart + pigeons/**)"
affects: [01-02, 01-03, 01-04, 01-05, 01-06, 01-07]

# Tech tracking
tech-stack:
  added: [flutter_bloc 9.1.1, bloc 9.2.1, equatable 2.1.0, pigeon 27.1.1, mocktail 1.0.5, very_good_analysis 10.3.0]
  patterns: [pigeon единственный кодоген, суффикс Message для типов контракта, один event channel + sealed события, exclude codegen из строгого линта]

key-files:
  created: [pigeons/vpn_api.dart, lib/core/bridge/vpn_api.g.dart, android/app/src/main/kotlin/com/example/vpn_oko/bridge/Messages.g.kt, ios/Runner/Bridge/Messages.g.swift]
  modified: [pubspec.yaml, pubspec.lock, analysis_options.yaml]

key-decisions:
  - "Поле ErrorMessage.description переименовано в message: pigeon 27.1.1 отвергает description (конфликт с NSObject.description в Swift)"
  - "pigeons/** исключён из very_good_analysis наряду с **/*.g.dart — pigeon-схема имеет форсированную структуру (single-method abstract, mutable public fields)"
  - "non-null поля с required-конструктором сгенерировались корректно — переход на late (assumption A1) не понадобился"

patterns-established:
  - "Единый контракт моста в pigeons/vpn_api.dart, генерация dart run pigeon --input pigeons/vpn_api.dart"
  - "kotlinOut + swiftOut + dartOut без javaOut/objcOut (event channels падают на java/objc)"
  - "Кодоген (*.g.dart и pigeons/**) вне строгого линта; контракт-типы с суффиксом Message"

requirements-completed: [BRG-01, BRG-02]

# Metrics
duration: 5min
completed: 2026-07-13
---

# Phase 1 Plan 01: Фундамент и Pigeon-контракт Summary

**Типобезопасный контракт моста с кодогеном Dart/Kotlin/Swift (@HostApi + @EventChannelApi поверх sealed VpnEventMessage) и утверждённый стек на строгом very_good_analysis**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-07-13T15:20:31Z
- **Completed:** 2026-07-13T15:25:48Z
- **Tasks:** 2
- **Files modified:** 7 (4 created, 3 modified)

## Accomplishments
- Стек зафиксирован точными версиями: flutter_bloc 9.1.1, equatable 2.1.0 (runtime); pigeon 27.1.1, mocktail 1.0.5, very_good_analysis 10.3.0 (dev)
- Строгий линт на very_good_analysis с override public_member_api_docs:false и исключением кодогена; `flutter analyze` зелёный
- Контракт `pigeons/vpn_api.dart` сгенерирован в три языка без ошибок; `VpnEventsStreamHandler` присутствует в Kotlin и Swift — гипотеза STATE.md (генерация StreamHandler в pigeon 27.x) подтверждена, @FlutterApi-fallback не нужен
- Сняты точные имена сгенерированных символов для планов 03/05/06 (см. раздел «Сгенерированные символы»)

## Task Commits

Each task was committed atomically:

1. **Task 1: Зависимости стека и строгий линт** - `e9fba62` (chore)
2. **Task 2: Контракт pigeon и кодоген трёх языков** - `074d539` (feat)

## Files Created/Modified
- `pubspec.yaml` — добавлены flutter_bloc/equatable (runtime), pigeon/mocktail/very_good_analysis (dev); dev_deps отсортированы
- `pubspec.lock` — зафиксированы точные версии зависимостей
- `analysis_options.yaml` — include very_good_analysis; public_member_api_docs:false; exclude **/*.g.dart + pigeons/**
- `pigeons/vpn_api.dart` — контракт: enum VpnStatusMessage, DTO VpnConfigMessage/VpnStatusSnapshotMessage, sealed VpnEventMessage (+4 подкласса), @HostApi VpnHostApi, @EventChannelApi VpnEventsApi
- `lib/core/bridge/vpn_api.g.dart` — Dart-клиент (генерируется, коммитится)
- `android/app/src/main/kotlin/com/example/vpn_oko/bridge/Messages.g.kt` — Kotlin выход (package com.example.vpn_oko.bridge)
- `ios/Runner/Bridge/Messages.g.swift` — Swift выход

## Сгенерированные символы (вход для планов 03/05/06)

Открытый вопрос 1 закрыт: точные имена сняты с фактического кодогена. Assumptions A1/A2/A4 подтверждены.

### Dart — `lib/core/bridge/vpn_api.g.dart`
- HostApi-клиент: `class VpnHostApi` с конструктором `VpnHostApi({BinaryMessenger? binaryMessenger, String messageChannelSuffix = ''})` (в composition root вызывается как `VpnHostApi()`)
  - `Future<void> startVpn(VpnConfigMessage config)`
  - `Future<void> stopVpn()`
  - `Future<VpnStatusSnapshotMessage> getStatus()`
- Событийный стрим: top-level `Stream<VpnEventMessage> vpnEvents({String instanceName = ''})` (в composition root — `vpnEvents()`)
- enum `VpnStatusMessage { disconnected, connecting, connected, disconnecting, error }` — lowerCamel

### Kotlin — `Messages.g.kt` (package `com.example.vpn_oko.bridge`)
- HostApi: `interface VpnHostApi`, регистрация через companion `VpnHostApi.setUp(binaryMessenger, api, messageChannelSuffix = "")` (A2 подтверждён — без суффикса Setup)
  - `fun startVpn(config: VpnConfigMessage, callback: (Result<Unit>) -> Unit)`
  - `fun stopVpn(callback: (Result<Unit>) -> Unit)`
  - `fun getStatus(): VpnStatusSnapshotMessage`
- StreamHandler: `abstract class VpnEventsStreamHandler`, регистрация `VpnEventsStreamHandler.register(messenger, streamHandler, instanceName = "")`
  - override-точки: `onListen(p0: Any?, sink: PigeonEventSink<VpnEventMessage>)`, `onCancel(p0: Any?)`
- sink: `class PigeonEventSink<T>` — `success(value: T)`, `error(errorCode, errorMessage, errorDetails)`, `endOfStream()`
- enum `enum class VpnStatusMessage(val raw: Int)` — UPPER_CASE (A4 подтверждён): `DISCONNECTED(0)`, `CONNECTING(1)`, `CONNECTED(2)`, `DISCONNECTING(3)`, `ERROR(4)`
- внутренний служебный префикс из имени файла: `MessagesPigeonUtils`, `MessagesPigeonCodec` (downstream-код их не трогает; наследует `VpnEventsStreamHandler`)

### Swift — `Messages.g.swift`
- HostApi: `protocol VpnHostApi`, регистрация через `VpnHostApiSetup.setUp(binaryMessenger:api:messageChannelSuffix:)` (A2 подтверждён — суффикс Setup)
  - `func startVpn(config: VpnConfigMessage, completion: @escaping (Result<Void, Error>) -> Void)`
  - `func stopVpn(completion: @escaping (Result<Void, Error>) -> Void)`
  - `func getStatus() throws -> VpnStatusSnapshotMessage`
- StreamHandler: `class VpnEventsStreamHandler: PigeonEventChannelWrapper<VpnEventMessage>`, регистрация `VpnEventsStreamHandler.register(with: messenger, instanceName: "", streamHandler:)` — сигнатура `register(with:instanceName:streamHandler:)`; вызов из research `register(with:streamHandler:)` валиден (instanceName имеет дефолт)
  - override-точки: `func onListen(withArguments arguments: Any?, sink: PigeonEventSink<ReturnType>)`, `func onCancel(withArguments arguments: Any?)`
- sink: `class PigeonEventSink<ReturnType>` — `success(_ value:)`, `error(code:message:details:)`, `endOfStream()`
- enum `enum VpnStatusMessage: Int, CaseIterable` — lowerCamel: `.disconnected = 0 ... .error = 4`

### Общие типы контракта (все три языка)
`VpnConfigMessage(host, port, userId, serverName)`, `VpnStatusSnapshotMessage(status, connectedSinceEpochMs?, rxBytes, txBytes)`, sealed `VpnEventMessage` → `StatusChangedMessage(status, connectedSinceEpochMs?)`, `LogMessage(text, timestampMillis, level)`, `TrafficChangedMessage(rxBytes, txBytes)`, `ErrorMessage(code, message)`.

## Decisions Made
- Поле `ErrorMessage.description` → `message`: pigeon 27.1.1 отвергает `description` (конфликт с `NSObject.description`/`CustomStringConvertible` в Swift). Новое имя ложится на доменный `VpnError.message`.
- `pigeons/**` исключён из very_good_analysis: pigeon-схема требует single-method abstract (`@EventChannelApi`), mutable public fields и длинный путь в `kotlinOut` — конфликт с VGA-правилами, аналогично исключению генерируемых файлов.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Переименование поля ErrorMessage.description → message**
- **Found during:** Task 2 (кодоген pigeon)
- **Issue:** `dart run pigeon` падал: `Field "description" is not allowed in class "ErrorMessage" because it conflicts with Swift's NSObject/CustomStringConvertible.description property`. План брал имя из Code Example 1, где эта коллизия не проявилась
- **Fix:** Поле переименовано в `message` в контракте; повторный кодоген прошёл без ошибок
- **Files modified:** pigeons/vpn_api.dart (+ три перегенерированных выхода)
- **Verification:** `dart run pigeon --input pigeons/vpn_api.dart` без ошибок; три файла созданы
- **Committed in:** `074d539` (Task 2 commit)

**2. [Rule 3 - Blocking] Исключение pigeons/** из строгого линта**
- **Found during:** Task 2 (verify — flutter analyze)
- **Issue:** very_good_analysis выдавал 4 info на `pigeons/vpn_api.dart` (one_member_abstracts на @EventChannelApi, lines_longer_than_80_chars на kotlinOut-пути, always_put_required_named_parameters_first на DTO). Структура форсирована pigeon, руками не исправляется без нарушения контракта
- **Fix:** В `analysis_options.yaml` добавлен `exclude: pigeons/**` (аналогично `**/*.g.dart`)
- **Files modified:** analysis_options.yaml
- **Verification:** `flutter analyze` → No issues found
- **Committed in:** `074d539` (Task 2 commit)

**3. [Rule 1 - Style] Сортировка dev_dependencies**
- **Found during:** Task 1 (verify — flutter analyze)
- **Issue:** `sort_pub_dependencies` info на dev_dependencies после `flutter pub add`
- **Fix:** dev_dependencies отсортированы по алфавиту
- **Files modified:** pubspec.yaml
- **Verification:** `flutter analyze` → No issues found
- **Committed in:** `e9fba62` (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (2 blocking, 1 style)
**Impact on plan:** Оба blocking-фикса — необходимая адаптация к фактическому поведению pigeon 27.1.1; контракт и границы фазы сохранены (VLESS-поля не добавлены, стек не расширен). Scope creep отсутствует.

## Issues Encountered
- Ассумпшн A1 (non-null поля data-классов): подтверждён без фикса — pigeon 27.1.1 сгенерировал non-null поля с required-конструктором корректно, переход на `late` не понадобился.

## User Setup Required
None — внешняя конфигурация сервисов не требуется.

## Next Phase Readiness
- Контракт и сгенерированные символы зафиксированы; планы 02 (домен/data), 03 (Android echo), 05/06 (iOS echo) пишутся без разведки имён.
- iOS: файл `ios/Runner/Bridge/Messages.g.swift` создан на диске, но НЕ добавлен в `Runner.xcodeproj` (регистрация в проекте — задача iOS-плана 05/06, вне границ 01-01).
- Границы фазы соблюдены: VpnService, Network Extension, UI, VLESS-поля, SDK-бампы и VPN-permissions не тронуты.

## Self-Check: PASSED

Все заявленные файлы существуют (pubspec.yaml, analysis_options.yaml, pigeons/vpn_api.dart, три сгенерированных выхода, 01-01-SUMMARY.md); коммиты `e9fba62` и `074d539` присутствуют в истории.

---
*Phase: 01-pigeon*
*Completed: 2026-07-13*
