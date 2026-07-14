---
phase: 05-ios-network-extension
plan: 01
subsystem: infra
tags: [ios, swift, network-extension, packet-tunnel, entitlements, app-group, xcodeproj, pbxproj]

# Dependency graph
requires:
  - phase: 01-pigeon
    provides: "ios/Runner target (bundle id com.example.vpnOko, team Z2GDTXHVZZ, Swift 5.0, objectVersion 54); Bridge/*.swift echo-мост"
provides:
  - "ios/PacketTunnel — app-extension таргет: PacketTunnelProvider (NEPacketTunnelProvider), Info.plist (packet-tunnel point), PacketTunnel.entitlements"
  - "ios/Runner/Runner.entitlements — packet-tunnel-provider + App Group group.com.example.vpnOko у контейнера"
  - "scripts/add_packet_tunnel_target.rb — идемпотентный xcodeproj-скрипт добавления NE-таргета"
  - "project.pbxproj: PacketTunnel target (com.example.vpnOko.PacketTunnel), PBXTargetDependency Runner->PacketTunnel, Embed App Extensions (PlugIns) перед Thin Binary, CODE_SIGN_ENTITLEMENTS обоих таргетов"
affects: [05-02, 05-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Новый нативный target в Flutter iOS через ruby-гем xcodeproj (не ручная правка pbxproj, не Xcode GUI): new_target(:app_extension) + source-фаза + dependency + Embed App Extensions copy-фаза"
    - "Embed App Extensions переставляется ПЕРЕД Thin Binary — снимает dependency-cycle Flutter build system + app-extension (ProcessInfoPlistFile <-> Copy .appex)"
    - "Extension вне Podfile: pods не тянутся в NE-процесс, embed не ломается"
    - "Узкий маршрут туннеля 10.111.222.0/24 (includedRoutes) — паритет с Android, интернет устройства в Connected не перехватывается"

key-files:
  created:
    - ios/PacketTunnel/PacketTunnelProvider.swift
    - ios/PacketTunnel/Info.plist
    - ios/PacketTunnel/PacketTunnel.entitlements
    - ios/Runner/Runner.entitlements
    - scripts/add_packet_tunnel_target.rb
  modified:
    - ios/Runner.xcodeproj/project.pbxproj

key-decisions:
  - "Embed App Extensions перемещена перед Thin Binary через build_phases.move — единственный способ собрать embedded extension без dependency-cycle на текущем Flutter build system"
  - "pbxproj коммитится без CocoaPods [CP]-фаз и без Pods-ссылки в workspace: HEAD-конвенция репо (pod-интеграция регенерируется pod install, не в git); Podfile.lock оставлен untracked как pod-артефакт"
  - "NSExtensionPointIdentifier = com.apple.networkextension.packet-tunnel (БЕЗ -provider); entitlement-значение packet-tunnel-provider — разные строки, обе точны"

patterns-established:
  - "Идемпотентный target-скрипт: повторный прогон выходит без дублей (проверка project.targets по имени + exit 0)"
  - "Entitlement packet-tunnel-provider + App Group group.com.example.vpnOko присутствуют идентично у ОБОИХ таргетов (Pitfall 4)"

requirements-completed: [IOS-02, IOS-04]

# Metrics
duration: 16min
completed: 2026-07-14
---

# Phase 5 Plan 01: NE-таргет PacketTunnel Summary

**App-extension таргет PacketTunnel (NEPacketTunnelProvider) с узким маршрутом 10.111.222.0/24, entitlements packet-tunnel-provider + App Group у обоих таргетов, добавлен идемпотентным ruby xcodeproj-скриптом; оба таргета собираются одной командой flutter build**

## Performance

- **Duration:** ~16 min
- **Started:** 2026-07-14T02:21:00Z
- **Completed:** 2026-07-14T02:36:30Z
- **Tasks:** 2
- **Files modified:** 6 (5 created, 1 modified)

## Accomplishments
- `PacketTunnelProvider.startTunnel` поднимает `NEPacketTunnelNetworkSettings` с `NEIPv4Settings` (адрес 10.0.0.2/32), узким `includedRoutes` 10.111.222.0/24 (паритет Android, не default route), DNS 1.1.1.1, MTU 1500; `stopTunnel` завершает teardown
- Entitlement `com.apple.developer.networking.networkextension = [packet-tunnel-provider]` и App Group `group.com.example.vpnOko` заданы идентично у Runner и PacketTunnel; `CODE_SIGN_ENTITLEMENTS` привязан у обоих таргетов
- `scripts/add_packet_tunnel_target.rb` (гем xcodeproj 1.27.0) идемпотентно создаёт app-extension таргет `com.example.vpnOko.PacketTunnel`, source-фазу, `PBXTargetDependency` Runner->PacketTunnel и «Embed App Extensions» (PlugIns) с `RemoveHeadersOnCopy`
- `flutter build ios --no-codesign --debug` зелёный: собран `Runner.app` со встроенным `Runner.app/PlugIns/PacketTunnel.appex`
- Info.plist extension объявляет корректную точку `com.apple.networkextension.packet-tunnel` (без ошибочного суффикса `-provider`); строка `com.example.vpn_oko` в фазе отсутствует

## Task Commits

Each task was committed atomically:

1. **Task 1: Skeleton-файлы PacketTunnel + entitlements обоих таргетов** - `032e6ec` (feat)
2. **Task 2: xcodeproj-скрипт добавления NE-таргета + привязка entitlements + компиляция** - `8e68fcf` (feat)

**Plan metadata:** docs-коммит SUMMARY + STATE + ROADMAP + REQUIREMENTS

## Files Created/Modified
- `ios/PacketTunnel/PacketTunnelProvider.swift` — `final class PacketTunnelProvider: NEPacketTunnelProvider`; startTunnel применяет узкий маршрут-паритет Android, stopTunnel завершает
- `ios/PacketTunnel/Info.plist` — NSExtension: point `com.apple.networkextension.packet-tunnel` + PrincipalClass `$(PRODUCT_MODULE_NAME).PacketTunnelProvider`, стандартные CFBundle-ключи
- `ios/PacketTunnel/PacketTunnel.entitlements` — packet-tunnel-provider + App Group group.com.example.vpnOko
- `ios/Runner/Runner.entitlements` — то же содержимое (entitlement у обоих таргетов, Pitfall 4)
- `scripts/add_packet_tunnel_target.rb` — идемпотентный xcodeproj-скрипт: target + build settings + source-фаза + dependency + Embed App Extensions (перед Thin Binary) + wire entitlements Runner
- `ios/Runner.xcodeproj/project.pbxproj` — PacketTunnel target, embed-фаза, CODE_SIGN_ENTITLEMENTS обоих таргетов (175 строк добавлено)

## Decisions Made
- **Embed App Extensions перед Thin Binary.** Скрипт `new_copy_files_build_phase` добавляет фазу в конец; в этом положении (после «Thin Binary») Flutter build system даёт dependency-cycle (`ProcessInfoPlistFile` Runner.app <-> Copy PacketTunnel.appex). Через `runner.build_phases.move(embed_phase, thin_binary_index)` фаза переставлена перед «Thin Binary» — цикл снят, сборка зелёная.
- **pbxproj без CocoaPods-артефактов.** HEAD репо не хранит `[CP]`-фазы, Pods-ссылку в workspace и Podfile.lock (pod-интеграция регенерируется `pod install`). После сборки pbxproj восстановлен из pristine и пересоздан скриптом, чтобы коммит содержал только PacketTunnel-добавления; `contents.xcworkspacedata` откачен к HEAD; `ios/Podfile.lock` оставлен untracked как pod-артефакт вне границ плана.
- **ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = NO** у extension: Swift-рантайм встраивает host-app, дублирование в .appex не нужно.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Dependency-cycle Flutter build + app-extension**
- **Found during:** Task 2 (первая сборка `flutter build ios --no-codesign --debug`)
- **Issue:** «Embed App Extensions», добавленная в конец build-фаз (после «Thin Binary»), давала цикл build system (`Copy PacketTunnel.appex` <-> `ProcessInfoPlistFile`/`Thin Binary`), сборка падала «Encountered error while building for device».
- **Fix:** В скрипт добавлена перестановка `runner.build_phases.move(embed_phase, thin_binary_index)` — Embed App Extensions переносится перед «Thin Binary». Скрипт остаётся идемпотентным и одноразово даёт корректный граф фаз.
- **Files modified:** scripts/add_packet_tunnel_target.rb, ios/Runner.xcodeproj/project.pbxproj
- **Verification:** `flutter build ios --no-codesign --debug` зелёный, `Runner.app/PlugIns/PacketTunnel.appex` собран; проверка порядка фаз (embed@5 < thin@6) в ruby-гейте.
- **Committed in:** `8e68fcf` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Фикс обязателен для компиляции embedded extension — цель Task 2 (оба таргета зелёные) без него недостижима. Ручная правка pbxproj НЕ применялась: решение внутри xcodeproj-скрипта (граница плана соблюдена). Без scope creep.

## Issues Encountered
- **pod install-артефакты после flutter build.** `flutter build` запустил `pod install`, добавивший в рабочий pbxproj `[CP]`-фазы, в workspace — Pods-ссылку, и сгенерировавший `Podfile.lock`. Эти артефакты вне границ плана и не в HEAD-конвенции репо. Решено восстановлением pristine pbxproj + повторным прогоном скрипта (детерминированный вывод, тот же собранный граф), откатом workspace к HEAD, оставлением Podfile.lock untracked. Коммит содержит только PacketTunnel-добавления.

## Known Stubs
- `PacketTunnelProvider` — skeleton по дизайну плана: без read-loop/счётчиков трафика (Open Q2) и без реального VPN-core (Out of Scope, REQUIREMENTS.md). Провайдер поднимает реальные `NEPacketTunnelNetworkSettings` и успешно завершает `startTunnel` — это закрывает IOS-02 на уровне компиляции. Реальный старт туннеля и живые статусы — device-checkpoint 05-03 (Simulator NE не исполняет, Pitfall 1). Стаб намеренный, не блокирует цель плана.

## Threat Model Coverage
- **T-5-03** (Spoofing/Elevation, load extension): entitlement `packet-tunnel-provider` у ОБОИХ таргетов + `CODE_SIGN_ENTITLEMENTS` в обоих build-конфигах — mitigated на уровне компиляции; реальная подпись — 05-03.
- **T-5-04** (Information Disclosure, App Group): `group.com.example.vpnOko` объявлен идентично у обоих; кредов в entitlements нет — mitigated.
- **T-5-01** (Info.plist/entitlements без секретов): файлы содержат только bundle id и capability-строки — accept, соблюдено.
- **T-5-SC** (installs): внешних пакетов не ставилось (Apple frameworks + уже установленный гем xcodeproj) — accept, соблюдено.

## User Setup Required
None — на уровне компиляции внешняя настройка не требуется. Реальный старт/подпись/TestFlight (portal App IDs + Network Extensions + App Groups capabilities) — device-checkpoint фазы (05-03, Pitfall 6).

## Next Phase Readiness
- Таргет `PacketTunnel` существует, оба таргета компилируются одной командой; entitlements + App Group привязаны у обоих (IOS-02/IOS-04 на уровне компиляции).
- Готово для 05-02: замена echo `VpnHostApiImpl` на реальный `NETunnelProviderManager` с `providerBundleIdentifier = com.example.vpnOko.PacketTunnel`; VpnStatusObserver (NEVPNStatusDidChange).
- Границы соблюдены: тронут только `ios/` (PacketTunnel target, entitlements, pbxproj через скрипт, сам скрипт). Dart/Android/мост-логика не менялись.

## Self-Check: PASSED

Все заявленные файлы существуют (PacketTunnelProvider.swift, Info.plist, PacketTunnel.entitlements, Runner.entitlements, add_packet_tunnel_target.rb, project.pbxproj); коммиты `032e6ec` и `8e68fcf` присутствуют в истории; `flutter build ios --no-codesign --debug` собрал Runner.app + встроенный PacketTunnel.appex.

---
*Phase: 05-ios-network-extension*
*Completed: 2026-07-14*
