---
phase: 6
slug: podacha
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-14
---

# Phase 6 — Validation Strategy

> Фаза подачи: код не пишется (кроме CI-workflow). README/DOC-разделы — ручная вычитка + рендер mermaid; CI сам себя валидирует прогоном; видео — ручная запись пользователя.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) + bloc_test + mocktail (147 тестов уже есть) |
| **Config file** | analysis_options.yaml (very_good_analysis) |
| **Quick run command** | `flutter test` |
| **Full suite command** | `flutter analyze && flutter test` (точная CI-последовательность локально) |

---

## Sampling Rate

- **After every task commit:** `flutter test`
- **After every wave:** `flutter analyze && flutter test`
- **Phase-gate:** зелёный CI на GitHub (первый прогон после push, шаг пользователя) + ручная вычитка README + рендер mermaid
- **Max feedback latency:** 15s (Dart)

---

## Per-Requirement Verification Map

| Req ID | Behavior | Test Type | Command / Method | Status |
|--------|----------|-----------|------------------|--------|
| DOC-01 | README: запуск/архитектура/mermaid/open-source | manual | ручная вычитка + рендер mermaid | ⬜ pending |
| DOC-02 | iOS-раздел README | manual | сверка с entitlements/Info.plist | ⬜ pending |
| DOC-03 | План интеграции core | manual | вычитка, точка = startReadLoop/startTunnel | ⬜ pending |
| DOC-04 | CI analyze+test зелёный, бейдж | integration (self-validating) | .github/workflows/ci.yml прогоняет analyze+test | ⬜ pending |
| DOC-05 | Видео 1-3 мин | manual (user) | ручная запись по чеклисту (checkpoint пользователя) | ⬜ user checkpoint |

*Status: ⬜ pending · ✅ green · ❌ red*

---

## Wave 0 Requirements

- [ ] `.github/workflows/ci.yml` — DOC-04 (flutter analyze + flutter test, subosito/flutter-action@v2, Flutter 3.44.5, ubuntu-latest, без APK)
- [ ] Прогнать `flutter pub get && flutter analyze && flutter test` на чистом чекауте — снять риск google_fonts-флейка до пуша

---

## Manual-Only Verifications (checkpoint пользователя)

| Behavior | Requirement | Test Instructions |
|----------|-------------|-------------------|
| Публичный репозиторий + push | DOC-01, DOC-04 | Создать публичный GitHub/GitLab репо, push (git remote не настроен — «пока локально»); первый CI-прогон зелёный, бейдж активен |
| Запись демо-видео 1-3 мин | DOC-05 | По чеклисту: запуск → Connect → consent → Connected+статусы/логи/трафик → Disconnect (на Android-эмуляторе живой; iOS — TestFlight) |

**Граница ручных шагов пользователя:** создание публичного репозитория + push (badge/сдача) и запись демо-видео. Оркестратор готовит README/DOC/CI/чеклист видео; сами push и запись — за пользователем.

---

## Validation Sign-Off

- [x] CI-workflow self-validating (analyze+test)
- [x] README/DOC-разделы — ручная вычитка (природа docs)
- [x] Видео + push — checkpoint пользователя (честно вынесены)
- [x] `nyquist_compliant: true`

**Approval:** approved 2026-07-14
