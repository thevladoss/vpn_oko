---
phase: 1
slug: pigeon
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-13
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) + mocktail 1.0.5 |
| **Config file** | none — Wave 0 installs mocktail |
| **Quick run command** | `flutter test test/features/vpn_connection/data` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~10 seconds (чистый Dart, без платформы) |

---

## Sampling Rate

- **After every task commit:** Run `flutter analyze && flutter test test/<изменённый каталог>`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green; `dart run pigeon --input pigeons/vpn_api.dart` без ошибок; сборка Android и iOS проходят
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 1-00-01 | 00 | 0 | CORE-01 | — | N/A | unit | `flutter test test/features/vpn_connection/domain/entities/vpn_state_test.dart` | ❌ W0 | ⬜ pending |
| 1-00-02 | 00 | 0 | BRG-03 | — | N/A | unit | `flutter test test/features/vpn_connection/data/mappers/vpn_event_mapper_test.dart` | ❌ W0 | ⬜ pending |
| 1-00-03 | 00 | 0 | BRG-03 | — | N/A | unit | `flutter test test/features/vpn_logs/data/mappers/log_mapper_test.dart` | ❌ W0 | ⬜ pending |
| 1-00-04 | 00 | 0 | BRG-01, BRG-02 | — | N/A | unit | `flutter test test/core/bridge/vpn_bridge_test.dart` | ❌ W0 | ⬜ pending |
| 1-00-05 | 00 | 0 | BRG-04 | — | N/A | unit | `flutter test test/features/vpn_connection/data/repositories/vpn_repository_impl_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/features/vpn_connection/domain/entities/vpn_state_test.dart` — CORE-01
- [ ] `test/features/vpn_connection/data/mappers/vpn_event_mapper_test.dart` — BRG-03
- [ ] `test/features/vpn_logs/data/mappers/log_mapper_test.dart` — BRG-03
- [ ] `test/core/bridge/vpn_bridge_test.dart` — BRG-01/BRG-02 (mock VpnHostApi + StreamController)
- [ ] `test/features/vpn_connection/data/repositories/vpn_repository_impl_test.dart` — BRG-04 (fake datasource)
- [ ] `test/helpers/` — общие фейки (FakeVpnNativeDatasource, MockVpnHostApi)
- [ ] Framework install: `flutter pub add --dev mocktail`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live echo из Kotlin/Swift в Dart-стрим (end-to-end мост) | BRG-02, BRG-04 | Unit-тесты Dart мокают native; реальный стрим через платформенный канал требует устройства/эмулятора | Запустить на Android-эмуляторе, в debug-harness нажать echo-Connect, увидеть StatusChanged + LogMessage; повторить на iOS-симуляторе |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
