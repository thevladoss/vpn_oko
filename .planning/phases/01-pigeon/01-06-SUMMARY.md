---
phase: 01-pigeon
plan: 06
subsystem: ios-bridge
tags: [ios, swift, pigeon, event-channel, host-api, appdelegate, scenedelegate, flutter-3.44, pbxproj]

# Dependency graph
requires:
  - "01-01: ios/Runner/Bridge/Messages.g.swift — VpnHostApiSetup.setUp, VpnEventsStreamHandler.register(with:instanceName:streamHandler:), PigeonEventSink<VpnEventMessage>, enum VpnStatusMessage lowerCamel"
provides:
  - "ios/Runner/Bridge/VpnHostApiImpl.swift — echo VpnHostApi (startVpn/stopVpn/getStatus)"
  - "ios/Runner/Bridge/VpnEventListener.swift — VpnEventsStreamHandler impl: main-queue доставка, replay lastStatus, снапшот"
  - "AppDelegate регистрирует HostApi + StreamHandler в didInitializeImplicitFlutterEngine через applicationRegistrar.messenger()"
  - "Bridge/*.swift входят в build sources таргета Runner (project.pbxproj)"
affects: [01-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "iOS-регистрация pigeon на шаблоне Flutter 3.44: engineBridge.applicationRegistrar.messenger() в didInitializeImplicitFlutterEngine, не rootViewController"
    - "централизованный main-queue эмиттер: DispatchQueue.main.async на каждый sink.success"
    - "native — источник истины по статусу: replay lastStatus в onListen + снапшот в getStatus"

key-files:
  created:
    - ios/Runner/Bridge/VpnHostApiImpl.swift
    - ios/Runner/Bridge/VpnEventListener.swift
  modified:
    - ios/Runner/AppDelegate.swift
    - ios/Runner.xcodeproj/project.pbxproj

key-decisions:
  - "echo LogMessage.level=\"info\" строковым литералом нижнего регистра — контракт с LogLevel.values.byName маппера 01-03 (симметрично Android 01-05)"
  - "события в Dart строго с DispatchQueue.main.async — единственная точка отправки в sink (Pitfall 1 / T-1-02)"
  - "три Bridge/*.swift добавлены в Runner.xcodeproj вручную через PBXFileReference+PBXBuildFile+группу Bridge (проект objectVersion 54, без синхронизированных групп)"

requirements-completed: [BRG-01, BRG-02, BRG-04]

# Metrics
duration: 2min
completed: 2026-07-13
---

# Phase 1 Plan 06: iOS echo-мост в Runner Summary

**Swift echo-мост pigeon в контейнер-приложении Runner: регистрация HostApi и event-стрима по шаблону Flutter 3.44 (SceneDelegate) через applicationRegistrar.messenger(), синтетический эмиттер с доставкой строго с main queue и replay последнего статуса**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-07-13T16:29:29Z
- **Completed:** 2026-07-13T16:32:08Z
- **Tasks:** 2
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments
- `VpnEventListener` реализует `VpnEventsStreamHandler`: `static let shared`, доставка `eventSink?.success` только внутри `DispatchQueue.main.async`, `onListen` реплеит `lastStatus`, `snapshot()` собирает `VpnStatusSnapshotMessage` из last-статуса и счётчиков rx/tx
- `VpnHostApiImpl` реализует `VpnHostApi`: `startVpn` эмитит синтетическую цепочку `LogMessage("starting vpn")` → `StatusChanged(.connecting)` → `LogMessage("tunnel up")` → `StatusChanged(.connected, connectedSinceEpochMs: now)`; `stopVpn` — `.disconnecting` → `.disconnected`; `getStatus()` отдаёт снапшот
- Все echo-`LogMessage` ставят `level: "info"` (нижний регистр) — совпадает с именами Dart-enum `LogLevel { info, warning, error }`, `byName` в маппере 01-03 не бросит ArgumentError на live-прогоне
- `AppDelegate.didInitializeImplicitFlutterEngine` регистрирует мост после `GeneratedPluginRegistrant`: `VpnHostApiSetup.setUp(binaryMessenger:api:)` + `VpnEventsStreamHandler.register(with:streamHandler:)` через `engineBridge.applicationRegistrar.messenger()` — путь `rootViewController` не задействован (закрыт Pitfall 4 / #185935)
- Три `Bridge/*.swift` (Messages.g.swift, VpnHostApiImpl.swift, VpnEventListener.swift) добавлены в Sources таргета Runner; `flutter build ios --no-codesign --debug` собрал `Runner.app` за 14.5s — линковка подтверждена сборкой, ручной шаг в Xcode для Plan 07 не нужен

## Task Commits

Each task was committed atomically:

1. **Task 1: echo VpnEventListener и VpnHostApiImpl (Swift)** - `44838bb` (feat)
2. **Task 2: регистрация в AppDelegate и членство файлов в таргете Runner** - `28b7972` (feat)

## Files Created/Modified
- `ios/Runner/Bridge/VpnEventListener.swift` — `VpnEventsStreamHandler` impl: main-queue доставка, replay lastStatus, snapshot из last-статуса + счётчиков
- `ios/Runner/Bridge/VpnHostApiImpl.swift` — echo `VpnHostApi`: startVpn/stopVpn эмитят цепочку через `VpnEventListener.shared.emit`, getStatus отдаёт снапшот, `level: "info"` явно
- `ios/Runner/AppDelegate.swift` — регистрация HostApi + StreamHandler в `didInitializeImplicitFlutterEngine`
- `ios/Runner.xcodeproj/project.pbxproj` — PBXFileReference + PBXBuildFile для трёх файлов, группа `Bridge` под Runner, записи в Sources build phase таргета Runner

## Точные символы (сверено с Messages.g.swift 01-01)
- `VpnHostApiSetup.setUp(binaryMessenger: FlutterBinaryMessenger, api: VpnHostApi?, messageChannelSuffix: String = "")`
- `VpnEventsStreamHandler.register(with: FlutterBinaryMessenger, instanceName: String = "", streamHandler: VpnEventsStreamHandler)`
- `PigeonEventChannelWrapper<ReturnType>.onListen(withArguments:sink:)` / `onCancel(withArguments:)` — override-точки; `PigeonEventSink<VpnEventMessage>.success(_:)`
- `enum VpnStatusMessage: Int, CaseIterable` lowerCamel (`.disconnected`/`.connecting`/`.connected`/`.disconnecting`/`.error`)
- `VpnEventMessage` — protocol (не sealed class); подтипы `StatusChangedMessage`/`LogMessage`/`TrafficChangedMessage`/`ErrorMessage` — struct; проверка типа через `event as? StatusChangedMessage`
- `LogMessage(text: String, timestampMillis: Int64, level: String)`; `VpnStatusSnapshotMessage(status:, connectedSinceEpochMs:?, rxBytes:, txBytes:)`; `ErrorMessage(code:, message:)` — поле `message`

## Decisions Made
- `level: "info"` строковым литералом нижнего регистра во всех echo-логах — жёсткий контракт с `LogLevel.values.byName` маппера 01-03; верхний/смешанный регистр запрещён (T-1-08). Симметрично Android 01-05.
- Доставка событий — единственная точка `DispatchQueue.main.async { self?.eventSink?.success(event) }`; прямой вызов sink из другого места отсутствует (T-1-02 / Pitfall 1).
- Регистрация через `engineBridge.applicationRegistrar.messenger()` в `didInitializeImplicitFlutterEngine`; `rootViewController`-путь не используется (T-1-07 / Pitfall 4).
- Членство файлов в таргете добавлено правкой pbxproj вручную: проект `objectVersion = 54` без `PBXFileSystemSynchronizedRootGroup`, поэтому папка `Bridge/` не подхватывается автоматически — созданы явные PBXFileReference/PBXBuildFile и группа `Bridge`. Сборка подтвердила линковку.

## Deviations from Plan

None — план выполнен точно как написан. Обе задачи закрыли acceptance-критерии без авто-фиксов; правка pbxproj прошла с первого раза (plutil-валидация OK, сборка зелёная), ручной шаг в Xcode для Plan 07 не потребовался.

## Threat Model Coverage
- **T-1-02** (DoS, main queue): `eventSink?.success` только внутри `DispatchQueue.main.async` — mitigated.
- **T-1-06** (гонка статуса): `onListen` реплеит `lastStatus`, `getStatus()` отдаёт снапшот — mitigated.
- **T-1-07** (регистрация): messenger из `applicationRegistrar.messenger()`, без `rootViewController` — mitigated.
- **T-1-08** (контракт level): `level: "info"` нижним регистром, guard `grep '"INFO"\|"Info"'` = 0 — mitigated.
- **T-1-01** (утечка кред): тексты echo синтетические, кред нет — mitigated.

## Issues Encountered
- Живой end-to-end прогон на iOS-симуляторе в этом заходе не выполнялся: верификация фазы на уровне codegen + компиляции достаточна (RESEARCH A5), Simulator Network Extension не относится к echo-мосту в Runner. Live-проверка echo — опционально Plan 07.

## User Setup Required
None — внешняя конфигурация не требуется.

## Next Phase Readiness
- iOS-echo моста компилируется и линкуется в Runner; BRG-01/BRG-02/BRG-04 закрыты на iOS симметрично Android (01-05).
- Границы фазы соблюдены: Network Extension / PacketTunnelProvider / entitlements / App Groups не тронуты (Phase 5); Dart/Android-файлы не менялись.
- Для Plan 07: членство Bridge/*.swift в таргете Runner зафиксировано в pbxproj, ручное добавление в Xcode НЕ требуется. Опциональная live-проверка echo на симуляторе iOS — вход в Plan 07 (checkpoint:human-verify).

## Self-Check: PASSED

Все заявленные файлы существуют (VpnEventListener.swift, VpnHostApiImpl.swift, AppDelegate.swift, project.pbxproj); коммиты `44838bb` и `28b7972` присутствуют в истории; `flutter build ios --no-codesign --debug` собрал Runner.app.

---
*Phase: 01-pigeon*
*Completed: 2026-07-13*
