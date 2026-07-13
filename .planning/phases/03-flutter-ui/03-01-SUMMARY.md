---
phase: 03-flutter-ui
plan: 01
subsystem: ui
tags: [google_fonts, bloc_test, fonts, space-grotesk, inter, jetbrains-mono, offline-bundle, flutter]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: flutter_bloc/equatable/mocktail в pubspec, structura проекта
  - phase: 02-android-vpnservice
    provides: рабочий native-слой и репозитории, поверх которых строится presentation
provides:
  - google_fonts ^8.1.0 (runtime) в pubspec.yaml
  - bloc_test ^10.0.0 (dev) для QA-02 Bloc-тестов
  - офлайн-бандл трёх семейств шрифтов в google_fonts/ (Space Grotesk, Inter, JetBrains Mono)
  - OFL-лицензии трёх семейств в бандле для LicenseRegistry (регистрация — план 03-02)
affects: [03-02, 03-03, 03-04, 03-05, 03-06, 03-07, 03-08, 03-09]

# Tech tracking
tech-stack:
  added: [google_fonts 8.1.0, bloc_test 10.0.0, bloc 9.2.1 (транзитив)]
  patterns: ["Офлайн-бандлинг google_fonts через статичные .ttf в assets (приоритет ассета над HTTP, Pitfall 5)"]

key-files:
  created:
    - google_fonts/SpaceGrotesk-Regular.ttf
    - google_fonts/SpaceGrotesk-SemiBold.ttf
    - google_fonts/Inter-Regular.ttf
    - google_fonts/Inter-SemiBold.ttf
    - google_fonts/JetBrainsMono-Regular.ttf
    - google_fonts/OFL-SpaceGrotesk.txt
    - google_fonts/OFL-Inter.txt
    - google_fonts/OFL-JetBrainsMono.txt
    - ios/Podfile
  modified:
    - pubspec.yaml
    - pubspec.lock
    - ios/Flutter/Debug.xcconfig
    - ios/Flutter/Release.xcconfig

key-decisions:
  - "Статичные .ttf инстансированы из variable-шрифтов google/fonts через fonttools varLib.instancer (fonts.google.com/download отдаёт HTML, репо содержит только variable-фонты)"
  - "Имена файлов по конвенции Google Fonts API ({Family}-{Weight}.ttf) — обязательное условие матчинга бандла пакетом google_fonts"
  - "OFL-лицензии трёх семейств вошли в бандл; регистрация в LicenseRegistry отложена в план 03-02 (runtime-код main.dart)"

patterns-established:
  - "Офлайн-бандлинг шрифтов: статичные .ttf в google_fonts/ + декларация assets в pubspec; HTTP-fetch остаётся фолбэком"

requirements-completed: [UI-06, QA-02]

# Metrics
duration: 12min
completed: 2026-07-14
---

# Phase 3 Plan 01: Зависимости шрифтов и Bloc-тестов Summary

**google_fonts ^8.1.0 + bloc_test ^10.0.0 подключены; Space Grotesk / Inter / JetBrains Mono забандлены статичными .ttf в google_fonts/ для офлайн-надёжности демо**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-07-13T21:51:00Z
- **Completed:** 2026-07-13T22:03:16Z
- **Tasks:** 2 (1 checkpoint + 1 auto)
- **Files modified:** 13

## Accomplishments
- Установлены обе pub-зависимости фазы: `google_fonts` 8.1.0 (runtime), `bloc_test` 10.0.0 (dev); транзитивный `bloc` разрешился в 9.2.1 — совместим с `flutter_bloc` 9.1.1.
- Собран офлайн-бандл шрифтов: пять статичных .ttf (Space Grotesk 400/600, Inter 400/600, JetBrains Mono 400) в `google_fonts/`, имена по конвенции Google Fonts API — пакет приоритизирует ассет над HTTP-загрузкой (закрывает Pitfall 5 из 03-RESEARCH).
- OFL-лицензии трёх семейств добавлены в бандл; папка `google_fonts/` объявлена в `flutter: assets:`.
- Автогейт зелёный: `flutter pub get` резолвится, `flutter analyze` без issues, все 46 существующих тестов проходят.

## Task Commits

1. **Task 1: Package legitimacy gate (google_fonts + bloc_test)** — без коммита (checkpoint). Легитимность обоих пакетов подтверждена оркестратором (verified publishers: flutter.dev, bloclibrary.dev); блокирующий checkpoint авто-одобрен, установка продолжена.
2. **Task 2: Установить пакеты и забандлить шрифты** — `0cd7674` (chore)

**Plan metadata:** _(коммитится отдельно с SUMMARY/STATE/ROADMAP)_

## Files Created/Modified
- `pubspec.yaml` — добавлены `google_fonts: ^8.1.0` (dependencies), `bloc_test: ^10.0.0` (dev_dependencies), секция `flutter: assets: - google_fonts/`
- `pubspec.lock` — зафиксированы разрешённые версии (google_fonts 8.1.0, bloc_test 10.0.0, bloc 9.2.1 + транзитивы)
- `google_fonts/SpaceGrotesk-Regular.ttf`, `SpaceGrotesk-SemiBold.ttf` — Space Grotesk 400/600 (display, цифры, таймер)
- `google_fonts/Inter-Regular.ttf`, `Inter-SemiBold.ttf` — Inter 400/600 (body, подписи)
- `google_fonts/JetBrainsMono-Regular.ttf` — JetBrains Mono 400 (строки логов)
- `google_fonts/OFL-SpaceGrotesk.txt`, `OFL-Inter.txt`, `OFL-JetBrainsMono.txt` — OFL-лицензии для LicenseRegistry
- `ios/Podfile`, `ios/Flutter/Debug.xcconfig`, `ios/Flutter/Release.xcconfig` — CocoaPods-интеграция, автогенерирована `flutter pub get` из-за плагина `path_provider` (транзитив google_fonts)

## Decisions Made
- **Источник .ttf — инстансирование variable-шрифтов.** `fonts.google.com/download` теперь отдаёт HTML-страницу вместо ZIP, а репозиторий `google/fonts` содержит только variable-фонты (`SpaceGrotesk[wght].ttf` и т.п.). Статичные single-weight инстансы получены через `fonttools varLib.instancer` (fontTools 4.60.2 в окружении): Space Grotesk/JetBrains Mono по оси `wght`, Inter с закреплением `opsz=14` и `wght`. Проверено: все пять файлов — валидный TTF (magic `00010000`), `OS/2.usWeightClass` = 400/600 корректно.
- **Матчинг по имени файла.** google_fonts сопоставляет бандл по имени файла (`{FamilyNoSpaces}-{WeightName}.ttf`), не по внутреннему `name`-table. Внутреннее имя Space Grotesk-инстансов — `Space Grotesk Light` (артефакт instancer), на рендеринг и матчинг не влияет; вес задан через `usWeightClass`.
- **Регистрация лицензий отложена в 03-02.** OFL-файлы вошли в бандл; вызов `LicenseRegistry.addLicense` — runtime-код в `main.dart`, вне границ этого плана (deps + bundle).

## Deviations from Plan

None - plan executed exactly as written. План допускал online-first фолбэк при отсутствии сети; сеть доступна, поэтому выполнен полный офлайн-бандл. Способ добычи .ttf (инстансирование через fonttools вместо прямого скачивания статики) — реализационная деталь внутри задачи, а не отклонение от контракта: план прямо указывает источником официальные шрифты Google Fonts и требует только корректных имён под google_fonts API.

## Issues Encountered
- **fonts.google.com/download отдаёт HTML, а не ZIP.** Прямое скачивание готовых статичных .ttf невозможно. Резолв: скачаны variable-фонты из `google/fonts` (raw) и инстансированы в статику через `fonttools varLib.instancer`.
- **Легаси-UA у Google Fonts CSS API отдаёт EOT, не TTF.** Первая попытка через `MSIE 6.0` User-Agent вернула Embedded OpenType (нечитаемо Flutter). Отброшено в пользу инстансирования variable-шрифтов.
- **zsh не делает word-splitting неэкранированных переменных.** Двухосевые аргументы Inter (`opsz=14 wght=400`) схлопнулись в один токен при передаче через функцию. Резолв: инстансирование Inter вызвано с явными раздельными аргументами.

## User Setup Required
None - внешняя конфигурация не требуется. Шрифты забандлены офлайн, сетевой fetch не нужен для демо.

## Next Phase Readiness
- Готово к плану 03-02: `google_fonts` API доступен, шрифты офлайн; `bloc_test` доступен для QA-02.
- `oko_typography.dart` (план 03-02+) может использовать `GoogleFonts.spaceGrotesk/inter/jetBrainsMono` — все начертания резолвятся из бандла без сети.
- Открытый пункт для 03-02: зарегистрировать OFL-лицензии в `LicenseRegistry` в `main.dart` (файлы `google_fonts/OFL-*.txt` уже в бандле).

## Self-Check: PASSED

Все заявленные файлы существуют (5 .ttf, 3 OFL, pubspec.yaml, ios/Podfile, SUMMARY); коммит `0cd7674` присутствует в истории.

---
*Phase: 03-flutter-ui*
*Completed: 2026-07-14*
