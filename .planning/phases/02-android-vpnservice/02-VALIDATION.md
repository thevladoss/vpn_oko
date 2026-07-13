---
phase: 2
slug: android-vpnservice
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-13
---

# Phase 2 — Validation Strategy

> Особенность фазы: почти все механики VpnService (consent-диалог, establish, видимость уведомления, onRevoke, счётчики) наблюдаемы только на устройстве/эмуляторе. Основной автогейт — компиляция Kotlin через `flutter build apk --debug`; поведение проверяется ручным device-чеклистом.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (Dart)** | flutter_test (SDK) — в фазе 2 Dart почти не меняется |
| **Framework (Kotlin)** | опциональный Wave 0: JUnit на state machine (чистый Kotlin) |
| **Config file** | analysis_options.yaml (Dart); нет (Kotlin) |
| **Quick run command** | `flutter build apk --debug` (компилирует Kotlin — основной автогейт) |
| **Full suite command** | `flutter analyze && flutter test` (Dart-регресс) + ручной device-чеклист |
| **Estimated runtime** | сборка APK — минуты; Dart-регресс — ~10s |

---

## Sampling Rate

- **After every task commit:** `flutter build apk --debug` (Kotlin компилируется без ошибок)
- **After every plan wave:** `flutter analyze && flutter test` (Dart-регресс зелёный)
- **Phase-gate (checkpoint:human-verify на эмуляторе API 34+):** ручной чеклист ниже
- **Max feedback latency (Dart unit):** 15 seconds; сборочные и device-проверки — phase-gate уровня

---

## Per-Requirement Verification Map

| Req ID | Behavior | Test Type | Command / Method | Status |
|--------|----------|-----------|------------------|--------|
| AND-01 | Consent-диалог, RESULT_OK/CANCELED | manual (device) | Connect → prepare-диалог; Cancel → Error+лог | ⬜ pending |
| AND-02 | establish на узкую подсеть, интернет жив | manual (device) | Connected → открыть сайт в браузере | ⬜ pending |
| AND-03 | FGS + уведомление + systemExempted (нет краша API 34+) | manual (эмулятор API 34+) | шторка показывает уведомление; нет MissingForegroundServiceType | ⬜ pending |
| AND-04 | teardown / onRevoke → Disconnected | manual (device) | включить второй VPN поверх → onRevoke | ⬜ pending |
| AND-05 | Счётчики rx растут при ping | manual (device + adb) | `adb shell ping <tun-subnet>` → rx растёт в UI | ⬜ pending |
| AND-06 | Переходы логируются | partial | JUnit на переходы (опц.) + device-видимость | ⬜ pending |
| (все) | Kotlin компилируется | smoke | `flutter build apk --debug` | ⬜ pending |
| (регресс) | Dart-контракт цел | unit | `flutter test` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] (опц.) `android/app/src/test/kotlin/.../VpnConnectionStateTest.kt` — таблица переходов state machine (JUnit, чистый Kotlin, без Android). Low priority.
- [ ] Эмулятор AVD API 34/35/36 доступен и запущен для phase-gate.
- [ ] `adb` в PATH (или `~/Library/Android/sdk/platform-tools/adb`) для ping-демо и logcat.

*Автотестов на сам VpnService нет по природе API — это ожидаемо и честно фиксируется.*

---

## Manual-Only Verifications (phase-gate чеклист)

| # | Behavior | Requirement | Test Instructions |
|---|----------|-------------|-------------------|
| 1 | Consent → Connected | AND-01, AND-02 | Connect → prepare-диалог → RESULT_OK → статус Connected, значок ключа в статус-баре |
| 2 | Интернет жив в Connected | AND-02 | В Connected открыть сайт в браузере — грузится (узкий маршрут) |
| 3 | Уведомление FGS | AND-03 | Уведомление foreground-сервиса видно в шторке (POST_NOTIFICATIONS выдан) |
| 4 | Счётчик трафика | AND-05 | `adb shell ping <tun-subnet>` → rx растёт в UI раз в секунду |
| 5 | Отказ consent | AND-01 | Cancel в consent-диалоге → статус Error + лог «permission denied» |
| 6 | onRevoke | AND-04 | Включить второй VPN поверх → onRevoke → статус Disconnected + лог |
| 7 | Стабильность lifecycle | AND-03, AND-04 | Цикл Connect→Disconnect→Connect ×3 — стабильно, уведомление снимается, fd не течёт |
| 8 | Нет краша на старте | AND-03 | Нет DidNotStartInTime / MissingForegroundServiceType на API 34+ |

---

## Validation Sign-Off

- [x] Автогейт компиляции Kotlin определён (`flutter build apk --debug`)
- [x] Dart-регресс сохраняется зелёным (`flutter test`)
- [x] Device-чеклист покрывает все AND-требования
- [x] Manual-only честно зафиксировано (природа VpnService API)
- [x] `nyquist_compliant: true`

**Approval:** approved 2026-07-13
