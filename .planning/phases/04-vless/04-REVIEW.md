---
phase: 04-vless
reviewed: 2026-07-14T01:32:53Z
depth: deep
files_reviewed: 13
files_reviewed_list:
  - lib/features/server_config/domain/services/vless_parser.dart
  - lib/features/server_config/domain/entities/vless_config.dart
  - lib/features/server_config/domain/entities/vless_parse_result.dart
  - lib/features/server_config/domain/entities/latency_result.dart
  - lib/features/server_config/domain/repositories/latency_probe.dart
  - lib/features/server_config/domain/repositories/clipboard_source.dart
  - lib/features/server_config/data/probes/socket_latency_probe.dart
  - lib/features/server_config/data/datasources/clipboard_source_impl.dart
  - lib/features/server_config/presentation/cubit/server_config_cubit.dart
  - lib/features/server_config/presentation/cubit/server_config_state.dart
  - lib/features/server_config/presentation/widgets/vless_config_card.dart
  - lib/features/server_config/presentation/widgets/paste_config_button.dart
  - lib/features/server_config/presentation/widgets/vless_error_text.dart
findings:
  critical: 1
  blocker: 1
  warning: 5
  info: 3
  total: 9
status: issues_found
---

# Phase 4: Code Review Report — VLESS-конфиг сервера

**Reviewed:** 2026-07-14T01:32:53Z
**Depth:** deep
**Files Reviewed:** 13 (+ интеграция в `di.dart`, `app.dart`, `vpn_home_screen.dart`)
**Status:** issues_found

## Summary

Разобрал новую feature `server_config` целиком: парсер `vless://`, sealed result-типы, TCP-пробу задержки, cubit и три виджета, плюс их интеграцию в DI и домашний экран. Архитектурные требования выдержаны: cubit зависит только от domain-абстракций (`ClipboardSource`, `LatencyProbe`, `parseVless`), а не от data-слоя; result-типы sealed и exhaustive; карточка рендерится через `BlocBuilder<ServerConfigCubit, ServerConfigState>`, так что вставка реактивно обновляет дерево; граница «display-only» соблюдена — вставленный конфиг не проходит в реальный Connect (кнопка шлёт `ConnectRequested` в `VpnConnectionBloc` с `demoConfig`). Новых пакетов не добавлено.

Одна критическая проблема: парсер **бросает наружу** `FormatException` на битом percent-encoded фрагменте (проверено эмпирически на Dart), что прямо нарушает контракт «парсер не бросает». Плюс пять предупреждений вокруг устойчивости cubit и пробы (emit после close, отсутствие try/catch вокруг внешних вызовов, узкий catch пробы, гонка при повторной вставке) и слабость маскировки UUID.

Проверенные вручную ловушки `Uri` (эмпирически, Dart-сниппет): фрагмент возвращается **сырым** (`My%20Server`), так что ручной `decodeComponent` — корректный single-decode, а не двойной; IPv6-хост отдаётся **без скобок** (`2606:4700:4700::1111`), карточка правильно оборачивает по `contains(':')`; порт вне диапазона (`:70000`) парсится и ловится ручной проверкой, огромный порт (`:99999999999999999999`) даёт `FormatException` → `malformed`, порт `0` даёт `hasPort=false` → `port`. Эти пути в порядке.

CONVENTION-проверки (JS/TS rule-packs) пропущены: проект чистый Dart, для него rule-pack отсутствует — graceful skip, находок нет.

## Critical Issues

### CR-01: `parseVless` бросает `FormatException` наружу на битом percent-encoded фрагменте

**File:** `lib/features/server_config/domain/services/vless_parser.dart:31-33` (try/catch — только `12-16`)
**Issue:**
`Uri.decodeComponent(uri.fragment)` вызывается **вне** `try/catch`, который покрывает лишь `Uri.parse`. `Uri.fragment` возвращает сырой (нормализованный) фрагмент, а `Uri.decodeComponent` бросает `FormatException` на некорректной UTF-8-последовательности в percent-кодировании. Проверено на Dart:

```
parse(#%D0) ok, fragment = "%D0"
decodeComponent(#%D0) THREW: FormatException: Unfinished UTF-8 octet sequence (at offset 1)
decodeComponent(#%FF) THREW: FormatException
```

Триггер реалистичен: имя сервера в share-ссылке приходит из буфера обмена (недоверенный ввод); обрезанный многобайтовый символ (`#%D0`) или невалидный байт (`#%FF`) — обычный результат порчи при копировании. `Uri.parse` такой фрагмент принимает, падает уже `decodeComponent`. Исключение уходит из `parseVless`, дальше из `ServerConfigCubit.pasteFromClipboard` (там нет try/catch), а вызов в `vpn_home_screen.dart:75` идёт через `unawaited(...)` → необработанная async-ошибка вместо ожидаемого `VlessParseFailure(VlessError.malformed)`. Прямое нарушение требования «парсер не бросает наружу», и вставка такой ссылки не покажет «Ссылка повреждена».

Тест-кейсов на этот путь среди 11 нет — поэтому дефект и прошёл (см. IN-02).

**Fix:**
```dart
  final q = uri.queryParameters;
  final String name;
  try {
    name = uri.fragment.isEmpty
        ? uri.host
        : Uri.decodeComponent(uri.fragment);
  } on FormatException {
    return const VlessParseFailure(VlessError.malformed);
  }
  return VlessParsed(
    VlessConfig(
      uuid: uuid,
      ...
```
Либо fallback без отказа: `on FormatException { name = uri.host; }` — тогда битое имя не рушит валидный в остальном конфиг.

## Warnings

### WR-01: `emit` после `close()` без `isClosed`-guard в cubit

**File:** `lib/features/server_config/presentation/cubit/server_config_cubit.dart:26-27`
**Issue:**
Между `await probe.measure(config.host, config.port)` (до 3 с при дефолтном таймауте пробы) и `emit(ServerConfigLoaded(config, latency: latency))` cubit может быть закрыт (пользователь ушёл с экрана, `BlocProvider` вызвал `close()`). `Cubit.emit` после `close()` бросает `StateError('Cannot emit new states after calling close')` и **rethrow'ит** его. Так как `pasteFromClipboard` дёргается через `unawaited(...)` (`vpn_home_screen.dart:75`), ошибка становится необработанной. То же касается emit'ов после первого `await clipboard.readText()`. Это ровно тот класс «emit после dispose», что вынесен в фокус ревью.

**Fix:**
```dart
      case VlessParsed(:final config):
        if (isClosed) return;
        emit(ServerConfigLoaded(config));
        final latency = await probe.measure(config.host, config.port);
        if (isClosed) return;
        emit(ServerConfigLoaded(config, latency: latency));
```

### WR-02: `pasteFromClipboard` не оборачивает внешние вызовы в try/catch

**File:** `lib/features/server_config/presentation/cubit/server_config_cubit.dart:15-29`
**Issue:**
`clipboard.readText()` (за ним `Clipboard.getData` — может бросить `PlatformException` при отказе доступа к буферу) и `probe.measure(...)` вызываются без обработки исключений. Любое исключение уходит из метода и, из-за `unawaited`-вызова, становится необработанной async-ошибкой. Пользователь не получит понятного состояния ошибки. Cubit — правильное место для перевода сбоя внешнего мира в состояние.

**Fix:** обернуть тело в `try { ... } on Object { if (!isClosed) emit(const ServerConfigError(VlessError.malformed)); }` (или отдельный enum-код для сбоя буфера/сети).

### WR-03: `SocketLatencyProbe.measure` ловит только `SocketException`

**File:** `lib/features/server_config/data/probes/socket_latency_probe.dart:29-31`
**Issue:**
`catch` покрывает лишь `SocketException`. Дефолтный `_defaultConnect` в норме бросает именно её (в т.ч. на таймауте), но при иных ошибках платформы или при инъецированном `connector`, кидающем не-`SocketException`, исключение уходит из `measure` и дальше — необработанным (см. WR-02). Проба задержки — необязательный сигнал; сбой должен деградировать в `LatencyUnreachable`, а не валить поток.

**Fix:**
```dart
    } on Object {
      return const LatencyUnreachable();
    }
```
(сокет при этом не течёт: на исключении `Socket.connect` объект не создан; на успехе `socket.destroy()` вызывается — путь ресурса корректен.)

### WR-04: `maskUuid` показывает первые 8 hex-символов UUID-креденшла в дереве

**File:** `lib/features/server_config/presentation/widgets/vless_config_card.dart:6-8`
**Issue:**
В VLESS `uuid` — это секрет аутентификации (аналог пароля). `maskUuid` рендерит `первые 8 … последние 4` — 12 из 36 символов, включая ведущие 8. Полная строка в дереве отсутствует (требование «не виден целиком» формально выполнено, тест это проверяет), но ведущие 8 hex-символов секрета попадают в виджет-дерево и на любой скриншот. Для «надёжной» маскировки это слабо.

**Fix:** показывать только хвост или полностью маскировать:
```dart
String maskUuid(String uuid) =>
    uuid.length >= 4 ? '••••${uuid.substring(uuid.length - 4)}' : '••••';
```

### WR-05: гонка при повторной вставке — поздний `measure` перетирает более новый конфиг

**File:** `lib/features/server_config/presentation/cubit/server_config_cubit.dart:24-27`
**Issue:**
Если пользователь вставит вторую ссылку, пока `probe.measure` первой ещё в полёте, две async-цепочки идут параллельно. Порядок завершения `measure` не гарантирован: поздно завершившийся замер первого конфига вызовет `emit(ServerConfigLoaded(configA, latency: ...))` поверх уже показанного `configB` — устаревшее состояние. Для прототипа с одной кнопкой вероятность низкая, но корректность нарушена.

**Fix:** ввести токен операции (счётчик/`Object`), сверять его перед пост-await emit'ом и игнорировать результат устаревшей цепочки; заодно закрывает часть WR-01.

## Info

### IN-01: `parseVless('')` возвращает `VlessError.scheme`, а не `VlessError.empty`

**File:** `lib/features/server_config/domain/services/vless_parser.dart:17-19`
**Issue:**
`Uri.parse('')` даёт пустую схему → парсер отдаёт `scheme` («Это не vless://-ссылка»). Значение `VlessError.empty` парсер не возвращает никогда — его выставляет только cubit (`server_config_cubit.dart:18`) по предварительной проверке `raw.trim().isEmpty`. Пока cubit гейтит пустой ввод до вызова парсера, расхождение не всплывает, но при прямом/повторном использовании парсера пустая строка даст вводящую в заблуждение ошибку «чужая схема».
**Fix:** в начале `parseVless` добавить `if (raw.isEmpty) return const VlessParseFailure(VlessError.empty);` — тогда парсер самодостаточен и семантика `empty` консистентна.

### IN-02: пробелы в тест-покрытии edge-кейсов

**File:** `test/features/server_config/domain/vless_parser_test.dart`, `test/features/server_config/presentation/server_config_cubit_test.dart`
**Issue:**
11 кейсов парсера не включают битый percent-encoded фрагмент (`#%D0`/`#%FF`), из-за чего CR-01 прошёл незамеченным. Тесты cubit не покрывают путь исключения из `clipboard`/`probe` (WR-02) и emit после `close()` (WR-01). Тест «percent-encoded имя» на `%20`/эмодзи проходит и при двойном декоде, и при отсутствии декода — он не пиннит поведение фрагмента.
**Fix:** добавить кейсы: `parseVless('vless://<uuid>@h:443#%D0')` → `VlessParseFailure` (после фикса CR-01), и cubit-тест с fake-пробой/буфером, бросающими исключение.

### IN-03: `Duration(milliseconds: sw.elapsedMilliseconds)` теряет точность

**File:** `lib/features/server_config/data/probes/socket_latency_probe.dart:28`
**Issue:**
Пересборка `Duration` из миллисекунд усекает субмиллисекундную часть и избыточна. `sw.elapsed` уже возвращает `Duration` с микросекундной точностью.
**Fix:** `return LatencyMeasured(sw.elapsed);`

---

_Reviewed: 2026-07-14T01:32:53Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
