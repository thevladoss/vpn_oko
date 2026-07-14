---
phase: 5
slug: ios-network-extension
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-14
---

# Phase 5 — Validation Strategy

> NE-специфика: реальный туннель не автоматизируется (симулятор его не исполняет). Автогейт = компиляция обоих таргетов + Dart-тесты моста + Swift-мост в симуляторе. Device/TestFlight — manual-only checkpoint.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (Dart)** | flutter_test (SDK) + mocktail 1.0.5 (уже в проекте) |
| **Swift NE** | нет XCTest-инфры; верификация Swift = компиляция + device |
| **Config file** | analysis_options.yaml (very_good_analysis) |
| **Quick run command** | `flutter analyze && flutter test` |
| **Full suite command** | `flutter test` + `flutter build ios --no-codesign --debug` (Runner + embedded PacketTunnel) |
| **Estimated runtime** | Dart ~10s; iOS-сборка — минуты |

---

## Sampling Rate

- **After every task commit:** `flutter analyze && flutter test` (Dart) — быстрый гейт
- **After every wave (iOS-таргеты затронуты):** `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -sdk iphonesimulator -configuration Debug build` — компиляция обоих таргетов
- **Phase-gate:** `flutter build ios --no-codesign --debug` зелёный (Runner + embedded PacketTunnel) + Swift-мост запускается в симуляторе (статусы/логи видны). Реальный туннель — отдельный device/TestFlight checkpoint (не блокирует автогейт)
- **Max feedback latency (Dart):** 15s; iOS-сборки — phase-gate уровня

---

## Per-Requirement Verification Map

| Req ID | Behavior | Test Type | Command / Method | Status |
|--------|----------|-----------|------------------|--------|
| IOS-01 | Swift-мост компилируется, статусы/логи из Swift в симуляторе | compile + manual-sim | flutter build ios --no-codesign + запуск в симуляторе | ⬜ pending |
| IOS-01 | Dart маппит NE-статусы/ошибки в domain | unit | flutter test (мапперы событий) | ⬜ pending |
| IOS-02 | Оба таргета (Runner + PacketTunnel) компилируются | compile | flutter build ios --no-codesign --debug | ⬜ pending |
| IOS-02 | Реальный startTunnel/setTunnelNetworkSettings | manual (device) | TestFlight-прогон | ⬜ device checkpoint |
| IOS-03 | NEVPNStatus observer доводит статус до Flutter | manual (device) | TestFlight; на симуляторе — путь ошибки | ⬜ device checkpoint |
| IOS-04 | entitlements/App Groups присутствуют, компиляция проходит | compile + grep | grep packet-tunnel в *.entitlements + build | ⬜ pending |
| IOS-04 | Готовность к TestFlight (archive/signing) | manual | ручной archive + upload | ⬜ device checkpoint |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `ios/PacketTunnel/` target создан через ruby `xcodeproj` (не руками в pbxproj)
- [ ] `ios/Runner/Runner.entitlements` + `ios/PacketTunnel/PacketTunnel.entitlements`
- [ ] Grep-гейт корректных строк: `com.apple.networkextension.packet-tunnel` (без `-provider`), `com.example.vpnOko.PacketTunnel`, `group.com.example.vpnOko`
- [ ] Skeleton PacketTunnelProvider.swift компилируется под iphonesimulator
- [ ] Dart-тест маппинга NE-ErrorMessage/статусов в domain (если не покрыт существующим маппером)

---

## Manual-Only Verifications (device / TestFlight checkpoint)

| Behavior | Requirement | Test Instructions |
|----------|-------------|-------------------|
| Реальный старт туннеля | IOS-02 | На устройстве через TestFlight: Connect → NETunnelProviderManager.startVPNTunnel → PacketTunnelProvider.startTunnel → NEPacketTunnelNetworkSettings применяются |
| NEVPNStatus → Flutter | IOS-03 | На устройстве: смена статуса туннеля доходит до Flutter-экрана (ирис-индикатор) |
| Готовность TestFlight | IOS-04 | Регистрация двух App ID (com.example.vpnOko + .PacketTunnel) с NE+App Groups capabilities в portal, provisioning profiles, archive, upload |

**Граница ручной проверки пользователя:** реальный NE-туннель на устройстве через TestFlight (аккаунт Apple Developer есть). Симулятор NE не исполняет — оркестратор проверяет только компиляцию обоих таргетов + Swift-мост (путь ошибки «NE недоступен в симуляторе»).

---

## Validation Sign-Off

- [x] Автогейт компиляции обоих таргетов определён (flutter build ios --no-codesign)
- [x] Dart-мост маппинг покрыт unit
- [x] Реальный туннель честно вынесен в device/TestFlight checkpoint (природа NE)
- [x] Grep-гейты корректных строк bundle id/entitlements/App Group
- [x] `nyquist_compliant: true`

**Approval:** approved 2026-07-14
