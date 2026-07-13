---
phase: 03-flutter-ui
plan: 02
subsystem: ui
tags: [theme, theme-extension, google_fonts, material3, color-tokens, motion, flutter]

# Dependency graph
requires:
  - phase: 03-flutter-ui
    provides: "план 03-01 — google_fonts 8.1.0 в pubspec + офлайн-бандл Space Grotesk / Inter / JetBrains Mono"
provides:
  - "enum VpnStatus (lib/core/theme/vpn_status.dart) — общий словарь пяти статусов для темы, Bloc и виджетов"
  - "OkoTones extends ThemeExtension: accentFor(VpnStatus) / copyWith / lerp + dark и light const-токены"
  - "OkoTypography.textTheme(Brightness) на google_fonts + OkoTypography.mono для строк логов"
  - "OkoTheme.dark / OkoTheme.light — ThemeData с явным ColorScheme и extensions<OkoTones>"
  - "OkoMotion — длительности, кривые и stagger-задержки motion как const"
affects: [03-03, 03-04, 03-05, 03-06, 03-07, 03-08, 03-09]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ThemeExtension<OkoTones> с lerp по Color.lerp — единственный источник статус→цвет через accentFor"
    - "ColorScheme выводится из токенов OkoTones (single source), не хардкодится и не fromSeed"
    - "TextTheme на google_fonts поверх Typography.material2021().white/black — цвета от темы, не хардкодом"

key-files:
  created:
    - lib/core/theme/vpn_status.dart
    - lib/core/theme/oko_tones.dart
    - lib/core/theme/oko_typography.dart
    - lib/core/theme/oko_theme.dart
    - lib/core/theme/oko_motion.dart
    - test/core/theme/oko_tones_test.dart
  modified: []

key-decisions:
  - "VpnStatus живёт в core/theme (не в feature): accentFor — метод темы, Bloc и виджеты импортируют enum из core (feature→core законно)"
  - "ColorScheme обеих тем выведен из токенов OkoTones; литералами остались только void #0B0F14, светлый фон #F4F6F9 и белый #FFFFFF (контраст/scaffold, отсутствуют как токены)"
  - "Табличные цифры (FontFeature.tabularFigures) вынесены на displayLarge и titleMedium — покрывают таймер и крупные числа трафика; на буквах эффекта нет"
  - "TextTheme строится поверх Typography.material2021().white/black, поэтому цвета текста приходят от режима темы, а не хардкодятся в типографике"

patterns-established:
  - "Дизайн-токены только в oko_tones.dart; виджеты берут их через Theme.of(context).extension<OkoTones>()!, хардкод цветов в виджетах запрещён"
  - "Motion-ритм централизован в OkoMotion; виджеты переиспользуют const длительности/кривые/задержки"

requirements-completed: [UI-06]

# Metrics
duration: 6min
completed: 2026-07-14
---

# Phase 3 Plan 02: Дизайн-система тем и токенов Summary

**Дизайн-система фазы собрана в lib/core/theme: enum VpnStatus, OkoTones (ThemeExtension с accentFor/lerp, dark+light), типографика google_fonts с табличными цифрами, обе ThemeData и motion-константы**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-07-13T22:09:56Z
- **Completed:** 2026-07-13T22:16:01Z
- **Tasks:** 2 (обе auto)
- **Files modified:** 6 создано

## Accomplishments
- `OkoTones extends ThemeExtension<OkoTones>` с полным набором токенов из UI-SPEC для dark и light; `accentFor(VpnStatus)` — единственный источник маппинга статус→цвет (exhaustive switch по пяти статусам), `lerp` по `Color.lerp` для плавного кроссфейда при смене темы.
- Обе темы `OkoTheme.dark` / `OkoTheme.light`: `useMaterial3: true`, явный `ColorScheme` (не `fromSeed`) выведенный из токенов OkoTones, `textTheme` из google_fonts, `extensions: <OkoTones>[tones]` — токены читаются через `Theme.of(context).extension<OkoTones>()`.
- Типографика на google_fonts: Space Grotesk (display 48/600 + title 20/600), Inter (body 15/400, label 12/600, caption 12/400), JetBrains Mono (логи 12/400); табличные цифры на display/title для таймера и чисел трафика.
- `OkoMotion` — все длительности, кривые и stagger-задержки из ## Motion как const (единый ритм для виджетов).
- Автогейт зелёный: `flutter analyze lib/core/theme/` без варнингов, полный `flutter test` — 53 теста проходят (46 регресс + 7 новых по токенам).

## Task Commits

Каждая задача закоммичена атомарно:

1. **Task 1: VpnStatus + OkoTones + OkoMotion + тест токенов** — `377eaac` (feat)
2. **Task 2: Типографика google_fonts и обе ThemeData** — `1af4097` (feat)
3. **Refactor: явный тип OkoTones в extensions темы** — `ec3ccd5` (refactor)

**Plan metadata:** _(коммитится отдельно с SUMMARY/STATE/ROADMAP)_

## Files Created/Modified
- `lib/core/theme/vpn_status.dart` — `enum VpnStatus { disconnected, connecting, connected, disconnecting, error }`
- `lib/core/theme/oko_tones.dart` — `OkoTones extends ThemeExtension<OkoTones>`: 9 Color-полей, `accentFor`, `copyWith`, `lerp`, `static const dark`/`light`
- `lib/core/theme/oko_typography.dart` — `OkoTypography.textTheme(Brightness)` + `OkoTypography.mono(Brightness)` на google_fonts
- `lib/core/theme/oko_theme.dart` — `OkoTheme.dark`/`OkoTheme.light` → ThemeData; ColorScheme выведен из токенов OkoTones
- `lib/core/theme/oko_motion.dart` — `OkoMotion` с const длительностями/кривыми/задержками
- `test/core/theme/oko_tones_test.dart` — accentFor для пяти статусов + lerp на границах 0.0/1.0 + fallback на не-OkoTones

## Decisions Made
- **VpnStatus в core/theme, не в feature.** `accentFor(VpnStatus)` — метод темы (core), поэтому enum живёт рядом; Bloc и виджеты импортируют его из core (feature→core законно). Значения один-к-одному с подтипами domain `VpnState`.
- **ColorScheme выведен из токенов OkoTones.** Чтобы палитра имела единственный источник, `primary/secondary/error/onSurface` читаются из `OkoTones.dark`/`light`. Литералами оставлены только void `#0B0F14`, светлый фон `#F4F6F9` и белый `#FFFFFF` — это scaffold/контрастные цвета, которых нет среди токенов OkoTones. Схемы `static final` (доступ к полю const-объекта не является const-выражением).
- **Табличные цифры на displayLarge и titleMedium.** Таймер (48) и крупные числа трафика (20) не должны дёргаться; на буквенных ролях (wordmark, `Logs`) `tabularFigures` — no-op, поэтому размещение безопасно.
- **Типографика поверх Typography.material2021().** `textTheme(Brightness)` строит стили на brightness-корректной базе, цвета текста приходят от режима темы, а не хардкодятся в типографике (требование UI-SPEC).
- **glow как базовый surface-независимый токен.** Dark — белый низкой альфы (`0x1AFFFFFF`), light — void низкой альфы (`0x140B0F14`); конкретную альфу radial-glow (0.10–0.16 / 0.06–0.10) задаёт виджет ириса, как указывает план.

## Deviations from Plan

None - план выполнен как написано. Границы соблюдены: только `lib/core/theme/` + типографика, ни виджетов, ни Bloc, ни экрана. Регистрация OFL-лицензий в `LicenseRegistry` (открытый пункт из 03-01) не входит в files_modified этого плана (runtime-код `main.dart`) — оставлена следующему плану.

## Issues Encountered
- **ThemeExtension не резолвился из `package:flutter/widgets.dart`.** Первый импорт oko_tones указывал на widgets; `ThemeExtension` экспортируется из `package:flutter/material.dart`. Исправлено до первого коммита (IDE-диагностика поймала сразу), автогейт зелёный.

## User Setup Required
None - внешняя конфигурация не требуется.

## Next Phase Readiness
- Виджеты фазы (03-03+) могут читать токены через `Theme.of(context).extension<OkoTones>()!` и брать акцент статуса через `accentFor(VpnStatus)`.
- Motion-виджеты берут ритм из `OkoMotion`; типографику — из `textTheme` темы, моно-строки логов — из `OkoTypography.mono`.
- Открытый пункт (перенос из 03-01): зарегистрировать OFL-лицензии в `LicenseRegistry` в `main.dart` при сборке `OkoApp`.

## Self-Check: PASSED

Все шесть заявленных файлов существуют; коммиты `377eaac`, `1af4097`, `ec3ccd5` присутствуют в истории.

---
*Phase: 03-flutter-ui*
*Completed: 2026-07-14*
