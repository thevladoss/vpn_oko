---
phase: quick-260714-ilt
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/features/vpn_connection/presentation/formatters/duration_format.dart
  - lib/features/vpn_connection/presentation/widgets/connection_timer.dart
  - lib/features/vpn_logs/presentation/widgets/log_console.dart
  - lib/features/vpn_connection/presentation/screens/vpn_home_screen.dart
  - test/features/vpn_connection/presentation/timer_format_test.dart
  - test/features/vpn_connection/presentation/widgets/connection_timer_test.dart
  - test/features/vpn_logs/presentation/widgets/log_console_test.dart
autonomous: true
requirements: [QUICK-260714-ilt]

must_haves:
  truths:
    - "Таймер показывает mm:ss пока время меньше часа и hh:mm:ss начиная с часа"
    - "Текст таймера имеет мягкую тень, читаемую в light и dark темах"
    - "Шапка лог-панели не даёт RenderFlex overflow ни в свёрнутом, ни в раскрытом виде"
    - "Лог-панель раскрывается тапом по шапке и свайпом вверх по шапке"
    - "Свайп по шапке при наличии логов раскрывает панель, а не скроллит список"
    - "Список логов скроллится независимо, только когда панель раскрыта"
    - "Copy, пустое состояние, авто-скролл (pause/resume), семантика и haptics сохранены"
  artifacts:
    - path: "lib/features/vpn_connection/presentation/formatters/duration_format.dart"
      provides: "hhmmss с ветвлением mm:ss / hh:mm:ss"
      contains: "inHours"
    - path: "lib/features/vpn_connection/presentation/widgets/connection_timer.dart"
      provides: "Text таймера с shadows"
      contains: "shadows"
    - path: "lib/features/vpn_logs/presentation/widgets/log_console.dart"
      provides: "Кастомная sliding-up панель на AnimationController"
      contains: "AnimationController"
  key_links:
    - from: "lib/features/vpn_connection/presentation/widgets/connection_timer.dart"
      to: "hhmmss"
      via: "вызов форматтера в build"
      pattern: "hhmmss\\("
    - from: "lib/features/vpn_logs/presentation/widgets/log_console.dart"
      to: "AnimationController"
      via: "GestureDetector шапки двигает контроллер"
      pattern: "onVerticalDragUpdate"
    - from: "lib/features/vpn_connection/presentation/screens/vpn_home_screen.dart"
      to: "LogConsole"
      via: "последний child Stack, выровнен по низу"
      pattern: "LogConsole"
---

<objective>
Пакет из четырёх UI-фиксов экрана VPN-подключения: формат таймера mm:ss до часа, мягкая тень текста таймера, устранение RenderFlex overflow в шапке лог-панели и замена DraggableScrollableSheet на кастомную sliding-up панель с раздельными drag-поверхностью шапки и скроллом списка.

Purpose: убрать визуальные дефекты и конфликт жестов (свайп снизу скроллит список вместо раскрытия панели), которые бросаются в глаза ревьюеру тестового задания.
Output: обновлённые форматтер и два виджета presentation-слоя + актуализированные и новые widget/unit-тесты; `flutter analyze` и весь тест-набор зелёные.
</objective>

<execution_context>
@/Users/thevladoss/.claude/plugins/cache/gsd-plugin/gsd/4.0.4/workflows/execute-plan.md
@/Users/thevladoss/.claude/plugins/cache/gsd-plugin/gsd/4.0.4/templates/summary.md
</execution_context>

<context>
@./CLAUDE.md

@lib/features/vpn_connection/presentation/formatters/duration_format.dart
@lib/features/vpn_connection/presentation/widgets/connection_timer.dart
@lib/features/vpn_logs/presentation/widgets/log_console.dart
@lib/features/vpn_connection/presentation/screens/vpn_home_screen.dart
@lib/features/vpn_logs/presentation/bloc/logs_cubit.dart
@lib/features/vpn_logs/presentation/bloc/logs_state.dart
@lib/features/vpn_logs/presentation/widgets/log_line.dart
@lib/core/theme/oko_tones.dart
@lib/core/theme/oko_motion.dart
@test/features/vpn_connection/presentation/timer_format_test.dart
@test/features/vpn_logs/presentation/widgets/log_console_test.dart

<interfaces>
<!-- Ключевые сигнатуры из кодовой базы. Используй напрямую, без доисследования. -->

lib/features/vpn_connection/presentation/formatters/duration_format.dart:
  String hhmmss(Duration duration)   // сейчас всегда 'hh:mm:ss', вызывается только из connection_timer.dart

lib/features/vpn_logs/presentation/bloc/logs_cubit.dart:
  class LogsCubit extends Cubit<LogsState>
  void pauseAutoScroll()
  void resumeAutoScroll()
  String plainText()                 // используется кнопкой Copy

lib/features/vpn_logs/presentation/bloc/logs_state.dart:
  class LogsState { List<LogEntry> entries; bool autoScroll; }

lib/core/theme/oko_tones.dart:
  extension OkoTonesContext on BuildContext { OkoTones get okoTones; }
  // токены: surfaceElevated, textPrimary, textSecondary, accentTransitional, accentError

lib/core/theme/oko_motion.dart:
  OkoMotion.autoscroll (200ms) / autoscrollCurve (easeOut)
  OkoMotion.statusCrossfade (300ms) / statusCrossfadeCurve (easeInOut)
  OkoMotion.enterScreen (350ms) / enterScreenCurve (easeOutCubic)
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Формат таймера mm:ss до часа</name>
  <files>
    lib/features/vpn_connection/presentation/formatters/duration_format.dart
    test/features/vpn_connection/presentation/timer_format_test.dart
  </files>
  <behavior>
    - 0s → "00:00"
    - 59s → "00:59"
    - 60s → "01:00"
    - 3599s → "59:59"
    - 3600s → "01:00:00"
    - 1h1m1s → "01:01:01"
    - 100h → "100:00:00" (часы не обрезаются)
    - отрицательная длительность → "00:00"
  </behavior>
  <action>
    Переработай `hhmmss(Duration)`: отрицательную длительность по-прежнему клампь к `Duration.zero`. Если `d.inHours == 0` — возвращай `mm:ss` (минуты = `d.inMinutes`, паддинг обоих полей до 2 знаков). Если `d.inHours >= 1` — возвращай `hh:mm:ss` (часы через `padLeft(2, '0')`, чтобы 1 час дал "01:00:00", а 100 часов остались "100:00:00"; минуты и секунды по модулю 60 с паддингом 2). Имя функции `hhmmss` НЕ переименовывай — это единственный вызов в connection_timer.dart, ripple не нужен. Комментарии в коде запрещены.
    Обнови существующий timer_format_test.dart: замени сломавшиеся ожидания (5s теперь "00:05", Duration.zero теперь "00:00", отрицательные теперь "00:00"), оставь кейсы >= 1 часа как есть, добавь граничные кейсы из блока behavior (59s, 60s, 3599s, 3600s).
  </action>
  <verify>
    <automated>flutter test test/features/vpn_connection/presentation/timer_format_test.dart</automated>
  </verify>
  <done>hhmmss отдаёт mm:ss ниже часа и hh:mm:ss с часа; все граничные кейсы зелёные; connection_timer.dart компилируется без правок сигнатуры вызова.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Мягкая тень текста таймера</name>
  <files>
    lib/features/vpn_connection/presentation/widgets/connection_timer.dart
    test/features/vpn_connection/presentation/widgets/connection_timer_test.dart
  </files>
  <behavior>
    - У Text таймера style.shadows содержит ровно один Shadow
    - blurRadius ~10 (в диапазоне 8..12), offset близко к Offset(0, 2)
    - цвет тени полупрозрачный (alpha в диапазоне 0.25..0.35)
    - виджет рендерится в dark-теме без падения по pending timer
  </behavior>
  <action>
    В `build` возьми `Theme.of(context).textTheme.displayLarge` и примени `.copyWith(shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 2))])`. Тень — drop shadow, а не тон поверхности: полупрозрачный чёрный корректно читается и в light, и в dark (мягкий ореол глубины под крупной акцентной цифрой), токен в okoTones под тень отсутствует и заводить его вне скоупа. Больше ничего в виджете не меняй (FittedBox, Timer.periodic, restart-логика остаются). Комментарии запрещены.
    Новый widget-тест connection_timer_test.dart: оберни ConnectionTimer в MaterialApp с `OkoTheme.dark` (чтобы displayLarge существовал), передай `connectedSince` в прошлом. После `await tester.pump()` найди Text, проверь `style.shadows` (длина 1, blurRadius, offset, alpha цвета). ВАЖНО: не вызывай `pumpAndSettle()` — периодический Timer раз в секунду не даст дереву осесть; после ассертов перепомпай дерево пустым виджетом (`await tester.pumpWidget(const SizedBox())`), чтобы State.dispose отменил таймер, затем `await tester.pump()` — иначе тест упадёт на pending timer.
  </action>
  <verify>
    <automated>flutter test test/features/vpn_connection/presentation/widgets/connection_timer_test.dart</automated>
  </verify>
  <done>Text таймера несёт мягкую тень (blur ~10, offset (0,2), alpha ~0.3); widget-тест подтверждает наличие и параметры тени; прогон зелёный без ошибок pending timer.</done>
</task>

<task type="auto">
  <name>Task 3: Кастомная sliding-up лог-панель без overflow и конфликта скролла</name>
  <files>
    lib/features/vpn_logs/presentation/widgets/log_console.dart
    lib/features/vpn_connection/presentation/screens/vpn_home_screen.dart
    test/features/vpn_logs/presentation/widgets/log_console_test.dart
  </files>
  <action>
    Перепиши LogConsole с DraggableScrollableSheet на кастомную sliding-up панель на `AnimationController` (`SingleTickerProviderStateMixin`), value 0..1 = collapsed..expanded. Держи минимум зависимостей — пакет sliding_up_panel НЕ добавлять (единственный кодоген проекта — pigeon). Комментарии в коде запрещены, feature-first presentation-слой, бизнес-логику LogsCubit не трогать.

    Геометрия. Заведи `static const double collapsedHeight` (значение с запасом под контент шапки: грабер 4 + отступ + Row высотой 40 + вертикальные паддинги ≈ 72-84, чтобы гарантированно НЕ было RenderFlex overflow — это закрывает Фикс 3). Раскрытая высота = `MediaQuery.sizeOf(context).height * 0.70`. Текущая высота панели = `lerp(collapsedHeight, expandedHeight, curvedValue)` через `AnimatedBuilder`. Панель прижата к низу (Align bottomCenter / Positioned bottom:0,left:0,right:0), поверх контента в Stack. Нижний паддинг = `MediaQuery.paddingOf(context).bottom` (SafeArea снизу), чтобы контент не уезжал под системный индикатор.

    Шапка = ОТДЕЛЬНАЯ drag-поверхность на `GestureDetector` (behavior opaque), не конфликтующая со скроллом списка: `onTap` → `_toggle()` (анимация к open/closed + `HapticFeedback.selectionClick`); `onVerticalDragUpdate` → сдвигай `_controller.value` на `-details.primaryDelta / dragRange` (тянуть вверх = увеличивать value), клампь 0..1; `onVerticalDragEnd` → snap к ближайшему состоянию по позиции и по знаку `velocity.pixelsPerSecond.dy` (быстрый флик доминирует над позицией), haptic при смене состояния. Содержимое шапки: центрированный грабер, Row [ Semantics(header:true) Text 'Logs' (titleMedium, textPrimary) + иконка `Icons.expand_less_rounded`/`expand_more_rounded` + Spacer + кнопка Copy 40x40 ]. Column шапки — `mainAxisSize.min`; высота контейнера шапки не превышает collapsedHeight → overflow исключён.

    Список. Внутри раскрытой области — обычный `ListView.builder` со СВОИМ `ScrollController`, скроллится независимо и только когда панель раскрыта; его жесты в отдельной арене под GestureDetector шапки, поэтому drag шапки списком не перехватывается. При наличии логов рисуй ListView, при пустом буфере — существующий `_EmptyState` ('Waiting for events' + подзаголовок). В collapsed логи можно не показывать (виден только шапка).

    Сохрани функциональность: авто-скролл к хвосту через `BlocConsumer<LogsCubit, LogsState>` listener `_followTail` (animateTo к maxScrollExtent на новых логах, `OkoMotion.autoscroll`/`autoscrollCurve`); pause/resume через `NotificationListener<ScrollNotification>` на списке с `_syncAutoScroll` (порог `_bottomThreshold`), логика pause/resume как в текущем коде. Кнопка Copy: `Clipboard.setData(cubit.plainText())` + `HapticFeedback.selectionClick` + снэкбар 'Copied N lines'. Семантика: Semantics(button:true, label 'Toggle logs panel') на шапке, header:true на 'Logs', button+label 'Copy all logs' на кнопке.

    vpn_home_screen.dart: замени резерв `sheetPeek = height * 0.12` на `LogConsole.collapsedHeight` для нижнего SizedBox колонки (убери магический множитель 0.12), LogConsole оставь последним child в Stack — панель сама прижимается к низу. Проверь, что ConnectButton не перекрывается свёрнутой панелью.

    Тесты log_console_test.dart (обнови сломавшиеся + добавь новые). Учти, что список теперь виден только после раскрытия — там, где нужны LogLine/EmptyState, сперва раскрывай панель (тап или drag по шапке) и `await tester.pumpAndSettle()`:
    - renders LogLine per entry: добавь 3 лога, раскрой панель, ожидай 3 LogLine.
    - empty state 'Waiting for events' виден после раскрытия пустой панели.
    - тап по шапке раскрывает панель (новый): tap header → pumpAndSettle → панель раскрыта (LogLine видны / высота выросла).
    - свайп вверх по шапке раскрывает (новый): `tester.drag` по области шапки Offset(0,-300) → pumpAndSettle → раскрыта.
    - drag шапки при наличии логов раскрывает, НЕ скролля список (ядро Фикс 4): добавь логи, drag по шапке вверх → раскрыта и LogLine видны.
    - copy-all пишет plainText в буфер (сохрани существующий кейс, кнопка Copy доступна и в collapsed).
    - H-01 авто-скролл: адаптируй под новый ListView + контроллер (user drag по ListView в раскрытом состоянии ставит autoScroll=false; всплеск логов не сбрасывает autoScroll).
  </action>
  <verify>
    <automated>flutter test test/features/vpn_logs/presentation/widgets/log_console_test.dart test/features/vpn_connection/presentation/screens/vpn_home_screen_test.dart && flutter analyze</automated>
  </verify>
  <done>LogConsole — кастомная панель на AnimationController; шапка это отдельная drag-поверхность (тап и свайп раскрывают/сворачивают, не конфликтуя со скроллом списка); список скроллится независимо в раскрытом виде; RenderFlex overflow отсутствует; Copy, пустое состояние, авто-скролл (pause/resume), семантика и haptics сохранены; SafeArea снизу учтён; vpn_home_screen резервирует collapsedHeight; widget-тесты (тап, свайп, drag-с-логами, copy, авто-скролл) зелёные; flutter analyze без issues.</done>
</task>

</tasks>

<verification>
- `flutter analyze` — ноль issues (very_good_analysis, public_member_api_docs:false).
- `flutter test` — весь набор зелёный (test-as-you-go: перед завершением гоняется полностью).
- Правки только в presentation-слое (форматтер + два виджета + экран) и тестах; LogsCubit/LogsState/Bloc не тронуты.
- Ни одного комментария в изменённом Dart-коде.
</verification>

<success_criteria>
- Таймер: mm:ss ниже часа, hh:mm:ss с часа; мягкая тень в обеих темах.
- Лог-панель: без RenderFlex overflow; тап и свайп вверх по шапке раскрывают; drag шапки при наличии логов раскрывает панель, а не скроллит список; независимый скролл списка в раскрытом виде.
- Сохранены Copy (снэкбар 'Copied N lines'), пустое состояние, авто-скролл pause/resume, haptics, семантика, SafeArea снизу.
- `flutter analyze` чист, полный `flutter test` зелёный.
- Три атомарных conventional-коммита с русским описанием (по одному на задачу).
</success_criteria>

<output>
Create `.planning/quick/260714-ilt-ui-vpn-overflow-sliding-up-mm-ss/260714-ilt-SUMMARY.md` when done
</output>
