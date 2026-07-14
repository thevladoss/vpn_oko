---
phase: 04-vless
fixed_at: 2026-07-14T01:49:57Z
review_path: .planning/phases/04-vless/04-REVIEW.md
iteration: 1
findings_in_scope: 9
fixed: 9
skipped: 0
status: all_fixed
---

# Phase 4: Code Review Fix Report — VLESS-конфиг сервера

**Fixed at:** 2026-07-14T01:49:57Z
**Source review:** .planning/phases/04-vless/04-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 9
- Fixed: 9
- Skipped: 0

Все 9 находок ревью закрыты. Каждый фикс — атомарный коммит `fix(04): ...`
с тестом в том же заходе. Гейты после фиксов: `flutter analyze` без issues,
`flutter test` 147/147 зелёных, `flutter build apk --debug` собран.

## Fixed Issues

### CR-01: `parseVless` бросал `FormatException` на битом percent-фрагменте

**Files modified:** `lib/features/server_config/domain/services/vless_parser.dart`, `test/features/server_config/domain/vless_parser_test.dart`
**Commit:** 88b4a35
**Applied fix:** `uri.queryParameters` и `Uri.decodeComponent(uri.fragment)`
обёрнуты в общий `try/catch`; любой ввод с битой UTF-8 percent-кодировкой
даёт `VlessParseFailure(malformed)`, а не необработанную async-ошибку.
Эмпирически проверено, что `queryParameters` тоже бросает `FormatException`
на `?sni=%D0` — поэтому catch расширен на весь хвост, а не только на fragment.
Тесты: `#%D0`, `#%FF`, `?sni=%D0`.

### WR-01: `emit` после `close()` без `isClosed`-guard в cubit

**Files modified:** `lib/features/server_config/presentation/cubit/server_config_cubit.dart`, `test/features/server_config/presentation/server_config_cubit_test.dart`
**Commit:** cde5979
**Applied fix:** `if (isClosed) return;` после каждого `await` (readText и measure).
Тест закрывает cubit во время gated-measure и проверяет, что StateError не
летит и loaded-с-latency после close не эмитится. Concurrency-guard покрыт
поведенческим тестом.

### WR-02: внешние вызовы cubit без try/catch

**Files modified:** `lib/features/server_config/presentation/cubit/server_config_cubit.dart`, `test/helpers/fake_clipboard_source.dart`, `test/helpers/fake_latency_probe.dart`, `test/features/server_config/presentation/server_config_cubit_test.dart`
**Commit:** 3ab74a2
**Applied fix:** `clipboard.readText()` и `probe.measure()` под `on Object`.
Сбой буфера → `ServerConfigError(malformed)`; сбой пробы деградирует в
`ServerConfigLoaded(config, latency: unreachable)` без потери валидного
конфига. Fakes получили опциональный `errorToThrow` (тип `Exception?`, чтобы
не ловить `only_throw_errors`). Тесты на оба пути.

### WR-03: `SocketLatencyProbe.measure` ловил только `SocketException`

**Files modified:** `lib/features/server_config/data/probes/socket_latency_probe.dart`, `test/features/server_config/data/socket_latency_probe_test.dart`
**Commit:** f4bdac7
**Applied fix:** `catch` расширен до `on Object` — `TimeoutException`, ошибки
платформы и любой не-`SocketException` из инъецированного connector дают
`LatencyUnreachable`, а не утечку. Заодно закрыт IN-03: `sw.elapsed` вместо
`Duration(milliseconds: sw.elapsedMilliseconds)` (без потери субмиллисекунд).
Тесты на `TimeoutException` и `StateError`.

### WR-04: `maskUuid` показывал первые 8 hex UUID-креденшла

**Files modified:** `lib/features/server_config/presentation/widgets/vless_config_card.dart`, `test/features/server_config/presentation/vless_config_card_test.dart`
**Commit:** 460fc06
**Applied fix:** маска сведена к хвосту — `••••<последние 4>`. Ведущие 8 hex
секрета больше не попадают в дерево/скриншот. Widget-тест обновлён:
`b831381d` теперь `findsNothing`, `••••0811` `findsOneWidget`.

### WR-05: гонка при повторной вставке — поздний measure перетирал новый конфиг

**Files modified:** `lib/features/server_config/presentation/cubit/server_config_cubit.dart`, `test/features/server_config/presentation/server_config_cubit_test.dart`
**Commit:** c68567e
**Applied fix:** введён `int _generation`; каждый заход берёт свою генерацию
`++_generation` и сверяет её перед post-await emit. Устаревшая цепочка молча
завершается, поверх нового конфига не эмитит. Заодно усиливает WR-01. Тест:
две быстрые вставки (a.example, b.example) с инверсией порядка завершения
measure → финальное состояние держит b.example с его latency.

### IN-01: `parseVless('')` возвращал `scheme` вместо `empty`

**Files modified:** `lib/features/server_config/domain/services/vless_parser.dart`, `test/features/server_config/domain/vless_parser_test.dart`
**Commit:** 7de3288
**Applied fix:** ранний `if (raw.isEmpty) return VlessParseFailure(empty);`
после trim. Парсер самодостаточен, семантика `empty` консистентна с cubit.
`VlessError.empty` уже существовал в enum. Существующий тест разделён на
scheme и empty-кейсы.

### IN-02: пробелы в тест-покрытии edge-кейсов

**Files modified:** покрыто тестами в коммитах 88b4a35, cde5979, 3ab74a2, c68567e
**Commit:** 88b4a35, cde5979, 3ab74a2, c68567e
**Applied fix:** добавлены недостающие кейсы, из-за отсутствия которых CR-01
прошёл незамеченным: битый percent-фрагмент/query (парсер), исключения
clipboard/probe (cubit), emit после close, гонка повторной вставки.

### IN-03: `Duration(milliseconds: sw.elapsedMilliseconds)` терял точность

**Files modified:** `lib/features/server_config/data/probes/socket_latency_probe.dart`
**Commit:** f4bdac7
**Applied fix:** `return LatencyMeasured(sw.elapsed);` — микросекундная точность
без пересборки Duration. Свёрнут в коммит WR-03 (тот же метод `measure`).

## Gates

- `flutter analyze` — No issues found
- `flutter test` — 147/147 passed (server_config: 14 парсер, 8 cubit, 6 проба, 12 карточка)
- `flutter build apk --debug` — Built build/app/outputs/flutter-apk/app-debug.apk

## Границы

Изменения строго в Dart-слое feature `server_config` фазы 4 и её тестах, плюс
два общих fake-хелпера (`test/helpers/`). Native/сгенерированный код и другие
фичи не тронуты. Комментариев в коде нет (конвенция проекта).

---

_Fixed: 2026-07-14T01:49:57Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
