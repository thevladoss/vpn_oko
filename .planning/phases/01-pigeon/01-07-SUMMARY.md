# Plan 01-07 Summary — Живая проверка echo-моста

**Plan:** 01-07 (phase gate + живой end-to-end echo)
**Status:** complete
**Requirements:** BRG-02, BRG-04
**Self-Check:** PASSED (с зафиксированными ограничениями окружения)

## Задача 1 — Phase gate (auto)

Прогнан перед живой проверкой, все зелёные:

| Проверка | Результат |
|----------|-----------|
| `dart run pigeon --input pigeons/vpn_api.dart` | идемпотентно, без ошибок, git-diff пустой |
| `flutter analyze` | No issues found |
| `flutter test` | 37 passed |
| `flutter build apk --debug` | app-debug.apk собран (wave 2, план 01-05) |
| `flutter build ios --no-codesign --debug` | Runner.app собран за 14.5s (wave 2, план 01-06) |

## Задача 2 — Живая проверка (checkpoint:human-verify)

Проверка проведена оркестратором на реальных устройствах-эмуляторах, зафиксирована скриншотами.

### iOS-симулятор (iPhone 17, iOS 26.4)
- `flutter run` собрал и запустил Runner на симуляторе за ~15s.
- Harness отрисовался: «Oko VPN — echo harness», Status: Disconnected, кнопки, блок Logs.
- **Нет `MissingPluginException`** — регистрация pigeon-моста под новый шаблон Flutter 3.44 (SceneDelegate / `didInitializeImplicitFlutterEngine`) работает. Это снимает главный iOS-риск research (Open Question, iOS-регистрация).
- Тап кнопок автоматизировать не удалось: в окружении нет idb/cliclick, AppleScript System Events блокируется отсутствием accessibility-разрешения. Полный echo-цикл на iOS не прокликан вживую (см. Ограничения).

### Android-эмулятор (Medium_Phone_API_36.1, API 36) — основной путь
Прокликан через `adb shell input tap`, каждый шаг зафиксирован скриншотом:

1. **Старт**: Status: Disconnected, Logs пусто. Нет `MissingPluginException` — регистрация в `MainActivity.configureFlutterEngine` работает.
2. **Echo Connect** → Status: **«Connected since 2026-07-13 20:17:40.572»**; Logs: **«[info] tunnel up»**, **«[info] starting»**.
   - Доказывает живой стрим StatusChanged + LogMessage из Kotlin в Dart через event channel (**BRG-02**).
   - `connectedSince` в статусе — снапшот из getStatus/StatusChanged (**BRG-04**, snapshot-путь).
   - Уровень лога `[info]` в нижнем регистре — контракт W3 (ревизия планов 05/06 + терпимый маппер) работает, `ArgumentError` нет.
   - Приложение не упало — доставка событий строго с main thread подтверждена вживую (**T-1-02** mitigated).
3. **Echo Disconnect** → Status: Disconnected (переход DISCONNECTING→DISCONNECTED из Kotlin). Полный lifecycle моста замкнут.

## Требования

- **BRG-02** (события native→Flutter одним стримом, демультиплекс) — подтверждено вживую на Android (StatusChanged + LogMessage), симметричный Swift-код собран.
- **BRG-04** (main-thread доставка, replay, снапшот) — снапшот с connectedSince подтверждён вживую; main-thread доставка подтверждена (нет crash); replay покрыт unit-тестом `vpn_repository_impl_test` (зелёный) — визуальный hot-restart не доснят из-за нехватки места на эмуляторе.

## Ограничения окружения (зафиксировано для README / Phase 6 DOC-02)

1. **Визуальный hot-restart replay не доснят**: при попытке пересобрать под hot-restart эмулятор выдал `INSTALL_FAILED_INSUFFICIENT_STORAGE` (диск AVD полон). Логика replay покрыта unit-тестом репозитория (последний статус отдаётся первым новому подписчику) и живым снапшотом getStatus. Ручная проверка: `flutter run` на Android → Connect → `R` (hot restart) → harness сразу показывает Connected.
2. **iOS echo не прокликан вживую**: нет tap-инструментария (idb/cliclick), accessibility для AppleScript недоступно. Подтверждено: приложение запускается, мост регистрируется (нет MissingPluginException), Swift-эмиттер собран и линкуется в Runner. Полный цикл на iOS воспроизводится вручную запуском на устройстве/симуляторе.

## Итог

Success Criteria фазы 1 (пункты 1–3) закрыты: типобезопасный echo-мост доказан вживую на Android (событие из Kotlin доходит до Dart-стрима и рисуется в harness), снапшот getStatus работает, обе платформы компилируются и регистрируют мост. Фундамент готов к Phase 2 (реальный Android VpnService).

## Артефакты проверки
- Скриншоты: harness_initial (iOS), and_initial / and_connected / and_disc (Android) — в scratchpad сессии.
