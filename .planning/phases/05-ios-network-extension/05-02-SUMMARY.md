---
phase: 05-ios-network-extension
plan: 02
subsystem: ios-bridge
tags: [ios, swift, network-extension, netunnelprovidermanager, nevpnstatus, observer, pigeon, xcodeproj]

# Dependency graph
requires:
  - phase: 05-01
    provides: "PacketTunnel app-extension таргет (com.example.vpnOko.PacketTunnel), embed App Extensions, entitlements packet-tunnel-provider + App Group у обоих таргетов"
  - phase: 01-pigeon
    provides: "Messages.g.swift (VpnHostApi, StatusChangedMessage/LogMessage/ErrorMessage/VpnStatusSnapshotMessage), VpnEventListener (main-queue emit, snapshot)"
provides:
  - "ios/Runner/Bridge/VpnHostApiImpl.swift — реальный NETunnelProviderManager: load→configure→save→loadFromPreferences(reload)→startVPNTunnel; stopVpn через connection.stopVPNTunnel(); getStatus — снапшот listener; честный симулятор-путь (connecting → error + лог «NE недоступен»)"
  - "ios/Runner/Bridge/VpnStatusObserver.swift — NEVPNStatusDidChange observer, полный маппинг NEVPNStatus (connecting/connected/disconnecting/disconnected/reasserting/invalid/@unknown) → VpnEventListener.emit"
  - "scripts/add_status_observer_to_runner.rb — идемпотентный xcodeproj-скрипт членства VpnStatusObserver.swift в Runner.source_build_phase"
  - "project.pbxproj: VpnStatusObserver.swift в группе Bridge + build sources Runner"
affects: [05-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Реальный NETunnelProviderManager вместо echo: load→configure NETunnelProviderProtocol→save→loadFromPreferences (обязательный reload, Pitfall 3)→startVPNTunnel; ошибки доводятся через event-стрим (ErrorMessage + StatusChangedMessage.error), completion всегда .success(()) — контракт startVpn=Future<void>"
    - "Честный симулятор-путь через #if targetEnvironment(simulator): реальный loadAllFromPreferences (доказывает живой менеджер) без save/startVPNTunnel → connecting → error + лог «Network Extension недоступен в симуляторе» (Open Q1 вариант a)"
    - "NEVPNStatusDidChange observer в отдельном классе; emit только через VpnEventListener.emit (main queue) — прямой eventSink.success из фонового notification запрещён"
    - "Переиспользование существующего менеджера (managers?.first ?? new) + стабильный localizedDescription «Oko VPN» — не плодить профили в Settings (Pitfall 7)"

key-files:
  created:
    - ios/Runner/Bridge/VpnStatusObserver.swift
    - scripts/add_status_observer_to_runner.rb
  modified:
    - ios/Runner/Bridge/VpnHostApiImpl.swift
    - ios/Runner.xcodeproj/project.pbxproj

key-decisions:
  - "Честный симулятор-путь (Open Q1 вариант a) поверх echo: на симуляторе вызывается реальный loadAllFromPreferences и эмитится connecting → error + предупреждающий лог, доказывая живой NETunnelProviderManager вместо синтетической цепочки"
  - "loadFromPreferences (reload) обязателен между saveToPreferences и startVPNTunnel — иначе NEVPNError.configurationStale (Pitfall 3)"
  - "userId не читается/не логируется/не кладётся в providerConfiguration (только host+port) — T-5-01 mitigate, паритет Android"
  - "pbxproj коммитится без [CP]-фаз pod install и без Pods-ссылки в workspace — HEAD-конвенция репо (регенерируется pod install); Podfile.lock оставлен untracked"

patterns-established:
  - "Идемпотентный source-membership скрипт: повторный прогон выходит exit 0 при наличии файла в source_build_phase"
  - "Восстановление чистого pbxproj после flutter build (pod install добавляет [CP]-фазы): backup чистого pbxproj → build → restore backup + git checkout workspace"

requirements-completed: [IOS-01, IOS-03]

# Metrics
duration: 14min
completed: 2026-07-14
---

# Phase 5 Plan 02: Реальный NETunnelProviderManager-мост + VpnStatusObserver Summary

**Echo `VpnHostApiImpl` заменён реальным `NETunnelProviderManager` (load→save→reload→startVPNTunnel) с честным симулятор-путём ошибки, добавлен `VpnStatusObserver` (NEVPNStatusDidChange → VpnEventListener.emit); оба таргета компилируются под device и simulator**

## Performance

- **Duration:** ~14 min
- **Started:** 2026-07-14T05:39:00Z
- **Completed:** 2026-07-14T05:46:00Z
- **Tasks:** 2
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments
- `VpnHostApiImpl.startVpn` выполняет реальный флоу `NETunnelProviderManager`: `loadAllFromPreferences` → переиспользование/создание менеджера → `NETunnelProviderProtocol` (`providerBundleIdentifier = com.example.vpnOko.PacketTunnel`, `serverAddress = config.host`, `providerConfiguration = {host, port}`) → `saveToPreferences` → `loadFromPreferences` (обязательный reload) → `observer.attach` + `startVPNTunnel()`; все ошибки доводятся `ErrorMessage` + `StatusChangedMessage.error`, `completion` всегда `.success(())`
- Честный симулятор-путь (`#if targetEnvironment(simulator)`): реальный `loadAllFromPreferences` (доказывает живой вызов менеджера) без `save`/`startVPNTunnel`, эмиссия `connecting → error` + лог «Network Extension недоступен в симуляторе»; echo-цепочка `tunnel up`/синтетический `connected` удалена
- `VpnStatusObserver` подписан на `.NEVPNStatusDidChange` для `connection`, маппит все ветки `NEVPNStatus` (включая `reasserting`→connecting, `invalid`→error, `@unknown`→disconnected), `connectedDate`→`connectedSinceEpochMs`; эмиссия строго через `VpnEventListener.emit` (main queue)
- `stopVpn` через `connection.stopVPNTunnel()` (device) / прямой `disconnected` (simulator); `getStatus` возвращает синхронный `listener.snapshot()`
- `scripts/add_status_observer_to_runner.rb` идемпотентно добавляет `VpnStatusObserver.swift` в группу `Bridge` и `Runner.source_build_phase`
- `flutter build ios --no-codesign --debug` (device) и `flutter build ios --simulator --debug` зелёные — компилируются обе ветки `#if targetEnvironment(simulator)` (device-флоу и honest-error-path)
- Dart-регресс зелёный: `vpn_event_mapper_test` (NE-`ErrorMessage`/статусы → domain) + полный `flutter test` (147 тестов) + `flutter analyze` без замечаний

## Task Commits

Each task was committed atomically:

1. **Task 1: Реальный VpnHostApiImpl (NETunnelProviderManager) + VpnStatusObserver** - `7dcb48b` (feat)
2. **Task 2: Членство VpnStatusObserver в таргете Runner + сборка** - `0542d74` (feat)

**Plan metadata:** docs-коммит SUMMARY + STATE + ROADMAP + REQUIREMENTS

## Files Created/Modified
- `ios/Runner/Bridge/VpnHostApiImpl.swift` — echo заменён реальным `NETunnelProviderManager`; развилка платформы, приватные `fail(code:message:)` и `nowMillis()`; инъекция `listener` + `private let observer`
- `ios/Runner/Bridge/VpnStatusObserver.swift` — `final class`, `attach(NEVPNConnection)` подписка на `.NEVPNStatusDidChange` + начальный `report`, `deinit` снимает observer
- `scripts/add_status_observer_to_runner.rb` — идемпотентный xcodeproj-скрипт (гем 1.27.0): file-reference в группе Bridge + добавление в Runner source_build_phase
- `ios/Runner.xcodeproj/project.pbxproj` — `VpnStatusObserver.swift` в группе Bridge + build sources Runner (без [CP]-фаз)

## Decisions Made
- **Честный симулятор-путь поверх echo (Open Q1 вариант a).** На симуляторе NE не исполняется; вместо синтетической цепочки статусов вызывается реальный `loadAllFromPreferences` и эмитится `connecting → error` + предупреждающий лог. Это доказывает, что мост дёргает настоящий `NETunnelProviderManager` (IOS-01: статусы/логи из живого Swift-слоя), а не echo.
- **Reload обязателен (Pitfall 3).** `loadFromPreferences` между `saveToPreferences` и `startVPNTunnel` — иначе `NEVPNError.configurationStale`.
- **userId исключён из моста (T-5-01, паритет Android).** В `providerConfiguration` только `host`+`port`; `userId` не читается/не логируется. Grep-инвариант `! grep userId` зелёный.
- **pbxproj без pod-артефактов.** `flutter build` запускает `pod install`, добавляющий `[CP]`-фазы в pbxproj и Pods-ссылку в workspace. Чистый pbxproj (только членство observer) восстановлен из backup после сборки, workspace откачен к HEAD, `Podfile.lock` оставлен untracked — HEAD-конвенция репо (05-01).

## Deviations from Plan

Код реализован ровно по плану — Rules 1-4 не срабатывали. Одно наблюдение при верификации (не правка кода):

**1. [Finding — Environment] Приложение с embedded packet-tunnel NE appex не устанавливается на iOS Simulator**
- **Found during:** Task 2 (попытка runtime-наблюдения honest-error-path после сборки)
- **Observation:** `xcrun simctl install` собранного `Runner.app` (симулятор) падает `IXErrorDomain code=2 «Invalid placeholder attributes»`; приложение не появляется в контейнере, `launch` не проходит. Причина — встроенный `PacketTunnel.appex` с extension point `com.apple.networkextension.packet-tunnel`: симулятор отклоняет установку app с packet-tunnel NE appex (грань Pitfall 1 на слое install, не дефект моста). Info.plist обоих таргетов без нерезолвленных `$(...)`-плейсхолдеров, `NSExtensionPrincipalClass` резолвится в `PacketTunnel.PacketTunnelProvider` — плейсхолдеры ни при чём; ограничение самой платформы симулятора для NE.
- **Impact:** Интерактивное runtime-наблюдение honest-error-path (`connecting → error` + лог на Flutter-экране) на симуляторе недостижимо, т.к. app с NE appex туда не ставится. Appex добавлен в 05-01, ограничение предшествует 05-02.
- **Resolution:** Honest-error-path подтверждён на уровне компиляции — `flutter build ios --simulator --debug` зелёный, ветка `#if targetEnvironment(simulator)` компилируется; поведение детерминировано кодом. Полное runtime-наблюдение (и honest-error-path, и реальный happy-path connected) консолидируется в device/TestFlight-checkpoint 05-03 — там же, где и реальные переходы NEVPNStatus. Automated-гейт плана (build device+simulator + membership + Dart-регресс) полностью зелёный и от этого наблюдения не зависит.

**Total deviations:** 0 code deviations; 1 environment finding (runtime-демо → device 05-03).

## Issues Encountered
- **pod install-артефакты после flutter build.** `flutter build` (device и simulator) запускает `pod install`, добавляющий `[CP]`-фазы в рабочий pbxproj и Pods-ссылку в workspace. Решено backup чистого pbxproj до сборки → restore после + `git checkout` workspace; коммит содержит только членство `VpnStatusObserver.swift`. Проверено: `grep -c '[CP]'` = 0, membership через xcodeproj API зелёный.

## Known Stubs
None — мост реален (не echo). Единственное отложенное — интерактивный runtime-демо honest-error-path/happy-path, перенесённый в device-checkpoint 05-03 по природе NE (симулятор не исполняет и не устанавливает packet-tunnel appex, Pitfall 1). Код обеих веток скомпилирован.

## Threat Model Coverage
- **T-5-01** (Information Disclosure, providerConfiguration/логи): `userId` не читается/не логируется/не в `providerConfiguration` (только `host`+`port`); grep-инвариант зелёный — mitigated.
- **T-5-02** (Tampering, VPN-профиль): переиспользование `managers?.first ?? NETunnelProviderManager()` + стабильный `localizedDescription = "Oko VPN"` — не плодит профили (Pitfall 7) — mitigated.
- **T-5-05** (DoS, emit из notification): статусы идут только через `VpnEventListener.emit` (`DispatchQueue.main.async`); прямой `eventSink.success` из фонового notification отсутствует — mitigated.

## User Setup Required
None на уровне компиляции. Реальный старт туннеля, живые переходы NEVPNStatus и runtime-демо honest-error-path требуют физического устройства + portal App IDs (Network Extensions + App Groups) — device/TestFlight-checkpoint 05-03 (Pitfall 6).

## Next Phase Readiness
- Мост реален: `startVpn` (load→save→reload→startVPNTunnel), `stopVpn` (stopVPNTunnel), `getStatus` (snapshot); `VpnStatusObserver` доводит `NEVPNStatus` до Flutter. Готово к device-прогону 05-03.
- Границы соблюдены: тронут только `ios/Runner/Bridge` (VpnHostApiImpl, VpnStatusObserver) + pbxproj через скрипт. PacketTunnel target, Dart, Android не менялись. Pigeon-контракт и AppDelegate не изменены.
- 05-03 (device-checkpoint): portal-регистрация App IDs + capabilities, реальный старт туннеля, наблюдение живых NEVPNStatus-переходов и honest-error-path на устройстве.

## Self-Check: PASSED

- Файлы существуют: `ios/Runner/Bridge/VpnHostApiImpl.swift`, `ios/Runner/Bridge/VpnStatusObserver.swift`, `scripts/add_status_observer_to_runner.rb`, `ios/Runner.xcodeproj/project.pbxproj` (VpnStatusObserver.swift в build sources).
- Коммиты присутствуют: `7dcb48b` (Task 1), `0542d74` (Task 2).
- Гейты зелёные: `flutter build ios --no-codesign --debug` (device), `flutter build ios --simulator --debug` (simulator, honest-error-path branch компилируется), `flutter test` (147), `flutter analyze` (0 issues), grep-инварианты (NETunnelProviderManager/loadFromPreferences/com.example.vpnOko.PacketTunnel есть; userId/«tunnel up» отсутствуют).

---
*Phase: 05-ios-network-extension*
*Completed: 2026-07-14*
