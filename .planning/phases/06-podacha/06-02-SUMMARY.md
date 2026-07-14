---
phase: 06-podacha
plan: 02
subsystem: ci-devops
tags: [github-actions, ci, flutter-analyze, flutter-test, google-fonts, offline-bundle]

requires:
  - phase: 06-podacha
    plan: 01
    provides: README с CI-бейджем на путь actions/workflows/ci.yml (name CI)
  - phase: 04-vless
    provides: 147 тестов в test/ (парсер, мапперы, Bloc/Cubit, виджеты)
  - phase: 03
    provides: офлайн-бандл шрифтов google_fonts/ (Inter, JetBrainsMono, SpaceGrotesk)
provides:
  - .github/workflows/ci.yml — GitHub Actions workflow analyze+test на ubuntu-latest
  - Подтверждённо зелёная локальная CI-последовательность (pub get + analyze + 147 тестов)
  - Доказательство офлайн-безопасности google_fonts (шрифты из бандла, не из сети)
affects: [06-04-checkpoints]

tech-stack:
  added:
    - "GitHub Actions: subosito/flutter-action@v2 (Flutter 3.44.5 stable)"
    - "GitHub Actions: actions/checkout@v4"
  patterns:
    - "CI пинит actions тегами major (@v4/@v2), без @master/@main"
    - "CI без сборки APK/IPA, без setup-java, без pigeon-кодогена (vpn_api.g.dart закоммичен)"
    - "yaml без пояснительных комментариев (по духу правила 'без комментариев в коде')"

key-files:
  created:
    - .github/workflows/ci.yml
    - .planning/phases/06-podacha/06-02-SUMMARY.md
  modified: []

key-decisions:
  - "test/flutter_test_config.dart НЕ создан: офлайн-прогон (allowRuntimeFetching=false) зелёный — шрифты резолвятся из бандла, флейк не подтверждён, гвард избыточен"
  - "Тип шагов пинится Flutter 3.44.5 stable под воспроизводимость с локальной средой (Dart 3.12.2)"
  - "Job назван analyze-and-test; name workflow — CI (совпадает с путём бейджа README плана 06-01)"

patterns-established:
  - "Wave 0 self-validation: точная CI-последовательность гоняется локально до пуша, зелёный результат = доказательство прохождения CI"

requirements-completed: [DOC-04]

duration: 4min
completed: 2026-07-14
---

# Phase 6 Plan 02: CI GitHub Actions Summary

**Workflow `.github/workflows/ci.yml` гоняет `flutter analyze` + `flutter test` на ubuntu-latest без сборки APK; точная CI-последовательность локально зелёная (147 тестов), риск google_fonts-флейка снят офлайн-прогоном — шрифты резолвятся из бандла, не из сети.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-07-14T03:49:26Z
- **Completed:** 2026-07-14T03:53:33Z
- **Tasks:** 2
- **Files created:** 1 (.github/workflows/ci.yml)

## Accomplishments
- `.github/workflows/ci.yml`: `name: CI`, триггеры `push`/`pull_request` в `main`, job `analyze-and-test` на `ubuntu-latest`; шаги `actions/checkout@v4` → `subosito/flutter-action@v2` (channel stable, flutter-version 3.44.5) → `flutter pub get` → `flutter analyze` → `flutter test`
- Actions запинены тегами major (`@v4`/`@v2`), без `@master`/`@main`; секреты (`secrets.*`) не используются — снимает T-6-02 и T-6-04 из threat-register
- Без сборки APK/IPA, без `setup-java`, без pigeon-кодогена; yaml без пояснительных комментариев
- Локальная CI-последовательность зелёная: `flutter pub get` (OK) → `flutter analyze` (No issues found) → `flutter test` (All 147 tests passed)
- Риск google_fonts-флейка снят: прогон с `GoogleFonts.config.allowRuntimeFetching = false` (эмуляция headless/офлайн) остался зелёным — все глифы резолвятся из офлайн-бандла `google_fonts/`, сетевой fetch не нужен

## Task Commits

Each task was committed atomically:

1. **Task 1: Создать .github/workflows/ci.yml (DOC-04)** — `22dab5e` (chore)
2. **Task 2: Self-validating прогон analyze+test, снятие риска google_fonts (Wave 0)** — без code-артефакта (валидационная задача; решение по `flutter_test_config.dart` — не создавать, задокументировано ниже)

## Files Created/Modified
- `.github/workflows/ci.yml` — новый workflow analyze+test (20 строк)
- `.planning/phases/06-podacha/06-02-SUMMARY.md` — этот файл

## Decisions Made
- **`test/flutter_test_config.dart` не создан.** Плановая логика: файл-гвард создаётся ТОЛЬКО при подтверждённом флейке google_fonts. Флейк не подтверждён. Доказательство: временно выставил `GoogleFonts.config.allowRuntimeFetching = false` (сильнее, чем отключение сети — google_fonts вообще не пытается fetch и обязан взять шрифт из бандла) и прогнал полный набор — все 147 тестов зелёные. Значит на headless CI без сети набор так же зелёный. Гвард избыточен: механизм офлайн-резолва — сам бандл (`google_fonts/` объявлен как asset), он работает идентично локально и на CI (один и тот же asset-пайплайн `flutter test`). Держать лишний файл нет причины ("не плодить лишнее").
- **Пин Flutter 3.44.5 stable** в workflow под воспроизводимость: совпадение с локальной средой разработки (Dart 3.12.2, revision f94f4fc76b).
- **runs-on ubuntu-latest**, не macOS: iOS/APK не собираем, дорогой macOS-раннер не нужен.

## Deviations from Plan

None — план выполнен как написан. План допускал два исхода Task 2 (создать `flutter_test_config.dart` или нет); реализован документированный исход "не создавать" по подтверждённо зелёному офлайн-прогону, что прямо предусмотрено acceptance criteria задачи.

## Google Fonts Risk Verification

| Прогон | Условие | Результат |
|--------|---------|-----------|
| Базовый | сеть доступна, дефолтное поведение | 147/147 зелёные |
| Офлайн-эмуляция | `allowRuntimeFetching = false` (fetch запрещён) | 147/147 зелёные |

Вывод: шрифты `Inter`/`JetBrainsMono`/`SpaceGrotesk` резолвятся из офлайн-бандла `google_fonts/`; сетевой fetch не срабатывает и не требуется. Риск Pitfall 1 (флейк в headless CI) снят до пуша.

## Threat Model Coverage
- **T-6-02 (Information Disclosure, CI logs):** workflow без сборки/подписи → нет `secrets.*`, env не используются. Mitigated.
- **T-6-04 (Tampering, GitHub Actions зависимости):** `actions/checkout@v4` и `subosito/flutter-action@v2` запинены тегами; оба verified в RESEARCH как официальные/де-факто-стандарт. Mitigated.
- **T-6-SC (supply-chain):** фаза не ставит пакетов; `flutter pub get` подтягивает зафиксированный `pubspec.lock`. Accept — неприменимо.

## Issues Encountered
- Локально нет PyYAML (`ModuleNotFoundError: No module named 'yaml'`). Валидность yaml подтверждена альтернативно: `ruby -ryaml YAML.load_file` (valid), проверка отсутствия табов и кратности отступа 2 пробелам.

## Known Stubs
None — CI-workflow полностью функционален. Бейдж-плейсхолдер `<owner>/<repo>` в README относится к плану 06-01/06-04, не к этому плану.

## User Setup Required
- Публичный GitHub-репозиторий + `git push` (git remote сейчас не настроен) — checkpoint плана 06-04. От него зависят первый прогон CI и зелёный бейдж.

## Next Phase Readiness
- `name: CI` + файл `ci.yml` совпадают с путём бейджа README (план 06-01) — ключевой линк подтверждён.
- Workflow пройдёт с первого прогона после пуша: локальная CI-последовательность доказано зелёная офлайн-безопасно.
- План 06-04 (checkpoints): создание публичного репо, push, подстановка owner/repo в бейдж, ожидание первого зелёного прогона.

## Self-Check: PASSED

- FOUND: .github/workflows/ci.yml
- FOUND: .planning/phases/06-podacha/06-02-SUMMARY.md
- ABSENT (by decision): test/flutter_test_config.dart
- FOUND commit: 22dab5e

---
*Phase: 06-podacha*
*Completed: 2026-07-14*
