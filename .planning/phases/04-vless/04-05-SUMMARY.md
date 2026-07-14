---
phase: 04-vless
plan: 05
subsystem: presentation
tags: [vless, integration, bloc-provider, blocbuilder, di, screen-test, flutter]

requires:
  - phase: 04-vless
    provides: SystemClipboardSource + SocketLatencyProbe (const-конструкторы, 04-02)
  - phase: 04-vless
    provides: VlessConfigCard + PasteConfigButton + describeVlessError (04-03)
  - phase: 04-vless
    provides: ServerConfigCubit + sealed ServerConfigState + фейки в test/helpers (04-04)
provides:
  - AppDependencies.clipboardSource + AppDependencies.latencyProbe (const-инстансы для DI)
  - BlocProvider<ServerConfigCubit> в MultiBlocProvider приложения
  - Реактивная карточка VlessConfigCard + PasteConfigButton в VpnHomeScreen
affects: [04-06]

tech-stack:
  added: []
  patterns:
    - "Реактивная карточка через BlocBuilder<ServerConfigCubit, ServerConfigState> — не context.read (Pitfall 4)"
    - "Приватный _pasteConfig(BuildContext) держит цепочку context.read().pasteFromClipboard() на одной строке под 80-символьный лимит very_good_analysis"
    - "Оба future (haptic + paste) обёрнуты в unawaited по конвенции connect_button + discarded_futures"

key-files:
  created: []
  modified:
    - lib/app/di.dart
    - lib/app/app.dart
    - lib/features/vpn_connection/presentation/screens/vpn_home_screen.dart
    - test/features/vpn_connection/presentation/screens/vpn_home_screen_test.dart

key-decisions:
  - "Карточка обёрнута в существующий _Staggered(staggerServerCard) через Column[BlocBuilder, кнопка] — staggered-анимация фазы 3 не тронута"
  - "Loaded → VlessConfigCard; Initial → демо ServerCard; Error → демо ServerCard + describeVlessError(bodySmall/accentError)"
  - "_pasteConfig-хелпер вместо inline-замыкания: цепочка pasteFromClipboard остаётся однострочной (читаемость + grep-гейт), формат не разрывает вызов"
  - "services.dart импортирован явно (конвенция connect_button/iris_indicator), хотя material его реэкспортирует"

patterns-established:
  - "Вертикальный срез замкнут: DI (const-реализации) → MultiBlocProvider → BlocBuilder-карточка + кнопка вставки"
  - "Screen-тест переиспользует фейки 04-04 (FakeClipboardSource/FakeLatencyProbe), третий BlocProvider.value, тап кнопки → карточка"

requirements-completed: [VLS-02, VLS-03]

duration: 6min
completed: 2026-07-14
---

# Phase 04 Plan 05: Интеграция server_config в VpnHomeScreen Summary

**DI собирает const SystemClipboardSource + SocketLatencyProbe, MultiBlocProvider отдаёт ServerConfigCubit, VpnHomeScreen через BlocBuilder реактивно рисует VlessConfigCard/ошибку/демо и PasteConfigButton — вертикальный срез VLS-02/VLS-03 замкнут в UI.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-14T01:09:06Z
- **Completed:** 2026-07-14T01:15:13Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- DI: `AppDependencies` получил `clipboardSource = const SystemClipboardSource()` и `latencyProbe = const SocketLatencyProbe()`; оба const-инстанса компилируются (гарантия 04-02)
- `MultiBlocProvider` приложения содержит третий `BlocProvider<ServerConfigCubit>` с инъекцией реальных `ClipboardSource` + `LatencyProbe`; `VpnConnectionBloc.config` неизменён (demoConfig)
- `VpnHomeScreen` реактивно (`BlocBuilder<ServerConfigCubit, ServerConfigState>`) показывает `VlessConfigCard` в loaded, демо-`ServerCard` в initial, `ServerCard` + строку `describeVlessError` в error
- `PasteConfigButton` вызывает `HapticFeedback.mediumImpact()` + `pasteFromClipboard()`; вставка обновляет карточку без ручного refresh (реактивность через BlocBuilder, не context.read — Pitfall 4)
- Screen-тест: старые 2 теста зелёные + новый (тап кнопки → валидная ссылка → `VlessConfigCard` виден, полный uuid маскирован); полный набор проекта — 138 тестов зелёные
- Автогейт зелёный: `flutter analyze` чист, `flutter test` 138/138, `flutter build apk --debug` собрался

## Task Commits

Each task was committed atomically:

1. **Task 1: DI + провайдер ServerConfigCubit** - `1d69ccb` (feat)
2. **Task 2: BlocBuilder карточки + кнопка вставки + обновление screen-теста** - `4d12e10` (feat)

## Files Created/Modified
- `lib/app/di.dart` - AppDependencies: const SystemClipboardSource() + const SocketLatencyProbe() + импорты domain-абстракций и data-реализаций
- `lib/app/app.dart` - третий BlocProvider ServerConfigCubit(clipboard, probe) рядом с LogsCubit
- `lib/features/vpn_connection/presentation/screens/vpn_home_screen.dart` - BlocBuilder-карточка (loaded/error/initial) + PasteConfigButton через _pasteConfig-хелпер, внутри существующего _Staggered(staggerServerCard)
- `test/features/vpn_connection/presentation/screens/vpn_home_screen_test.dart` - третий BlocProvider.value из фейков 04-04 + тест вставки (карточка появляется, полный uuid отсутствует)

## Decisions Made
- Карточка живёт в `Column[BlocBuilder, SizedBox, PasteConfigButton]` внутри уже существующего `_Staggered(staggerServerCard)` — staggered-фазы экрана 3 не сдвинуты, кнопка встала под карточку
- `_pasteConfig(BuildContext)` вынесен приватным методом State: цепочка `context.read<ServerConfigCubit>().pasteFromClipboard()` остаётся на одной строке (под 80 символов), inline-замыкание `dart format` разбивал на три строки и рвал grep-гейт
- Оба future — `HapticFeedback.mediumImpact()` и `pasteFromClipboard()` — обёрнуты в `unawaited` (very_good_analysis `discarded_futures` + конвенция connect_button/iris_indicator)
- `import 'package:flutter/services.dart'` оставлен явным, как в connect_button/iris_indicator, хотя material реэкспортирует HapticFeedback

## Deviations from Plan

None по существу — план выполнен как написано.

Формат-обусловленный рефактор (не отклонение по смыслу): inline-onPressed из плана вынесен в приватный `_pasteConfig` — `dart format` разбивал `unawaited(context.read<ServerConfigCubit>().pasteFromClipboard())` на глубоком отступе, ломая читаемость и однострочный grep-гейт `context.read<ServerConfigCubit>().pasteFromClipboard`. Поведение идентично плану (haptic + paste по тапу).

## Issues Encountered
None. `flutter analyze` чист после форматирования, все 138 тестов зелёные, APK собрался за 4.7s. Тап `PasteConfigButton` в widget-тесте вызывает haptic-платформенный канал без падения (конвенция уже проверена в widget-тестах фазы 3).

## Threat Model Coverage
- **T-4-02 (Information Disclosure, mitigate):** экран рисует только `VlessConfigCard`, которая маскирует uuid; новый screen-тест доказывает отсутствие обеих половин полной строки (`b831381d-6324-4d53` и `ad4f-8cda48b30811`) → `findsNothing`, при этом карточка `findsOneWidget`.
- **T-4-04 (SSRF-подобный, accept):** tcping инициируется только явным тапом `PasteConfigButton` → `pasteFromClipboard`; авто-вставки/авто-коннекта нет; таймаут пробы 3с (04-02).
- **T-4-02b (Information Disclosure, accept):** `VpnConnectionBloc.config` по-прежнему = `demoConfig` (grep подтверждает `config: dependencies.demoConfig`); вставленный конфиг display-only, в реальный Connect не проводится.
- Новой security-поверхности за пределами threat_model плана не добавлено.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Вертикальный срез VLS-02/VLS-03 замкнут в реальном дереве: вставка → parse → measure → реактивная карточка с задержкой
- 04-06 (device-gate) проверит живой буфер и реальный tcping на устройстве поверх собранного среза
- Демо-путь Connect неизменен — экран фазы 3 сохраняет поведение, тесты зелёные

## Self-Check: PASSED

Все 4 изменённых файла + SUMMARY на диске; коммиты `1d69ccb`, `4d12e10` в истории.

---
*Phase: 04-vless*
*Completed: 2026-07-14*
