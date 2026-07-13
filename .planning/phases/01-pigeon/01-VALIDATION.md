---
phase: 1
slug: pigeon
status: approved
nyquist_compliant: true
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
- **Max feedback latency (unit-тесты):** 15 seconds
- **Phase-gate проверки** (`flutter build apk --debug`, `flutter build ios --no-codesign`, live-echo checkpoint) выполняются на границе фазы, а не после каждой задачи — их время (минуты) не входит в per-task latency

---

## Per-Task Verification Map

Wave-0 тесты встроены как TDD-задачи в планы 02/03/04 (test-first, RED→GREEN), отдельного Plan 00 нет.

| Test | Plan / Task | Requirement | Test Type | Automated Command | Status |
|------|-------------|-------------|-----------|-------------------|--------|
| Домен-модели: равенство/иммутабельность | 01-02 / T1 | CORE-01 | unit | `flutter test test/features/vpn_connection/domain/entities/vpn_state_test.dart` | ⬜ pending |
| Маппер StatusChanged→VpnState | 01-03 / T2 | BRG-03 | unit | `flutter test test/features/vpn_connection/data/mappers/vpn_event_mapper_test.dart` | ⬜ pending |
| Маппер LogMessage→LogEntry | 01-03 / T2 | BRG-03 | unit | `flutter test test/features/vpn_logs/data/mappers/log_mapper_test.dart` | ⬜ pending |
| VpnBridge демультиплекс + HostApi-проксирование | 01-03 / T1 | BRG-01, BRG-02 | unit | `flutter test test/core/bridge/vpn_bridge_test.dart` | ⬜ pending |
| VpnRepositoryImpl replay last-статус | 01-04 / T1 | BRG-04 | unit | `flutter test test/features/vpn_connection/data/repositories/vpn_repository_impl_test.dart` | ⬜ pending |

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
- [x] Feedback latency < 15s (unit); phase-gate сборки вынесены отдельно
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-13
