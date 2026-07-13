---
phase: 03-flutter-ui
plan: 06
subsystem: ui
tags: [flutter, widgets, material3, theme-extension, semantics, tdd]

requires:
  - phase: 03-flutter-ui (план 03-02)
    provides: OkoTones, VpnStatus, OkoMotion, OkoTypography, OkoTheme
  - phase: 03-flutter-ui (план 03-04)
    provides: formatBytes (presentation/formatters/byte_format.dart)
provides:
  - OkoWordmark — wordmark oko с акцентной точкой состояния
  - StatusBadge — pill со словом статуса, цвет из accentFor, кроссфейд
  - ServerCard — карточка name + host:port с иконкой и шевроном
  - TrafficTile / TrafficPanel — плитки rx/tx через formatBytes, tabular
  - ConnectButton — CTA со сменой лейбла/стиля по статусу, блокировка в переходных, haptic
affects: [03-flutter-ui (план 03-08 vpn_home_screen — обёртка в BlocBuilder)]

tech-stack:
  added: []
  patterns:
    - "Презентационные виджеты: примитивы + колбэки, Bloc не читают"
    - "Приватный StatefulWidget (_RunningSegment) внутри StatelessWidget для анимации без утечки состояния наружу"
    - "Бегущий сегмент через CustomPainter вместо CircularProgressIndicator"

key-files:
  created:
    - lib/features/vpn_connection/presentation/widgets/oko_wordmark.dart
    - lib/features/vpn_connection/presentation/widgets/status_badge.dart
    - lib/features/vpn_connection/presentation/widgets/server_card.dart
    - lib/features/vpn_connection/presentation/widgets/traffic_tile.dart
    - lib/features/vpn_connection/presentation/widgets/traffic_panel.dart
    - lib/features/vpn_connection/presentation/widgets/connect_button.dart
    - test/features/vpn_connection/presentation/widgets/status_badge_test.dart
    - test/features/vpn_connection/presentation/widgets/connect_button_test.dart
  modified: []

key-decisions:
  - "StatusBadge рендерит слово статуса в title-case ('Disconnected'), стиль labelSmall даёт визуал; uppercase-строка из UI-SPEC конфликтовала с behavior-контрактом find.text('Disconnected') — приоритет у контракта плана"
  - "ConnectButton остаётся StatelessWidget; бегущий сегмент вынесен в приватный _RunningSegment (AnimationController), уважающий MediaQuery.disableAnimations"
  - "Foreground filled-кнопки = colorScheme.onPrimary (тема), не хардкод void-цвета — инвертируется по яркости, проходит grep-гейт Color(0xFF"

patterns-established:
  - "TrafficDirection enum рядом с TrafficTile; TrafficPanel строит down/up равной ширины"
  - "Виджеты со сменой статуса кроссфейдят цвет через AnimatedContainer/AnimatedDefaultTextStyle за OkoMotion.statusCrossfade"

requirements-completed: [UI-01, UI-02, UI-04, UI-05, UI-06]

duration: 4min
completed: 2026-07-14
---

# Phase 03 Plan 06: Хром и элементы управления Summary

**Шесть презентационных виджетов Oko — wordmark, бейдж-слово статуса, карточка сервера, плитки rx/tx через formatBytes и Connect/Disconnect-кнопка с UI-блокировкой двойного тапа и haptic — плюс два widget-теста (StatusBadge, ConnectButton).**

## Performance

- **Duration:** 4 min
- **Started:** 2026-07-13T22:59:10Z
- **Completed:** 2026-07-14
- **Tasks:** 2
- **Files modified:** 8 (создано)

## Accomplishments

- StatusBadge озвучивает статус словом (UI-01: дублирование не только цветом), цвет из OkoTones.accentFor, кроссфейд за statusCrossfade.
- ConnectButton в connecting/disconnecting имеет onPressed==null — двойной тап невозможен на уровне UI (UI-02, вторая линия к Bloc-гейту isBusy, T-3-07); haptic mediumImpact на нажатие (UI-06).
- TrafficPanel показывает rx/tx через formatBytes с разбивкой значение/единица и tabular-цифрами (UI-05); ServerCard — name + host:port (UI-04).
- Прогресс в переходных статусах — горизонтальный бегущий сегмент (CustomPainter), спиннеров нет (UI-06).
- Все цвета из OkoTones/темы, ноль хардкода Color(0xFF, ноль комментариев; полный flutter test зелёный (90 тестов), flutter analyze чист.

## Task Commits

Каждая задача — TDD RED→GREEN:

1. **Task 1: OkoWordmark, StatusBadge, ServerCard**
   - RED `da2aed0` (test) — падающий StatusBadge-тест на слово статуса
   - GREEN `640265c` (feat) — три виджета, тест зелёный
2. **Task 2: TrafficTile, TrafficPanel, ConnectButton**
   - RED `ba94ef6` (test) — падающий ConnectButton-тест на блокировку и лейблы
   - GREEN `8a49b6f` (feat) — три виджета, тест зелёный

_TDD-гейт: test(...)-коммит предшествует feat(...) в обеих задачах._

## Files Created/Modified

- `lib/.../widgets/oko_wordmark.dart` — wordmark oko + акцентная точка accentFor(status)
- `lib/.../widgets/status_badge.dart` — pill radius 999, фон accent@0.16, слово статуса
- `lib/.../widgets/server_card.dart` — surfaceCard radius 20, dns-иконка, name + host:port, шеврон
- `lib/.../widgets/traffic_tile.dart` — плитка направления (down/up), formatBytes значение+единица, Semantics
- `lib/.../widgets/traffic_panel.dart` — Row двух TrafficTile равной ширины, active=connected
- `lib/.../widgets/connect_button.dart` — CTA 56px, стиль/лейбл/enabled ведёт статус, haptic, _RunningSegment
- `test/.../widgets/status_badge_test.dart` — слово статуса для пяти статусов
- `test/.../widgets/connect_button_test.dart` — onPressed==null в переходных, лейблы, тап-колбэк

## Decisions Made

- **StatusBadge title-case, не uppercase-строка.** UI-SPEC описывает лейбл uppercase, а behavior-контракт плана требует `find.text('Disconnected')` (title-case). Плоская строка не может быть одновременно 'DISCONNECTED' и совпадать с 'Disconnected'. Приоритет у executable-контракта плана: строка 'Disconnected', визуальный вес даёт стиль labelSmall (semibold, letterSpacing 0.5). Отклонение от косметики SPEC, семантика статуса не страдает.
- **_RunningSegment вынесен из ConnectButton.** План фиксирует ConnectButton как StatelessWidget, а бегущий сегмент требует AnimationController. Приватный StatefulWidget держит анимацию инкапсулированной; уважает disableAnimations (в reduce-motion сегмент статичен), поэтому тесты с disableAnimations:true проходят pumpAndSettle без зависания на бесконечной анимации.
- **Foreground filled-кнопки = colorScheme.onPrimary.** Инвертируется по яркости темы (тёмный текст на ярком акценте в dark, белый в light), контраст держится в обеих темах и без литералов Color(0xFF.

## Deviations from Plan

None - plan executed exactly as written. Решение по title-case бейджа — разрешение внутреннего конфликта UI-SPEC (uppercase) и behavior-контракта плана (find.text title-case), не отклонение от задачи.

## Issues Encountered

None. Оба widget-теста прошли RED→GREEN с первой итерации реализации; overflow в TrafficTile исключён точным бюджетом высоты (72 − padding 32 = 40px под контент 16+24).

## Threat Surface

T-3-07 (двойной тап) закрыт как запланировано: ConnectButton.onPressed==null в connecting/disconnecting — UI-линия защиты поверх Bloc-гейта isBusy. Новых trust boundary не введено (виджеты презентационные).

## Next Phase Readiness

- Все шесть виджетов готовы к сборке экраном (план 03-08): принимают VpnStatus/данные + onConnect/onDisconnect, оборачиваются в BlocBuilder<VpnConnectionBloc>.
- Осталось по фазе: iris уже собран (03-05), LogConsole/LogLine и сам экран vpn_home_screen с MultiBlocProvider.

## Self-Check: PASSED

Все 8 созданных файлов присутствуют на диске; все четыре task-коммита (da2aed0, 640265c, ba94ef6, 8a49b6f) есть в истории. flutter analyze чист, flutter test зелёный (90).

---
*Phase: 03-flutter-ui*
*Completed: 2026-07-14*
