---
phase: 06-podacha
plan: 03
subsystem: docs
tags: [demo-video, recording-checklist, android-live, ios-testflight, doc-05]

requires:
  - phase: 02-android-vpnservice
    plan: 06
    provides: реальный Android-флоу consent→Connected→rx→Disconnect, снятый вживую на эмуляторе
  - phase: 03-flutter-ui
    plan: 09
    provides: UI-статусы (ирис, таймер, темы, живые логи, счётчик rx) для кадров видео
  - phase: 06-podacha
    plan: 01
    provides: README, чьё поведение (Connect→статусы→Disconnect) демонстрирует видео
provides:
  - docs/demo-script.md — покадровый сценарий видео (7 тактов) на русском
  - Чеклист записи с запретом реальных секретов в кадре (митигация T-6-06)
  - Заметка Android-live vs iOS-TestFlight
affects: [06-04-checkpoints]

tech-stack:
  added: []
  patterns:
    - "Сценарий выведен из реального поведения приложения фаз 2-3, не из воображения"
    - "Секреты в кадре: фейковый демо-конфиг echo.oko.vpn / нулевой UUID, маскировка в UI"

key-files:
  created:
    - docs/demo-script.md
    - .planning/phases/06-podacha/06-03-SUMMARY.md
  modified: []

key-decisions:
  - "DOC-05 не закрывается этим планом: 06-03 даёт сценарий, сам видео-артефакт снимается в чекпоинте 06-04 — маркировать DOC-05 complete до записи видео было бы ложным утверждением"
  - "Стоп-слоп в русском тексте: без em-dash, активный залог, конкретика (adb ping для растущего rx, точные инструменты записи)"
  - "Такты 2 и 7 (вставка vless, restart+getStatus) помечены опциональными; обязательный минимум — Connect+consent+Connected+живые данные+Disconnect"

patterns-established:
  - "Ручной артефакт (видео) готовится сценарием агента, снимается пользователем-чекпоинтом — агент не записывает экран"

requirements-completed: []

duration: 5min
completed: 2026-07-14
---

# Phase 6 Plan 03: Сценарий демо-видео Summary

**Покадровый сценарий на 7 тактов (0:00-2:40) плюс чеклист записи, по которому пользователь снимет живое Android-демо Connect→consent→Connected→трафик/логи→Disconnect без реальных секретов в кадре.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-07-14T03:56:00Z
- **Completed:** 2026-07-14T04:00:53Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- `docs/demo-script.md`: таблица из 7 тактов с временными метками, привязанная к реальному поведению приложения (consent-диалог, ирис, таймер, живой rx, teardown)
- Чеклист записи с явным запретом реальных `vless://`/UUID в кадре и списком инструментов (`scrcpy`, `adb screenrecord`, QuickTime, `xcrun simctl`)
- Честное разделение Android-live end-to-end и iOS через TestFlight (симулятор NE не хостит)
- Практическая деталь: `adb shell ping 10.111.222.1` даёт растущий rx в кадре при узком маршруте 10.111.222.0/24

## Task Commits

Each task was committed atomically:

1. **Task 1: Покадровый сценарий видео (7 тактов)** - `cb4d4ba` (docs)
2. **Task 2: Чеклист записи + платформенная заметка** - `ab138a2` (docs)

**Plan metadata:** см. финальный docs-коммит ниже.

## Files Created/Modified
- `docs/demo-script.md` - покадровый сценарий демо 1-3 мин: 7 тактов, чеклист записи, заметка Android vs iOS

## Decisions Made
- **DOC-05 остаётся Pending:** этот план поставляет сценарий/чеклист, а не видео. Сам ролик записывается в чекпоинте пользователя 06-04, который тоже владеет DOC-05 (ROADMAP). Пометка DOC-05 complete до наличия файла-видео была бы неточной, поэтому `requirements mark-complete` для DOC-05 не запускался.
- **Без em-dash в русском тексте** по language_rule плана: тире заменено двоеточиями, скобками и переносами предложений.
- **Опциональные такты помечены явно:** вставка `vless://` (такт 2) и restart+`getStatus()` (такт 7) усиливают подачу, но обязательный минимум — Connect, consent, Connected, живые логи/трафик, Disconnect.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None. Обе задачи прошли автогейты grep с первого прогона; проверка на отсутствие em-dash — чисто.

## Threat Surface

Митигация T-6-06 (Information Disclosure, кадр демо → зритель) реализована в чеклисте: секция «Секреты в кадре» требует фейковый демо-конфиг (`echo.oko.vpn`, UUID `00000000-...`), маскировку UUID в UI и запрет показа полного `vless://` при вставке из буфера. Новой security-поверхности план не вводит (документ, без кода).

## User Setup Required
None - no external service configuration required. Сама запись видео — checkpoint пользователя в плане 06-04.

## Next Phase Readiness
- Сценарий готов: пользователь в 06-04 снимает видео по чеклисту и закрывает DOC-05.
- 06-04 остаётся последним планом фазы 6 (публичный репозиторий + push + зелёный бейдж + запись видео).

## Self-Check: PASSED

- FOUND: docs/demo-script.md
- FOUND: .planning/phases/06-podacha/06-03-SUMMARY.md
- FOUND commit: cb4d4ba (Task 1)
- FOUND commit: ab138a2 (Task 2)

---
*Phase: 06-podacha*
*Completed: 2026-07-14*
