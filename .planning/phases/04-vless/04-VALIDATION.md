---
phase: 4
slug: vless
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-14
---

# Phase 4 — Validation Strategy

> Чистый Dart: парсер и tcping покрываются unit-тестами (с фейк-connector), вставка — bloc-тест, карточка — widget-тест. Платформа/сеть не нужны в автосьюте.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) + bloc_test ^10.0.0 + mocktail ^1.0.5 (уже в pubspec) |
| **Config file** | нет (стандартный flutter test) |
| **Quick run command** | `flutter test test/features/server_config/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~12s |

---

## Sampling Rate

- **After every task commit:** `flutter test test/features/server_config/`
- **After every plan wave:** `flutter test`
- **Phase-gate:** полный `flutter test` зелёный + `flutter analyze` чистый (very_good_analysis)
- **Max feedback latency:** 15 seconds

---

## Per-Requirement Verification Map

| Req ID | Behavior | Test Type | File | Status |
|--------|----------|-----------|------|--------|
| VLS-01 | reality/tcp — полный конфиг | unit | vless_parser_test.dart | ⬜ pending |
| VLS-01 | ws/tls, grpc — разные type/security | unit | vless_parser_test.dart | ⬜ pending |
| VLS-01/QA-01 | percent-encoded имя → decode | unit | vless_parser_test.dart | ⬜ pending |
| VLS-01/QA-01 | IPv6-хост [::1] | unit | vless_parser_test.dart | ⬜ pending |
| VLS-01/QA-01 | порт вне 1..65535 → failure | unit | vless_parser_test.dart | ⬜ pending |
| VLS-01/QA-01 | нечисловой порт → failure(malformed) | unit | vless_parser_test.dart | ⬜ pending |
| VLS-01/QA-01 | пустой/невалидный uuid → failure | unit | vless_parser_test.dart | ⬜ pending |
| VLS-01/QA-01 | пустой host → failure | unit | vless_parser_test.dart | ⬜ pending |
| VLS-01/QA-01 | чужая схема → failure(scheme) | unit | vless_parser_test.dart | ⬜ pending |
| VLS-01/QA-01 | trim пробелов из буфера | unit | vless_parser_test.dart | ⬜ pending |
| VLS-01/QA-01 | отсутствующие параметры → дефолты | unit | vless_parser_test.dart | ⬜ pending |
| VLS-03 | measured RTT через фейк-connect | unit | socket_latency_probe_test.dart | ⬜ pending |
| VLS-03 | SocketException → LatencyUnreachable | unit | socket_latency_probe_test.dart | ⬜ pending |
| VLS-02 | paste valid → state.loaded(config) | bloc | server_config_cubit_test.dart | ⬜ pending |
| VLS-02 | paste invalid → state.error(reason) | bloc | server_config_cubit_test.dart | ⬜ pending |
| VLS-02 | пустой буфер → error(empty) | bloc | server_config_cubit_test.dart | ⬜ pending |
| VLS-02 | loaded → measure → loaded+latency | bloc | server_config_cubit_test.dart | ⬜ pending |
| VLS-02 | карточка рендерит поля, маскирует uuid | widget | vless_config_card_test.dart | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/features/server_config/domain/vless_parser_test.dart` — VLS-01, QA-01 (ядро, ~11 кейсов)
- [ ] `test/features/server_config/data/socket_latency_probe_test.dart` — VLS-03 (фейк-connector)
- [ ] `test/features/server_config/presentation/server_config_cubit_test.dart` — VLS-02
- [ ] `test/features/server_config/presentation/vless_config_card_test.dart` — VLS-02 карточка (widget, опц.)

---

## Manual-Only Verifications (device phase-gate)

| Behavior | Requirement | Test Instructions |
|----------|-------------|-------------------|
| Вставка vless:// из буфера | VLS-02 | Скопировать vless://-ссылку, нажать вставку, увидеть карточку конфига |
| tcping реальный | VLS-03 | Карточка показывает задержку в мс (или «недоступен») к реальному хосту |

---

## Validation Sign-Off

- [x] Парсер + tcping + cubit покрыты unit/bloc-тестами (Wave 0)
- [x] Карточка — widget-тест (маскирование uuid)
- [x] Sampling continuity выдержана
- [x] `nyquist_compliant: true`

**Approval:** approved 2026-07-14
