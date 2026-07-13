---
phase: 3
slug: flutter-ui
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-14
---

# Phase 3 — Validation Strategy

> UI-фаза: бизнес-логика (Bloc/Cubit) и чистые функции покрываются unit-тестами; визуал (ирис, темы, пять статусов) проверяется на устройстве/эмуляторе (phase-gate).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) + bloc_test ^10.0.0 + mocktail ^1.0.5 |
| **Config file** | analysis_options.yaml (very_good_analysis 10.3.0) |
| **Quick run command** | `flutter test test/features/vpn_connection/presentation/bloc/vpn_connection_bloc_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15s |

---

## Sampling Rate

- **After every task commit:** `flutter analyze` + целевой тест-файл (`flutter test <file>`)
- **After every plan wave:** `flutter test` (весь набор)
- **Phase-gate:** `flutter analyze` без варнингов + `flutter test` зелёный + визуальная проверка обеих тем и пяти статусов на устройстве/эмуляторе
- **Max feedback latency:** 15 seconds

---

## Per-Requirement Verification Map

| Req ID | Behavior | Test Type | Command | Status |
|--------|----------|-----------|---------|--------|
| QA-02 / UI-01 | disconnected→connecting→connected, connectedSince | unit (bloc) | vpn_connection_bloc_test.dart | ⬜ pending |
| QA-02 / UI-02 | double-tap guard: ConnectRequested×2 в connecting → connectVpn 0 | unit (bloc) | vpn_connection_bloc_test.dart | ⬜ pending |
| QA-02 | any→error: VpnError → status error, errorMessage | unit (bloc) | vpn_connection_bloc_test.dart | ⬜ pending |
| QA-02 | onRevoke: VpnDisconnected из стрима, disconnectVpn НЕ вызван | unit (bloc) | vpn_connection_bloc_test.dart | ⬜ pending |
| UI-07 | syncStatus вызван ровно раз на VpnStarted | unit (bloc) | vpn_connection_bloc_test.dart | ⬜ pending |
| UI-03 | LogsCubit: append + cap 500 + pause/resume autoScroll | unit (cubit) | logs_cubit_test.dart | ⬜ pending |
| UI-08 | plainText форматирует HH:mm:ss [LEVEL] text | unit (cubit) | logs_cubit_test.dart | ⬜ pending |
| UI-05 | formatBytes: 812 B / 12.4 MB / границы 1024 | unit (pure) | format_bytes_test.dart | ⬜ pending |
| UI-04 | hhmmss: zero-pad, часы >0 | unit (pure) | timer_format_test.dart | ⬜ pending |
| UI-02 | ConnectButton onPressed==null в connecting/disconnecting | widget (опц.) | connect_button_test.dart | ⬜ pending |
| UI-01 | StatusBadge показывает слово статуса | widget (опц.) | status_badge_test.dart | ⬜ pending |
| UI-06 | ирис, темы, staggered, haptics | manual (device) | визуальный phase-gate | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/features/vpn_connection/presentation/bloc/vpn_connection_bloc_test.dart` — QA-02, UI-01, UI-02, UI-07
- [ ] `test/features/vpn_logs/presentation/bloc/logs_cubit_test.dart` — UI-03, UI-08
- [ ] `test/features/vpn_connection/presentation/format_bytes_test.dart` — UI-05
- [ ] `test/features/vpn_connection/presentation/timer_format_test.dart` — UI-04
- [ ] `flutter pub add --dev bloc_test`
- [ ] Тест-хелперы: моки/фейки usecases по образцу test/helpers/
- [ ] (опц.) widget-тесты connect_button_test.dart, status_badge_test.dart

---

## Manual-Only Verifications (визуальный phase-gate)

| Behavior | Requirement | Test Instructions |
|----------|-------------|-------------------|
| Ирис-индикатор 5 состояний | UI-01, UI-06 | На устройстве прогнать все статусы, увидеть анимацию/цвет ириса |
| Тёмная И светлая темы | UI-06 | Переключить системную тему — обе выглядят корректно, контраст ≥4.5:1 |
| Живые логи + автоскролл + копирование | UI-03, UI-08 | Логи прокручиваются, копирование в буфер работает |
| Таймер + карточка сервера + трафик | UI-04, UI-05 | Таймер тикает от connectedSince, rx/tx обновляются |
| Восстановление состояния | UI-07 | Hot restart при активном VPN — UI показывает Connected |

---

## Validation Sign-Off

- [x] Bloc/Cubit + чистые функции покрыты unit-тестами (Wave 0)
- [x] Визуал — device phase-gate (природа UI)
- [x] Sampling continuity: каждая логическая задача имеет тест
- [x] `nyquist_compliant: true`

**Approval:** approved 2026-07-14
