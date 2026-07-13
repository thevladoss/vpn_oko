---
phase: 03-flutter-ui
plan: 05
subsystem: ui
tags: [flutter, custompainter, animationcontroller, reduce-motion, semantics, timer]

# Dependency graph
requires:
  - phase: 03-02
    provides: OkoTones (accentFor, glow), VpnStatus, OkoMotion (segment/ringBreath/pupilOpen/shake), OkoTheme.dark
  - phase: 03-04
    provides: "hhmmss(Duration) — форматтер таймера HH:MM:SS"
provides:
  - "IrisPainter — один CustomPainter геометрии ириса (кольцо/зрачок/glow/сегмент/shake) для пяти статусов (UI-01, UI-06)"
  - "IrisIndicator — StatefulWidget + 4 AnimationController + reduce-motion + Semantics liveRegion (UI-06)"
  - "ConnectionTimer — Timer.periodic от connectedSince, переживает пересоздание, FittedBox tabular (UI-04)"
affects: [03-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Один параметризованный CustomPainter на все состояния; геометрию ведут анимируемые значения, цвета только из переданных полей"
    - "reduce-motion читается в didChangeDependencies, не в initState; oneShot-эффекты отделены от смены зависимостей"
    - "TickerFuture-вызовы (repeat/forward) и HapticFeedback оборачиваются unawaited для discarded_futures"

key-files:
  created:
    - lib/features/vpn_connection/presentation/widgets/iris_painter.dart
    - lib/features/vpn_connection/presentation/widgets/iris_indicator.dart
    - lib/features/vpn_connection/presentation/widgets/connection_timer.dart
    - test/features/vpn_connection/presentation/widgets/iris_indicator_test.dart
  modified: []

key-decisions:
  - "IrisIndicator принимает VpnStatus + DateTime? connectedSince (презентационный, Bloc не читает) — центр отдаёт в ConnectionTimer только в connected"
  - "Overshoot зрачка через CurvedAnimation(easeOutBack); painter получает curved-value, растит зрачок с лёгким перелётом"
  - "oneShot-флаг: раскрыв зрачка, shake и haptics срабатывают лишь на реальной смене статуса, не при каждой смене зависимостей (тема/reduce)"
  - "Haptics остаются при reduce-motion (это не анимация, DESIGN); loop-контроллеры при disableAnimations остановлены"

patterns-established:
  - "Виджеты ириса/таймера презентационные: вход VpnStatus/connectedSince, экран 03-08 обернёт в BlocBuilder"
  - "Smoke-тест анимированного виджета: pump (не pumpAndSettle) для loop-статусов, финальный pumpWidget(SizedBox) снимает висящие таймеры"

requirements-completed: [UI-01, UI-04, UI-06]

# Metrics
duration: 6min
completed: 2026-07-13
---

# Phase 03 Plan 05: Сигнатурный ирис-индикатор Summary

**Один CustomPainter рисует ирис на пять статусов, IrisIndicator ведёт его четырьмя AnimationController с уважением к reduce-motion и Semantics liveRegion, а ConnectionTimer тикает от connectedSince и переживает пересоздание.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-13T22:43:58Z
- **Completed:** 2026-07-13T22:50:05Z
- **Tasks:** 2
- **Files modified:** 4 (все созданы)

## Accomplishments
- `IrisPainter`: центрированное кольцо диаметром `min(size)*0.8`, толщина по статусу (3/5/8), раскрытие зрачка, радиальный glow с alpha по статусу+breath, бегущий сегмент 40° для connecting, разрыв дуги 30° и shake по X для error. `shouldRepaint` сравнивает все семь полей (status/segment/breath/pupil/shake/accent/glow) — ирис не замерзает (Pitfall 7). Цвета только из `accent`/`glow`, хардкода `Color` нет.
- `IrisIndicator`: контроллеры `_segment`/`_breath`/`_pupil`/`_shake` + `CurvedAnimation` overshoot; reduce-motion через `MediaQuery.disableAnimationsOf` в `didChangeDependencies`; connecting крутит сегмент и дышит, connected раскрывает зрачок один раз + дыхание glow + light haptic, error даёт shake + heavy haptic; `Semantics(liveRegion: true)` с лейблом статуса; все контроллеры и `CurvedAnimation` диспоузятся (Pitfall 3, T-3-06).
- `ConnectionTimer`: `Timer.periodic(1s)` от `connectedSince`, перезапуск только при смене источника (Pitfall 4), `FittedBox` + `displayLarge` (Space Grotesk 48/600 tabular), `SizedBox.shrink()` и без тика при `connectedSince == null`, отмена таймера в `dispose`.

## Task Commits

Каждая задача закоммичена атомарно:

1. **Task 1: IrisPainter** — `5188753` (feat)
2. **Task 2: IrisIndicator + ConnectionTimer + smoke-тест** — `bbdb811` (feat)

## Files Created/Modified
- `lib/features/vpn_connection/presentation/widgets/iris_painter.dart` — `IrisPainter extends CustomPainter`, геометрия пяти статусов
- `lib/features/vpn_connection/presentation/widgets/iris_indicator.dart` — `IrisIndicator` StatefulWidget, анимации + reduce-motion + Semantics
- `lib/features/vpn_connection/presentation/widgets/connection_timer.dart` — `ConnectionTimer` от connectedSince
- `test/features/vpn_connection/presentation/widgets/iris_indicator_test.dart` — smoke: пять статусов, disableAnimations, ConnectionTimer(null)

## Decisions Made
- IrisIndicator получил параметр `DateTime? connectedSince` дополнительно к `VpnStatus` (критические заметки плана: виджеты принимают оба, Bloc не читают). Только в connected он пробрасывается в центральный `ConnectionTimer`, иначе `null` — таймер не тикает.
- Overshoot зрачка реализован через `CurvedAnimation(curve: easeOutBack)`; painter принимает curved-value `pupil`, поэтому перелёт живёт в кривой, а не в ручной математике.
- `oneShot`-флаг разделяет смену статуса и смену зависимостей: раскрыв/shake/haptics запускаются только при реальной смене статуса, чтобы тема или переключение reduce-motion не перезапускали одноразовые эффекты.
- TickerFuture-вызовы (`repeat`, `forward`) и `HapticFeedback` обёрнуты в `unawaited` — снимает `discarded_futures` без изменения fire-and-forget поведения (тот же приём, что в LogsCubit 03-04).

## Deviations from Plan

None - plan executed exactly as written. Единственное уточнение — параметр `connectedSince` у `IrisIndicator` (прямо предписан критическими заметками плана «принимают VpnStatus + connectedSince»), не отклонение.

## Threat Register Coverage
- **T-3-06 (Denial of Service, AnimationController / Timer):** mitigate — все четыре `AnimationController` и `CurvedAnimation` диспоузятся, `Timer.periodic` отменяется в `dispose` и при смене источника; при `disableAnimations` loop-контроллеры остановлены (нет утечки тикеров). Smoke-тест подтверждает отсутствие висящих таймеров.

## Issues Encountered
None. Одна правка длины строки (перенос аргумента `Listenable.merge`) под лимит 80 символов VGA.

## User Setup Required
None — внешних сервисов не требуется.

## Next Phase Readiness
- Виджеты готовы для экрана 03-08: `IrisIndicator(status:, connectedSince:)` оборачивается в `BlocBuilder<VpnConnectionBloc, VpnConnectionState>`
- `flutter test` зелёный (80 тестов), `flutter analyze` чист

## Self-Check: PASSED

Все 4 файла на диске; оба коммита (5188753, bbdb811) в истории.

---
*Phase: 03-flutter-ui*
*Completed: 2026-07-13*
