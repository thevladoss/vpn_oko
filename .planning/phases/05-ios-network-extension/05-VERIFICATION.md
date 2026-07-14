---
phase: 05-ios-network-extension
verified: 2026-07-14T06:20:00Z
status: passed
score: 4/4 must-haves verified (automatable level)
has_blocking_gaps: false
overrides_applied: 0
mode: mvp
automatable_scope: "компиляция обоих таргетов + корректность строк + Dart-маппинг NE"
device_checkpoint: "реальный туннель на устройстве через TestFlight — manual-only (симулятор NE не исполняет; ограничение платформы Apple, не gap фазы)"
human_verification:
  - test: "TestFlight: Connect на устройстве → системный VPN-диалог → Connecting → Connected, профиль «Oko VPN» в Settings"
    expected: "NETunnelProviderManager.startVPNTunnel → PacketTunnelProvider.startTunnel → NEPacketTunnelNetworkSettings применяются (узкий маршрут 10.111.222.0/24); интернет устройства работает"
    why_human: "iOS Simulator не исполняет packet-tunnel NE (simctl install падает Invalid placeholder attributes); реальный туннель требует физического устройства"
  - test: "TestFlight: смена статуса туннеля доходит до Flutter-экрана; Disconnect → Disconnected, значок VPN исчезает"
    expected: "NEVPNStatus observer доводит переходы через VpnEventListener до Flutter (IOS-03 runtime)"
    why_human: "Реальные NEVPNStatus-переходы возникают только при живом NE-процессе на устройстве"
  - test: "Portal: два App ID (com.example.vpnOko + com.example.vpnOko.PacketTunnel) с Network Extensions + App Groups; archive + upload в TestFlight"
    expected: "Подпись обоих таргетов проходит без «No profiles for …PacketTunnel»; билд в TestFlight"
    why_human: "Требует Apple Developer portal + подпись distribution — вне среды агента"
---

# Phase 5: iOS-мост и Network Extension — Verification Report

**Phase Goal:** Демо на iOS работает: статусы и логи идут из Swift-слоя, туннель стартует и останавливается через реальный Network Extension таргет (PacketTunnelProvider + NETunnelProviderManager). Проверка на устройстве через TestFlight.
**Verified:** 2026-07-14T06:20:00Z
**Status:** passed (автоматизируемый уровень — 4/4 требования; device-runtime = TestFlight-checkpoint пользователя)
**Re-verification:** No — initial verification
**Mode:** mvp

## Граница проверки

Природа Network Extension: реальный туннель не исполняется на симуляторе (`simctl install` приложения со встроенным packet-tunnel appex падает `Invalid placeholder attributes` — ограничение платформы Apple, подтверждено оркестратором в 05-02/05-03). Автоматизируемый уровень = компиляция обоих таргетов + корректность строк + Dart-маппинг NE — проверен здесь заново, руками верификатора. Реальный старт туннеля, живые NEVPNStatus-переходы и archive/TestFlight — checkpoint пользователя на устройстве (честно зафиксирован в 05-03/DOC-02, не gap фазы).

## Goal Achievement

### Observable Truths (Success Criteria из ROADMAP)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Connect ведёт через Connecting к Connected, статусы/логи из Swift-слоя видны на Flutter (IOS-01) | ✓ VERIFIED (автоуровень) | `VpnHostApiImpl.swift` вызывает реальный `NETunnelProviderManager` (load→save→loadFromPreferences→startVPNTunnel), echo убран (`grep 'tunnel up'`=0); честный симулятор-путь `connecting→error`+лог через реальный `loadAllFromPreferences`; `getStatus`→snapshot. Компилируется (build green). Dart-маппинг: 147/147 тестов. Happy-path Connected runtime = device. |
| 2 | Extension-таргет PacketTunnelProvider стартует/останавливает туннель через NETunnelProviderManager, NEPacketTunnelNetworkSettings применяются (IOS-02) | ✓ VERIFIED (автоуровень) | `PacketTunnelProvider: NEPacketTunnelProvider`, `startTunnel`→`setTunnelNetworkSettings` с узким маршрутом `10.111.222.0/24` (не default route), `stopTunnel`. Target `PacketTunnel` (app-extension) существует, встроен в Runner; собранный `Runner.app/PlugIns/PacketTunnel.appex` содержит Mach-O arm64 бинарь. Реальный старт = device. |
| 3 | Смена статуса из extension доходит до Flutter через NEVPNStatus observer (IOS-03) | ✓ VERIFIED (автоуровень) | `VpnStatusObserver.swift` подписан на `.NEVPNStatusDidChange`, маппит все ветки `NEVPNStatus` (connected/connecting/reasserting/disconnecting/disconnected/invalid/@unknown)→`VpnEventListener.emit`. `VpnEventListener.swift` не изменён (git подтверждает). В build sources Runner. Runtime-переходы = device. |
| 4 | Packet Tunnel entitlements + App Group у обоих таргетов; архив готов к TestFlight (IOS-04) | ✓ VERIFIED (автоуровень) | Оба `.entitlements`: `packet-tunnel-provider` + `group.com.example.vpnOko`. Info.plist: `com.apple.networkextension.packet-tunnel` (без `-provider`). `CODE_SIGN_ENTITLEMENTS` привязан у обоих таргетов в pbxproj. DOC-02 handoff существует. Portal/archive/TestFlight = шаги пользователя. |

**Score:** 4/4 truths verified на автоматизируемом уровне. Device-runtime — checkpoint пользователя (не gap).

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ios/PacketTunnel/PacketTunnelProvider.swift` | NEPacketTunnelProvider: startTunnel/stopTunnel | ✓ VERIFIED | 26 строк; `final class PacketTunnelProvider: NEPacketTunnelProvider`; узкий маршрут `10.111.222.0/24`; компилируется (appex Mach-O собран) |
| `ios/PacketTunnel/Info.plist` | NSExtension packet-tunnel point + PrincipalClass | ✓ VERIFIED | `NSExtensionPointIdentifier=com.apple.networkextension.packet-tunnel` (без `-provider`); резолвится в собранном appex |
| `ios/PacketTunnel/PacketTunnel.entitlements` | packet-tunnel-provider + App Group | ✓ VERIFIED | оба ключа присутствуют |
| `ios/Runner/Runner.entitlements` | packet-tunnel-provider + App Group у контейнера | ✓ VERIFIED | идентичное содержимое (Pitfall 4) |
| `ios/Runner/Bridge/VpnHostApiImpl.swift` | Реальный NETunnelProviderManager load→save→reload→start | ✓ VERIFIED | 100 строк; `NETunnelProviderManager`, `loadFromPreferences` (reload), `#if targetEnvironment(simulator)`; echo/`userId` отсутствуют |
| `ios/Runner/Bridge/VpnStatusObserver.swift` | NEVPNStatusDidChange observer → emit | ✓ VERIFIED | 45 строк; полный маппинг NEVPNStatus; `emit` только через `listener` (нет `eventSink`) |
| `scripts/add_packet_tunnel_target.rb` | Идемпотентный xcodeproj-скрипт NE-таргета | ✓ VERIFIED | `ruby -c` OK; `new_target` присутствует |
| `scripts/add_status_observer_to_runner.rb` | Идемпотентный скрипт членства observer | ✓ VERIFIED | `ruby -c` OK; `source_build_phase` присутствует |
| `ios/Runner.xcodeproj/project.pbxproj` | PacketTunnel target + embed + entitlements | ✓ VERIFIED | xcodeproj API: app-extension target, Runner→PacketTunnel dependency, Embed App Extensions (PlugIns) перед Thin Binary, оба CODE_SIGN_ENTITLEMENTS |
| `.planning/phases/05-ios-network-extension/DOC-02-ios-setup.md` | Handoff-заметка для DOC-02 фазы 6 | ✓ VERIFIED | 5 разделов; строки `group.com.example.vpnOko`/`com.example.vpnOko.PacketTunnel`/`packet-tunnel-provider` есть, `com.example.vpn_oko` нет |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `VpnHostApiImpl.swift` | `NETunnelProviderManager.loadAllFromPreferences` | старт: загрузка профиля | ✓ WIRED | вызов в обеих ветках `#if` |
| `VpnHostApiImpl.swift` | `com.example.vpnOko.PacketTunnel` | `proto.providerBundleIdentifier` | ✓ WIRED | строка присутствует (device-ветка) |
| `VpnStatusObserver.swift` | `VpnEventListener` | `emit(StatusChangedMessage)` | ✓ WIRED | `listener.emit(...)` во всех ветках маппинга |
| `VpnStatusObserver.swift` | `.NEVPNStatusDidChange` | NotificationCenter observer | ✓ WIRED | `addObserver(forName: .NEVPNStatusDidChange, object: connection)` |
| `project.pbxproj` | `com.example.vpnOko.PacketTunnel` | PRODUCT_BUNDLE_IDENTIFIER | ✓ WIRED | 3 вхождения |
| `project.pbxproj` | `Runner.entitlements` / `PacketTunnel.entitlements` | CODE_SIGN_ENTITLEMENTS | ✓ WIRED | оба привязаны |
| `project.pbxproj` | `PacketTunnel.appex` | Embed App Extensions (PlugIns) + PBXTargetDependency | ✓ WIRED | embed@6 < thin@7; appex собран в Runner.app/PlugIns |
| device Connect | `PacketTunnelProvider.startTunnel` | startVPNTunnel → системный NE-процесс | ⏸ DEVICE | код-путь скомпилирован; runtime — TestFlight-checkpoint |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `VpnStatusObserver` | `connection.status` | `NEVPNConnection` (live NE) | На устройстве — да; симулятор NE не исполняет | ✓ FLOWING (device) / детерминирован кодом |
| `VpnHostApiImpl` симулятор-путь | ErrorMessage/StatusChanged | реальный `loadAllFromPreferences` callback → `fail()` | Да (эмитит error+лог, доказывает живой менеджер) | ✓ FLOWING |
| `getStatus` | `listener.snapshot()` | `VpnEventListener.lastStatus` (обновляется observer'ом) | Да | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Оба таргета компилируются | `flutter build ios --no-codesign --debug` | ✓ Built Runner.app (10.4s) | ✓ PASS |
| Embedded appex собран | `ls Runner.app/PlugIns/PacketTunnel.appex` + `file …/PacketTunnel` | Mach-O 64-bit arm64 | ✓ PASS |
| Appex Info.plist резолвится | PlistBuddy NSExtensionPointIdentifier/PrincipalClass/BundleId | com.apple.networkextension.packet-tunnel / PacketTunnel.PacketTunnelProvider / com.example.vpnOko.PacketTunnel | ✓ PASS |
| Dart-статик-анализ | `flutter analyze` | No issues found | ✓ PASS |
| Dart-регресс + NE-маппинг | `flutter test` | 147/147 passed | ✓ PASS |
| Target graph | `xcodeproj` API | app-extension + dep + embed + sources OK | ✓ PASS |
| Реальный туннель на устройстве | TestFlight | — | ? SKIP (device checkpoint) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| IOS-01 | 05-02, 05-03 | Swift-мост startVpn/stopVpn/getStatus + статусы/логи из Swift | ✓ SATISFIED (автоуровень) | реальный NETunnelProviderManager, честный симулятор-путь, компиляция, Dart-маппинг; happy-path runtime — device |
| IOS-02 | 05-01, 05-02, 05-03 | NE-таргет PacketTunnelProvider start/stop через NETunnelProviderManager | ✓ SATISFIED (автоуровень) | provider + узкий маршрут, target встроен, appex собран; реальный старт — device |
| IOS-03 | 05-02, 05-03 | NEVPNStatus observer → Flutter | ✓ SATISFIED (автоуровень) | VpnStatusObserver полный маппинг → VpnEventListener; runtime-переходы — device |
| IOS-04 | 05-01, 05-03 | Entitlements Packet Tunnel + App Groups; TestFlight-готовность | ✓ SATISFIED (автоуровень) | entitlements обоих таргетов, строки корректны, DOC-02; portal/archive — device |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | Комментарии в Swift (запрещены конвенцией) | ℹ️ — | 0 найдено в трёх phase-5 Swift-файлах |
| — | — | Debt-маркеры (TBD/FIXME/XXX/TODO) | ℹ️ — | 0 найдено |
| — | — | `com.example.vpn_oko` (запрещённая строка) | ℹ️ — | 0 найдено в ios/ и scripts/ |

`PacketTunnelProvider` без read-loop/трафик-счётчиков и без реального VPN-core — намеренный skeleton по дизайну плана (Open Q2 / Out of Scope в REQUIREMENTS.md), не стаб-дефект: провайдер поднимает реальные `NEPacketTunnelNetworkSettings`. Не блокирует цель фазы.

### Human Verification Required (Device / TestFlight checkpoint)

Это НЕ gap фазы — граница честно зафиксирована в 05-03/DOC-02 (симулятор NE не исполняет по дизайну Apple). checkpoint:human-verify пользователя:

1. **Реальный туннель на устройстве.** Connect → VPN-диалог → Connecting → Connected, профиль «Oko VPN» в Settings, интернет работает (узкий маршрут). Disconnect → Disconnected.
2. **NEVPNStatus → Flutter runtime.** Переходы статуса из живого NE доходят до экрана.
3. **Portal + TestFlight.** Два App ID с NE + App Groups, provisioning, archive, upload.

### Гейты, прогнанные верификатором заново (не по SUMMARY)

- `flutter build ios --no-codesign --debug` → ✓ Runner.app + PlugIns/PacketTunnel.appex (Mach-O arm64) собраны
- `flutter analyze` → ✓ No issues found
- `flutter test` → ✓ 147/147
- Grep-инварианты строк → ✓ (bundle id ×3, entitlements ×2 таргета, App Group, Info.plist без `-provider`, `com.example.vpn_oko`=0, `userId`=0, `tunnel up`=0)
- xcodeproj target graph → ✓ (app-extension, dependency, embed перед Thin Binary, membership)
- Pigeon-контракт (`Messages.g.swift`, `pigeons/`, `AppDelegate`) и `VpnEventListener.swift` не изменены в коммитах фазы 5 → ✓ (git diff подтверждает)

### Gaps Summary

Gap-ов на автоматизируемом уровне нет. Все 4 требования (IOS-01..04) закрыты на уровне компиляции обоих таргетов, корректности строк и Dart-маппинга — проверено заново верификатором, не по заявлениям SUMMARY. Единственная незакрытая позиция — реальный NE-туннель на физическом устройстве через TestFlight — это ограничение платформы Apple (симулятор packet-tunnel NE не исполняет), вынесенное в явный device-checkpoint пользователя (05-03, gate blocking) и зафиксированное в DOC-02. По директиве фазы это не gap.

Примечание (не gap): рабочее дерево содержит pod-install артефакты после сборки (`M project.pbxproj` с `[CP]`-фазами, `M contents.xcworkspacedata`, `?? Podfile.lock`) — регенерированы прогоном `flutter build` при верификации. Коммит HEAD чист (`[CP]`=0), что соответствует HEAD-конвенции репо (05-01/05-02).

---

_Verified: 2026-07-14T06:20:00Z_
_Verifier: Claude (gsd-verifier)_
