# Phase 4: VLESS-конфиг сервера — Research

**Researched:** 2026-07-14
**Domain:** Парсинг `vless://` URI на чистом Dart, TCP-замер задержки (tcping), вставка из буфера, карточка конфига в существующем Flutter-экране
**Confidence:** HIGH (поведение `Uri.parse`, `Socket.connect`, `Clipboard` проверено эмпирически на SDK проекта — Dart 3.12.2 / Flutter 3.44.5; спецификация VLESS-ссылки снята с первоисточника XTLS)

## Summary

Фаза целиком укладывается в стандартную библиотеку. `vless://` — это URI, а не JSON: `Uri.parse` из `dart:core` разбирает схему, `userInfo` (uuid), host, port, query-параметры и fragment без единого пакета. tcping — это `Socket.connect(host, port, timeout:)` из `dart:io` плюс `Stopwatch`. Вставка из буфера — `Clipboard.getData` из `flutter/services`. Новых зависимостей ноль: `equatable`, `flutter_bloc`, `bloc_test`, `mocktail`, `flutter_test` уже в `pubspec.yaml`.

Проверка `Uri.parse` на реальном SDK вскрыла три ловушки, которые определяют форму парсера: `Uri.fragment` возвращает percent-encoded строку и требует ручного `Uri.decodeComponent` (при этом `queryParameters` декодируется сам); `Uri.parse` не валидирует диапазон порта (`:70000` проходит), но бросает `FormatException` на нечисловой порт и на ведущий пробел. Значит парсер обязан: `trim()` вход, обернуть `Uri.parse` в try/catch, вручную проверить `hasPort` и диапазон 1..65535, и звать `decodeComponent` ровно для fragment.

Архитектурно фаза добавляет новую feature `server_config` (feature-first CA). Парсер — чистая функция в domain (тесты без моков, ядро QA-01). tcping прячется за абстракцией `LatencyProbe` в domain, реализация на `dart:io` — в data (инъекция фейка в тестах, никакой реальной сети в автосьюте). Буфер прячется за `ClipboardSource`, чтобы cubit-тесты не били в platform channel. `VlessConfig` — богаче существующего `VpnConfig`; маппер `toVpnConfig()` сводит его к 4 полям моста (host, port, uuid→userId, name→serverName). Карточка — новый виджет `VlessConfigCard`, не трогающий phase-3 `ServerCard` (у него уже есть контракт в UI).

**Primary recommendation:** Новая feature `server_config`. Парсер — чистая функция `String → VlessParseResult` (sealed) поверх `Uri.parse` с ручной валидацией порта/uuid/host и `Uri.decodeComponent(uri.fragment)`. tcping и буфер — за domain-абстракциями (`LatencyProbe`, `ClipboardSource`), реализации на `dart:io`/`flutter/services` в data. UI — `ServerConfigCubit` + `VlessConfigCard` с реактивным `BlocBuilder`, UUID маскируется. Ноль новых пакетов.

## Project Constraints (from CLAUDE.md + CONVENTIONS.md)

Эти директивы имеют силу locked-решений. Планировщик обязан их соблюсти.

- **Feature-first Clean Architecture:** `lib/features/<feature>/{domain,data,presentation}`; общее — в `core/`/`app/`. `[CITED: .planning/codebase/CONVENTIONS.md]`
- **SOLID через абстракции:** presentation не знает про data; зависимости инъектятся в composition root `lib/app/di.dart`. `[CITED: CONVENTIONS.md]`
- **Комментарии в коде запрещены** (Dart/Kotlin/Swift). Имена несут смысл. `[CITED: CONVENTIONS.md]`
- **State management только Bloc/Cubit** (`flutter_bloc`); виджеты — только `BlocBuilder`/`BlocListener` и разметка. `[CITED: CONVENTIONS.md]`
- **Domain-модели: sealed + equatable, immutable.** Никакого freezed/json_serializable; единственный кодоген проекта — pigeon. `[CITED: CONVENTIONS.md]`
- **Ошибки:** типизированные (`sealed Failure`/sealed result), UI получает доменные ошибки, не строки платформы. `[CITED: CONVENTIONS.md, lib/core/error/failures.dart]`
- **Тесты test-as-you-go:** код → тесты → прогон в том же заходе; перед коммитом весь набор зелёный. `mocktail` для моков. Приоритет: VLESS-парсер. `[CITED: CONVENTIONS.md, глобальный CLAUDE.md]`
- **Язык:** код и идентификаторы — английский; доки, коммиты, общение — русский. `[CITED: CONVENTIONS.md, глобальный CLAUDE.md]`
- **Коммиты:** атомарные по задачам, conventional commits (`feat:`/`test:`/`fix:`) с русским описанием. `[CITED: CONVENTIONS.md]`
- **stop-slop для всего текста** (доки, commit messages): без филлеров, активный залог, без em-dash. `[CITED: глобальный CLAUDE.md]`

> CONTEXT.md для этой фазы отсутствует (каталог `.planning/phases/04-vless/` пуст — `/gsd:discuss-phase` не запускался). Раздел «User Constraints» опущен намеренно; ограничения выше сняты с CONVENTIONS.md, ROADMAP.md и CLAUDE.md.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VLS-01 | Парсер `vless://` → `VlessConfig` (uuid, host, port, type, security, sni, name); кривые ссылки дают внятные ошибки | `Uri.parse` + ручная валидация (раздел «Парсер: алгоритм»); sealed `VlessParseResult` для ошибок; edge-cases проверены эмпирически (раздел «Проверенное поведение Dart Uri.parse») |
| VLS-02 | Вставка `vless://` из буфера + карточка распарсенного конфига | `Clipboard.getData` за `ClipboardSource`-абстракцией; `ServerConfigCubit` + `VlessConfigCard`; интеграция в `VpnHomeScreen` через `BlocBuilder` (раздел «Вставка из буфера», «Интеграция в экран фазы 3») |
| VLS-03 | Замер задержки через TCP connect time (tcping) с таймаутом | `Socket.connect(host, port, timeout:)` + `Stopwatch` за `LatencyProbe`-абстракцией; тайминг и обработка недоступности проверены (раздел «tcping») |
| QA-01 | Unit-тесты парсера: валидные, кривые, edge cases | Полный список кейсов в разделе «Validation Architecture» → «Phase Requirements → Test Map»; чистые unit-тесты без сети/платформы |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Парсинг `vless://` → `VlessConfig` | Domain (чистый Dart) | — | Ни I/O, ни платформы; чистая функция, тестируется без моков. Ядро QA-01 |
| Валидация ошибок ссылки | Domain | — | Sealed `VlessParseResult`; доменная ошибка, не строка платформы |
| tcping (TCP connect time) | Data (`dart:io` Socket) | Domain (абстракция `LatencyProbe`) | Сетевой I/O живёт в data; domain видит только интерфейс — инъекция фейка в тестах |
| Чтение буфера обмена | Data (`flutter/services`) | Domain (абстракция `ClipboardSource`) | Platform channel — инфраструктура; за абстракцией cubit-тесты не бьют в канал |
| Оркестрация paste→parse→measure | Presentation (`ServerConfigCubit`) | — | Bloc-слой связывает domain-сервисы; виджеты только рендерят |
| Карточка конфига + маскировка UUID | Presentation (`VlessConfigCard`) | — | Чистая разметка поверх `BlocBuilder`; UUID не показывается целиком |
| Маппинг `VlessConfig` → `VpnConfig` для моста | Domain (mapper) | — | Мост принимает 4 поля; сведение — доменная трансформация |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `dart:core` `Uri` | SDK (Dart 3.12.2) | Разбор `vless://` URI | Штатный RFC-3986 парсер: схема, userInfo, host (с IPv6-скобками), port, queryParameters, fragment. Ноль зависимостей `[VERIFIED: эмпирическая проверка на SDK проекта]` |
| `dart:io` `Socket` | SDK | tcping — TCP connect time | `Socket.connect(host, port, timeout:)` даёт встроенный таймаут и DNS-резолв; `Stopwatch` меряет; `.destroy()` закрывает `[VERIFIED: socket_probe.dart, 56ms до example.com:443, SocketException на недоступный]` |
| `flutter/services` `Clipboard` | SDK (Flutter 3.44.5) | Чтение буфера | `Clipboard.getData(Clipboard.kTextPlain)` → `ClipboardData?`; штатный API, без пакета и без Android-permission `[CITED: api.flutter.dev — Clipboard]` |
| `equatable` | ^2.1.0 (в pubspec) | Value equality для `VlessConfig`, sealed-результатов | Тесты сравнивают конфиги целиком; `==`/`hashCode` без кодогена. Уже используется в проекте `[VERIFIED: pubspec.yaml, lib/.../vpn_config.dart]` |
| `flutter_bloc` | ^9.1.1 (в pubspec) | `ServerConfigCubit` | Единственный разрешённый state-management в проекте `[VERIFIED: pubspec.yaml, CONVENTIONS.md]` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `flutter_test` | SDK | Unit/widget тесты | Парсер, cubit, виджет карточки `[VERIFIED: pubspec.yaml]` |
| `bloc_test` | ^10.0.0 (в pubspec) | Тесты переходов `ServerConfigCubit` | `blocTest` для paste-valid/paste-invalid/latency `[VERIFIED: pubspec.yaml]` |
| `mocktail` | ^1.0.5 (в pubspec) | Фейки `LatencyProbe`/`ClipboardSource` | Мок абстракций domain без кодогена `[VERIFIED: pubspec.yaml]` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Uri.parse` + ручная валидация | Ручной split по `@`, `:`, `?`, `#` | Ручной split ломается на IPv6-скобках, percent-encoding, отсутствующих сегментах. `Uri` покрывает RFC даром `[ASSUMED]` |
| RegExp для UUID | Пакет `uuid` | `uuid` тянется ради одной проверки формата; regex `^[0-9a-fA-F]{8}-...{12}$` достаточно `[VERIFIED: uri_probe2.dart — regex различает валидный/невалидный]` |
| Sealed `VlessParseResult` | `Either` из `dartz`/`fpdart` | Новый пакет ради одного result-типа; sealed class + pattern matching Dart 3 закрывает то же без зависимости. Совпадает с проектным паттерном (`sealed Failure`, `sealed VpnState`) `[CITED: CONVENTIONS.md]` |
| Абстракция `LatencyProbe` | Прямой вызов `Socket.connect` в cubit | Прямой вызов делает cubit непроверяемым без сети; абстракция = инъекция фейка `[ASSUMED]` |

**Installation:**
```bash
# Новых пакетов НЕ требуется. Всё уже в pubspec.yaml:
#   equatable ^2.1.0, flutter_bloc ^9.1.1
#   dev: bloc_test ^10.0.0, mocktail ^1.0.5, flutter_test (SDK)
# dart:core (Uri), dart:io (Socket), flutter/services (Clipboard) — часть SDK.
```

**Version verification:** SDK проекта подтверждён локально: `Dart SDK version: 3.12.2 (stable)`, `Flutter 3.44.5 • channel stable`. Все проектные зависимости зафиксированы в `pubspec.yaml` и `pubspec.lock`.

## Package Legitimacy Audit

Фаза **не устанавливает внешних пакетов**. Весь функционал — на стандартной библиотеке Dart/Flutter (`dart:core`, `dart:io`, `flutter/services`) и уже присутствующих в проекте зависимостях (`equatable`, `flutter_bloc`, `bloc_test`, `mocktail`, `flutter_test`).

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| — (новых нет) | — | — | — | — | N/A | Пакеты не добавляются |

**Packages removed due to slopcheck [SLOP] verdict:** none (устанавливать нечего)
**Packages flagged as suspicious [SUS]:** none

> slopcheck не запускался: гейт применяется, когда фаза ставит внешние пакеты. Здесь установки нет. Планировщику не нужен `checkpoint:human-verify` на установку в этой фазе.

## Architecture Patterns

### System Architecture Diagram

```
[ Буфер обмена ОС ]
        │  Clipboard.getData(kTextPlain)
        ▼
[ ClipboardSource (data) ]  ──abstraction──►  использует ServerConfigCubit
        │ String? raw
        ▼
[ ServerConfigCubit (presentation) ]
        │  raw.trim()
        ▼
[ parseVless(String) : VlessParseResult ]   (domain, чистая функция)
        │
        ├── VlessParseFailure(reason) ──► emit(state.error)  ──► текст ошибки в UI
        │
        └── VlessParsed(VlessConfig)
                 │  emit(state.config)  ──► VlessConfigCard (BlocBuilder)
                 │                            показывает name, host:port, type,
                 │                            security, sni, маскированный uuid
                 ▼
        [ LatencyProbe.measure(host, port) ]   (domain interface)
                 │        реализация: SocketLatencyProbe (data)
                 │        Socket.connect(host, port, timeout) + Stopwatch
                 ├── LatencyMeasured(Duration) ──► карточка: "· 56 ms"
                 └── LatencyUnreachable        ──► карточка: "· недоступен"

  (опционально) VlessConfig.toVpnConfig() ──► VpnConnectionBloc.config
                 для реального Connect выбранным сервером
```

### Recommended Project Structure
```
lib/features/server_config/
├── domain/
│   ├── entities/
│   │   ├── vless_config.dart          # VlessConfig extends Equatable (immutable)
│   │   ├── vless_parse_result.dart    # sealed: VlessParsed | VlessParseFailure
│   │   └── latency_result.dart        # sealed: LatencyMeasured | LatencyUnreachable
│   ├── services/
│   │   └── vless_parser.dart          # parseVless(String) : VlessParseResult (чистая)
│   ├── repositories/
│   │   └── latency_probe.dart         # abstract interface class LatencyProbe
│   └── mappers/
│       └── vless_to_vpn_config.dart   # VlessConfig -> VpnConfig (для моста)
├── data/
│   ├── datasources/
│   │   └── clipboard_source.dart      # abstract + SystemClipboardSource
│   └── probes/
│       └── socket_latency_probe.dart  # dart:io Socket.connect impl LatencyProbe
└── presentation/
    ├── cubit/
    │   ├── server_config_cubit.dart
    │   └── server_config_state.dart
    └── widgets/
        ├── paste_config_button.dart
        └── vless_config_card.dart
```

### Pattern 1: Парсер как чистая функция + sealed result
**What:** `parseVless(String raw)` возвращает `VlessParseResult` (sealed), не бросает исключения наружу и не делает I/O.
**When to use:** VLS-01, ядро QA-01. Чистота = тесты без моков, без сети, без платформы.
**Example:**
```dart
// domain/services/vless_parser.dart
// Source: поведение Uri.parse проверено на Dart 3.12.2 (uri_probe*.dart)
final _uuidRe = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

VlessParseResult parseVless(String input) {
  final raw = input.trim();
  final Uri uri;
  try {
    uri = Uri.parse(raw);
  } on FormatException {
    return const VlessParseFailure(VlessError.malformed);
  }
  if (uri.scheme != 'vless') {
    return const VlessParseFailure(VlessError.scheme);
  }
  final uuid = uri.userInfo;
  if (uuid.isEmpty || !_uuidRe.hasMatch(uuid)) {
    return const VlessParseFailure(VlessError.uuid);
  }
  if (uri.host.isEmpty) {
    return const VlessParseFailure(VlessError.host);
  }
  if (!uri.hasPort || uri.port < 1 || uri.port > 65535) {
    return const VlessParseFailure(VlessError.port);
  }
  final q = uri.queryParameters; // уже percent-decoded
  final name = uri.fragment.isEmpty
      ? uri.host
      : Uri.decodeComponent(uri.fragment); // fragment НЕ декодируется getter'ом
  return VlessParsed(
    VlessConfig(
      uuid: uuid,
      host: uri.host,
      port: uri.port,
      transport: q['type'] ?? 'tcp',
      security: q['security'] ?? 'none',
      sni: q['sni'],
      name: name,
    ),
  );
}
```

### Pattern 2: tcping за абстракцией `LatencyProbe`
**What:** Domain объявляет `abstract interface class LatencyProbe`; data реализует через `Socket.connect`. Cubit зависит от интерфейса.
**When to use:** VLS-03. Инъекция фейка в тестах, ноль реальной сети в автосьюте.
**Example:**
```dart
// domain/repositories/latency_probe.dart
abstract interface class LatencyProbe {
  Future<LatencyResult> measure(String host, int port);
}

// data/probes/socket_latency_probe.dart
// Source: socket_probe.dart — connect 56ms; SocketException(110) на недоступный
class SocketLatencyProbe implements LatencyProbe {
  const SocketLatencyProbe({this.timeout = const Duration(seconds: 3)});
  final Duration timeout;

  @override
  Future<LatencyResult> measure(String host, int port) async {
    final sw = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      sw.stop();
      return LatencyMeasured(Duration(milliseconds: sw.elapsedMilliseconds));
    } on SocketException {
      return const LatencyUnreachable();
    } finally {
      socket?.destroy();
    }
  }
}
```

### Pattern 3: Буфер за `ClipboardSource`
**What:** `Clipboard.getData` прячется за абстракцией, чтобы cubit-тесты не трогали platform channel.
**When to use:** VLS-02.
**Example:**
```dart
// data/datasources/clipboard_source.dart
abstract interface class ClipboardSource {
  Future<String?> readText();
}

class SystemClipboardSource implements ClipboardSource {
  const SystemClipboardSource();
  @override
  Future<String?> readText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }
}
```

### Pattern 4: `ServerConfigCubit` оркеструет paste → parse → measure
```dart
// presentation/cubit/server_config_cubit.dart
class ServerConfigCubit extends Cubit<ServerConfigState> {
  ServerConfigCubit({required this.clipboard, required this.probe})
      : super(const ServerConfigState.initial());
  final ClipboardSource clipboard;
  final LatencyProbe probe;

  Future<void> pasteFromClipboard() async {
    final raw = await clipboard.readText();
    if (raw == null || raw.trim().isEmpty) {
      emit(const ServerConfigState.error(VlessError.empty));
      return;
    }
    final result = parseVless(raw);
    switch (result) {
      case VlessParseFailure(:final error):
        emit(ServerConfigState.error(error));
      case VlessParsed(:final config):
        emit(ServerConfigState.loaded(config));
        final latency = await probe.measure(config.host, config.port);
        emit(ServerConfigState.loaded(config, latency: latency));
    }
  }
}
```

### Anti-Patterns to Avoid
- **Ручной split строки** вместо `Uri.parse`: ломается на IPv6 `[::1]`, percent-encoding и отсутствующих сегментах.
- **`Uri.decodeComponent` на `queryParameters`:** они уже декодированы — двойной декод портит `%`-содержащие значения.
- **`Socket.connect` прямо в cubit:** делает VLS-03 непроверяемым без сети; всегда за `LatencyProbe`.
- **Показ полного UUID в карточке или логах:** нарушает критерий «UUID маскируется» (см. Security Domain).
- **Чтение config через `context.read<...>().config` для карточки:** нереактивно; после вставки карточка не обновится. Карточка обязана сидеть в `BlocBuilder<ServerConfigCubit, ...>`.
- **Расширение phase-3 `ServerCard` под новые поля:** у него уже есть роль в `VpnHomeScreen`; лучше отдельный `VlessConfigCard`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Разбор `vless://` | Ручной парсер по разделителям | `Uri.parse` | RFC-3986, IPv6-скобки, percent-encoding, отсутствующие сегменты — всё покрыто SDK |
| Percent-decoding имени/параметров | Своя таблица `%XX` | `Uri.decodeComponent` / `Uri.queryParameters` | Корректный UTF-8 percent-decode (эмодзи в имени сервера) `[VERIFIED: uri_probe3.dart — "Tokyo 🇯🇵"]` |
| Таймаут TCP-коннекта | `Timer` + гонка с `Socket.connect()` | `Socket.connect(..., timeout:)` | Встроенный таймаут закрывает сокет и бросает `SocketException` без ручной гонки `[VERIFIED]` |
| Проверка формата UUID | Пакет `uuid` | `RegExp` 8-4-4-4-12 | Одна проверка формата не стоит зависимости |
| Result-тип ошибок | `dartz`/`fpdart` `Either` | sealed `VlessParseResult` | Dart 3 sealed + pattern matching; совпадает с проектным паттерном |
| Value equality | Ручные `==`/`hashCode` | `equatable` (уже в проекте) | Меньше кода, меньше багов в тестах сравнения |
| Моки в тестах | Ручные фейки везде | `mocktail` (для абстракций) | Проектный стандарт; чистые фейки для простых интерфейсов тоже ок |

**Key insight:** Вся фаза — это склейка четырёх готовых примитивов SDK (`Uri`, `Socket`, `Clipboard`, `Stopwatch`) плюс sealed-модели. Любой самописный аналог одного из них добавляет баги на edge-cases, которые SDK уже закрывает.

## Проверенное поведение Dart `Uri.parse` (эмпирика, SDK проекта)

Прогнал `Uri.parse` на выборке ссылок на `Dart 3.12.2`. Результаты определяют форму валидации.

| Вход | Результат | Вывод для парсера |
|------|-----------|-------------------|
| `vless://uuid@host:443?type=tcp&sni=x#My%20Server` | `userInfo=uuid`, `host=host`, `port=443`, `queryParameters` декодированы, `fragment="My%20Server"` (RAW) | Fragment декодировать вручную `Uri.decodeComponent` `[VERIFIED]` |
| `...#Tokyo%20%F0%9F%87%AF%F0%9F%87%B5` | `fragment` = `"Tokyo%20%F0%9F%87%AF%F0%9F%87%B5"`; `decodeComponent` → `"Tokyo 🇯🇵"` | Getter `.fragment` НЕ декодирует; `queryParameters` декодирует (`%2Fpath`→`/path`, `A%20B`→`A B`) `[VERIFIED: uri_probe3.dart]` |
| `vless://uuid@[2606:4700:4700::1111]:8443?...` | `host="2606:4700:4700::1111"` (скобки сняты), `port=8443` | IPv6 работает; для отображения `$host:$port` обернуть host в `[...]`, если содержит `:` `[VERIFIED]` |
| `vless://uuid@host:70000` | `port=70000`, `hasPort=true`, **не бросает** | `Uri.parse` НЕ валидирует диапазон порта → ручная проверка `1..65535` `[VERIFIED: uri_probe2.dart]` |
| `vless://uuid@host:abc` | **бросает** `FormatException: Invalid port` | Нечисловой порт роняет сам `Uri.parse` → нужен try/catch `[VERIFIED]` |
| `vless://uuid@host:0` / `vless://uuid@host` | `hasPort=false`, `port=0` | Отсутствие/нулевой порт ловится через `!uri.hasPort` `[VERIFIED]` |
| `VLESS://uuid@host:443#Name` | `scheme="vless"` (lowercased) | Проверка `scheme != 'vless'` ловит и верхний регистр `[VERIFIED]` |
| `vless://@host:443` | `userInfo=""` | Пустой uuid → ошибка `[VERIFIED]` |
| `vless://uuid@:443` / `vless:uuid@host:443` | `host=""` | Пустой host → ошибка (второй — без `//`, authority не распознан) `[VERIFIED]` |
| `not a uri` / `""` | `scheme=""`, `host=""`, не бросает | Ловится проверкой схемы `[VERIFIED]` |
| `  vless://...  ` (пробелы) | **бросает** `FormatException: Scheme not starting with alphabetic` | Буфер часто с `\n`/пробелами → `trim()` ДО парса обязателен `[VERIFIED]` |
| `?type=tcp&type=ws` (дубль ключа) | `queryParameters={type: ws}` (последний), `queryParametersAll` хранит оба | Дубли не роняют; берём последний `[VERIFIED]` |

## Runtime State Inventory

Фаза greenfield для feature `server_config` (новый код), плюс минимальная интеграция в phase-3 экран. Это не rename/refactor и не миграция данных, но проверил категории на предмет скрытого состояния:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — конфиг не персистится; демо-`VpnConfig` живёт в памяти (`AppDependencies.demoConfig`). Verified: grep по `lib/` — единственный источник конфига это `di.dart` | Нет |
| Live service config | None — приложение автономно, внешних сервисов с VLESS-строкой нет. Verified: нет бэкенда/подписок в скоупе (Out of Scope в REQUIREMENTS.md) | Нет |
| OS-registered state | None — фаза не регистрирует задач/сервисов ОС | Нет |
| Secrets/env vars | None — vless-ссылка вводится/вставляется рантайм-пользователем, в репо не попадает (locked: «демо-конфиг зашит, реальную ссылку пользователь даёт у демо»). `[CITED: STATE.md Decisions]` | Нет |
| Build artifacts | None — новый Dart-код собирается штатно; демо-`VpnConfig` в `di.dart` остаётся как есть либо дополняется опциональным маппингом | Нет |

## Common Pitfalls

### Pitfall 1: `Uri.fragment` возвращает percent-encoded строку
**What goes wrong:** Имя сервера с пробелом/юникодом (`#My%20Server`, `#Tokyo%20🇯🇵`) попадает в карточку как `My%20Server`.
**Why it happens:** В Dart 3.12.2 getter `.fragment` НЕ декодирует, в отличие от `.queryParameters`. `[VERIFIED: uri_probe3.dart]`
**How to avoid:** `final name = uri.fragment.isEmpty ? uri.host : Uri.decodeComponent(uri.fragment);`
**Warning signs:** `%20`, `%F0` в имени на карточке.

### Pitfall 2: `Uri.parse` не валидирует диапазон порта
**What goes wrong:** `:70000` или `:99999` проходят как валидный `VlessConfig`, tcping потом падает или ведёт себя странно.
**Why it happens:** `Uri.parse` принимает любое число как порт (проверяет только «число»). `[VERIFIED: uri_probe2.dart — port=70000 без throw]`
**How to avoid:** После парса — `if (!uri.hasPort || uri.port < 1 || uri.port > 65535) return failure(port);`
**Warning signs:** Порт вне 1..65535 «проглатывается» без ошибки.

### Pitfall 3: `Uri.parse` бросает на нечисловом порте и на ведущем пробеле
**What goes wrong:** Вставка из буфера с `\n` в конце или порт `:abc` роняет парсер `FormatException` без внятной ошибки.
**Why it happens:** Буфер обмена часто содержит хвостовой перевод строки; `Uri.parse` требует схему с первого символа и число в порту. `[VERIFIED: uri_probe2.dart]`
**How to avoid:** `input.trim()` ДО `Uri.parse`; весь `Uri.parse` в `try/catch (FormatException)` → `VlessError.malformed`.
**Warning signs:** Валидная на вид ссылка даёт «malformed» из-за невидимого `\n`.

### Pitfall 4: Карточка читает config нереактивно
**What goes wrong:** Пользователь жмёт «Вставить», состояние меняется, но карточка не обновляется.
**Why it happens:** `VpnHomeScreen` берёт config через `context.read<VpnConnectionBloc>().config` в `build()` — это snapshot, не подписка. `[VERIFIED: lib/.../vpn_home_screen.dart:70]`
**How to avoid:** Карточку конфига обернуть в `BlocBuilder<ServerConfigCubit, ServerConfigState>`; не переиспользовать `context.read` для отображения.
**Warning signs:** Тап по «Вставить» без визуального отклика.

### Pitfall 5: `Clipboard`/`Socket` в unit-тестах бьют в платформу/сеть
**What goes wrong:** Cubit-тест виснет или падает `MissingPluginException` (Clipboard) либо флейлит по сети (Socket).
**Why it happens:** `Clipboard.getData` идёт через `SystemChannels.platform`; `Socket.connect` идёт в реальную сеть — обоих нет в чистом unit-окружении.
**How to avoid:** Инъекция `ClipboardSource`/`LatencyProbe`-фейков в cubit-тестах. Для widget-теста кнопки вставки — мок `SystemChannels.platform` метода `Clipboard.getData` через `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler`.
**Warning signs:** `MissingPluginException`, плавающие таймауты в тестах.

### Pitfall 6: Двойное декодирование query-параметров
**What goes wrong:** Значения с `%` (например `path=%2F...`) искажаются.
**Why it happens:** `uri.queryParameters` УЖЕ декодирован; повторный `decodeComponent` ломает данные.
**How to avoid:** `decodeComponent` звать ТОЛЬКО для `uri.fragment`, не для `queryParameters`.
**Warning signs:** `sni`/`path` теряют символы.

### Pitfall 7: IPv6-хост в отображении `$host:$port`
**What goes wrong:** `2606:4700:4700::1111:8443` — неоднозначно, где host, где port.
**Why it happens:** `.host` возвращает IPv6 без скобок; наивная конкатенация теряет разделение.
**How to avoid:** Для отображения: `final display = host.contains(':') ? '[$host]:$port' : '$host:$port';`. Для `Socket.connect` бортовой host без скобок корректен.
**Warning signs:** Кривой адрес на карточке для IPv6-узлов.

## Code Examples

### VlessConfig (immutable + equatable)
```dart
// domain/entities/vless_config.dart
// Source: паттерн VpnConfig (lib/.../vpn_config.dart) + поля VLESS URI (XTLS #716)
class VlessConfig extends Equatable {
  const VlessConfig({
    required this.uuid,
    required this.host,
    required this.port,
    required this.transport,
    required this.security,
    required this.name,
    this.sni,
  });

  final String uuid;
  final String host;
  final int port;
  final String transport; // type: tcp|ws|grpc|... (default tcp)
  final String security;  // none|tls|reality (default none)
  final String? sni;
  final String name;      // из fragment, decodeComponent

  @override
  List<Object?> get props => [uuid, host, port, transport, security, sni, name];
}
```

### Sealed result-типы
```dart
// domain/entities/vless_parse_result.dart
enum VlessError { empty, malformed, scheme, uuid, host, port }

sealed class VlessParseResult extends Equatable {
  const VlessParseResult();
  @override
  List<Object?> get props => const [];
}

class VlessParsed extends VlessParseResult {
  const VlessParsed(this.config);
  final VlessConfig config;
  @override
  List<Object?> get props => [config];
}

class VlessParseFailure extends VlessParseResult {
  const VlessParseFailure(this.error);
  final VlessError error;
  @override
  List<Object?> get props => [error];
}

// domain/entities/latency_result.dart
sealed class LatencyResult extends Equatable {
  const LatencyResult();
  @override
  List<Object?> get props => const [];
}
class LatencyMeasured extends LatencyResult {
  const LatencyMeasured(this.rtt);
  final Duration rtt;
  @override
  List<Object?> get props => [rtt];
}
class LatencyUnreachable extends LatencyResult {
  const LatencyUnreachable();
}
```

### Маппинг VlessConfig → VpnConfig (для моста)
```dart
// domain/mappers/vless_to_vpn_config.dart
// Мост принимает только 4 поля (host, port, userId, serverName) — см. VpnConfigMessage
VpnConfig vlessToVpnConfig(VlessConfig v) => VpnConfig(
      host: v.host,
      port: v.port,
      userId: v.uuid,
      serverName: v.name,
    );
```

### Маскировка UUID
```dart
// presentation — карточка и любые логи
String maskUuid(String uuid) => uuid.length >= 12
    ? '${uuid.substring(0, 8)}…${uuid.substring(uuid.length - 4)}'
    : '••••';
```

### Тест парсера (образец под QA-01)
```dart
// test/features/server_config/domain/vless_parser_test.dart
void main() {
  group('parseVless', () {
    test('reality/tcp — все поля', () {
      final r = parseVless(
        'vless://b831381d-6324-4d53-ad4f-8cda48b30811@example.com:443'
        '?type=tcp&security=reality&sni=www.microsoft.com&pbk=k&fp=chrome#Tokyo',
      );
      expect(r, isA<VlessParsed>());
      final c = (r as VlessParsed).config;
      expect(c.uuid, 'b831381d-6324-4d53-ad4f-8cda48b30811');
      expect(c.host, 'example.com');
      expect(c.port, 443);
      expect(c.security, 'reality');
      expect(c.sni, 'www.microsoft.com');
      expect(c.name, 'Tokyo');
    });

    test('порт вне диапазона — failure(port)', () {
      expect(
        parseVless('vless://b831381d-6324-4d53-ad4f-8cda48b30811@h:70000'),
        const VlessParseFailure(VlessError.port),
      );
    });

    test('percent-encoded имя декодируется', () {
      final r = parseVless(
        'vless://b831381d-6324-4d53-ad4f-8cda48b30811@h:443#My%20Server',
      ) as VlessParsed;
      expect(r.config.name, 'My Server');
    });
    // ... IPv6, нечисловой порт, пустой uuid/host, чужая схема, ведущий пробел
  });
}
```

## Интеграция в экран фазы 3 (VLS-02, минимально)

`VpnHomeScreen` — `StatefulWidget` со staggered-входом; карточка сервера сейчас между ирисом и трафиком (`_Staggered` → `ServerCard`). Минимальная, неломающая интеграция:

1. Зарегистрировать `ServerConfigCubit` рядом с `VpnConnectionBloc`/`LogsCubit` в `MultiBlocProvider` (`app.dart`), инъекция `ClipboardSource`/`LatencyProbe` из `AppDependencies` (`di.dart`).
2. Заменить блок `_Staggered(child: ServerCard(...))` на `BlocBuilder<ServerConfigCubit, ServerConfigState>`, который:
   - при `initial`/`loaded==null` показывает текущий `ServerCard` (демо-config) + кнопку «Вставить `vless://`»;
   - при `loaded(config)` показывает `VlessConfigCard(config, latency)` с маскированным uuid;
   - при `error(reason)` показывает `ServerCard` + строку ошибки под ним.
3. Кнопка `PasteConfigButton` вызывает `context.read<ServerConfigCubit>().pasteFromClipboard()`; haptic `mediumImpact` по паттерну DESIGN.
4. Стиль карточки — токены `OkoTones` (`surfaceCard`, `textPrimary`, `textSecondary`, `accentError`), как в существующем `ServerCard`. Цвет пинга опционально по шкале (зелёный/янтарь/коралл — уже есть `accentFor`/акценты). `[CITED: lib/.../server_card.dart, oko_tones]`

**Опционально (не в требованиях фазы):** реальный Connect выбранным сервером. Требует сделать `VpnConnectionBloc.config` изменяемым (событие `ConfigSelected(VpnConfig)`), т.к. сейчас `config` — `final` и читается нереактивно. Вынести в Open Questions; по умолчанию карточка демонстрирует парсер, Connect остаётся на демо-config.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Ручной разбор share-строки | `Uri.parse` + доменная валидация | Dart 2+ | IPv6/percent-encoding даром |
| `mockito` + `@GenerateMocks` | `mocktail` (без кодогена) | mocktail 1.x | Ноль build_runner для фейков |
| VLESS с `tls`/`ws` | REALITY (`security=reality`, `pbk`/`sid`/`fp`), новые транспорты `xhttp`/`httpupgrade` | Xray-core 1.8+ (2023-2025) | Парсер обязан не падать на незнакомых `type`/`security`, хранить их как строки `[CITED: XTLS/Xray-core #716]` |
| «Real delay» по HTTP через core | TCP connect time (tcping) без core | Практика v2rayNG | Без запущенного ядра доступен только TCP-замер `[CITED: FEATURES.md, v2rayNG issues]` |

**Deprecated/outdated:**
- `encryption` в VLESS исторически всегда `none` (аутентификация по UUID); появление `mlkem768x25519` в новых Xray не меняет дефолт. Парсеру достаточно игнорировать/хранить как строку. `[CITED: XTLS/Xray-core #716]`

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Минимальный набор полей `VlessConfig` (uuid, host, port, transport, security, sni, name) достаточен для карточки и маппинга в мост | Standard Stack / Code Examples | Если планировщик захочет показывать `pbk`/`fp`/`flow`/`path` — добавить `Map<String,String> extraParams` в entity (расширяемо, не ломает) |
| A2 | Реальный Connect выбранным сервером — вне требований VLS-01/02/03/QA-01 | Интеграция в экран | Если ревьюер ждёт Connect по вставленному конфигу — нужна правка `VpnConnectionBloc` (событие + mutable config); отдельная задача |
| A3 | tcping в автосьюте тестируется только через фейк `LatencyProbe`; живой `Socket`-тест — вне CI | Validation Architecture | Если требуется живой замер в тестах — флейки на CI без сети; держать за тегом/скипом |
| A4 | Абстракции `Uri.parse`/RegExp достаточно для UUID; пакет `uuid` не нужен | Don't Hand-Roll | Пренебрежимо: regex 8-4-4-4-12 проверен эмпирически |
| A5 | Feature называется `server_config` | Project Structure | Косметика; при желании `vless` — переименование каталога |

## Open Questions

1. **Использовать ли вставленный конфиг для реального Connect?**
   - Что знаем: сейчас `VpnConnectionBloc.config` — `final`, читается нереактивно; мост принимает 4 поля, маппинг готов (`vlessToVpnConfig`).
   - Что неясно: входит ли «Connect выбранным сервером» в ожидания демо (в требованиях фазы явно нет).
   - Recommendation: по умолчанию НЕТ — карточка демонстрирует парсер+пинг, Connect на демо-config. Если да — отдельная задача: событие `ConfigSelected(VpnConfig)` + mutable `config`.

2. **Показывать ли REALITY-детали (pbk/fp/sid/flow) на карточке?**
   - Что знаем: спека их определяет; entity можно расширить `extraParams`.
   - Что неясно: нужны ли они ревьюеру визуально.
   - Recommendation: минимум на карточке (name, host:port, type, security, sni, ping); остальное хранить, но не показывать. UUID маскировать всегда.

3. **Цветовая шкала пинга.**
   - Что знаем: `OkoTones` даёт акценты connected/connecting/error.
   - Что неясно: пороги (например <100ms зелёный, <300ms янтарь, иначе коралл).
   - Recommendation: discretionary; выбрать простые пороги или единый secondary-цвет.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Сборка, виджеты, Clipboard | ✓ | 3.44.5 stable | — |
| Dart SDK | Парсер, Socket, тесты | ✓ | 3.12.2 stable | — |
| Проектные dev-deps (bloc_test, mocktail) | Тесты | ✓ | pubspec.lock | — |

**Missing dependencies with no fallback:** нет.
**Missing dependencies with fallback:** нет. Реальная сеть нужна только рантайм-tcping к пользовательскому хосту (не для сборки/тестов); в автосьюте заменяется фейком `LatencyProbe`.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) + `bloc_test` ^10.0.0 + `mocktail` ^1.0.5 |
| Config file | нет отдельного (стандартный `flutter test`); тесты в `test/` |
| Quick run command | `flutter test test/features/server_config/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VLS-01 | reality/tcp — полный конфиг | unit | `flutter test test/features/server_config/domain/vless_parser_test.dart` | ❌ Wave 0 |
| VLS-01 | ws/tls, grpc — разные type/security | unit | тот же файл | ❌ Wave 0 |
| VLS-01/QA-01 | percent-encoded имя → decode | unit | тот же файл | ❌ Wave 0 |
| VLS-01/QA-01 | IPv6-хост `[::1]` | unit | тот же файл | ❌ Wave 0 |
| VLS-01/QA-01 | порт вне 1..65535 → failure | unit | тот же файл | ❌ Wave 0 |
| VLS-01/QA-01 | нечисловой порт → failure(malformed) | unit | тот же файл | ❌ Wave 0 |
| VLS-01/QA-01 | пустой uuid / невалидный формат uuid → failure | unit | тот же файл | ❌ Wave 0 |
| VLS-01/QA-01 | пустой host → failure | unit | тот же файл | ❌ Wave 0 |
| VLS-01/QA-01 | чужая схема (`https://`, `""`) → failure(scheme) | unit | тот же файл | ❌ Wave 0 |
| VLS-01/QA-01 | ведущий/хвостовой пробел (буфер) → trim + parse | unit | тот же файл | ❌ Wave 0 |
| VLS-01/QA-01 | отсутствующие параметры → дефолты (tcp/none) | unit | тот же файл | ❌ Wave 0 |
| VLS-03 | measured RTT через фейк-connect | unit | `flutter test test/features/server_config/data/socket_latency_probe_test.dart` | ❌ Wave 0 |
| VLS-03 | SocketException → LatencyUnreachable | unit | тот же файл (фейк бросает) | ❌ Wave 0 |
| VLS-02 | paste valid → state.loaded(config) | bloc | `flutter test test/features/server_config/presentation/server_config_cubit_test.dart` | ❌ Wave 0 |
| VLS-02 | paste invalid → state.error(reason) | bloc | тот же файл | ❌ Wave 0 |
| VLS-02 | пустой буфер → error(empty) | bloc | тот же файл | ❌ Wave 0 |
| VLS-02 | loaded → measure → loaded+latency | bloc | тот же файл (фейк probe) | ❌ Wave 0 |
| VLS-02 | карточка рендерит поля, маскирует uuid | widget | `flutter test test/features/server_config/presentation/vless_config_card_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/features/server_config/`
- **Per wave merge:** `flutter test`
- **Phase gate:** полный `flutter test` зелёный + `flutter analyze` чистый (very_good_analysis) перед `/gsd:verify-work`.

### Wave 0 Gaps
- [ ] `test/features/server_config/domain/vless_parser_test.dart` — VLS-01, QA-01 (ядро)
- [ ] `test/features/server_config/data/socket_latency_probe_test.dart` — VLS-03 (фейк-connector)
- [ ] `test/features/server_config/presentation/server_config_cubit_test.dart` — VLS-02
- [ ] `test/features/server_config/presentation/vless_config_card_test.dart` — VLS-02 (маскировка uuid)
- [ ] `test/helpers/` — фейки `LatencyProbe`, `ClipboardSource` (mocktail или ручные `implements`)
- [ ] Framework install: не требуется (всё в pubspec)

## Security Domain

`security_enforcement` в `config.json` отсутствует → трактуется как enabled. Скоуп безопасности узкий: обработка недоверенного ввода из буфера и защита чувствительного идентификатора (UUID).

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Нет аутентификации в фазе |
| V3 Session Management | no | Нет сессий |
| V4 Access Control | no | Локальное приложение, один пользователь |
| V5 Input Validation | yes | `parseVless` — единственная точка валидации недоверенной строки из буфера; sealed-ошибки, никаких исключений наружу, `trim` + range-check порта |
| V6 Cryptography | no | Криптоключи VLESS (pbk) не используются приложением, только парсятся/хранятся как строка; ничего не шифруем сами |
| V7 Logging / Sensitive Data | yes | UUID = секрет доступа к серверу; маскировать в UI и логах, не печатать целиком |

### Known Threat Patterns for Dart/Flutter + буфер обмена
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malformed/adversarial vless-строка роняет приложение | Denial of Service | `parseVless` не бросает наружу; всё в sealed result; `Uri.parse` в try/catch `[VERIFIED]` |
| Утечка UUID через логи/скриншот демо | Information Disclosure | `maskUuid` в карточке и логах; Kotlin-сервис уже не логирует `userId` `[CITED: STATE.md 02-03]` |
| tcping к произвольному host из ссылки (SSRF-подобный вектор) | — (низкий риск) | Коннект инициирует сам пользователь вставкой; таймаут 3с не даёт зависнуть; только TCP-connect без данных. Не авто-коннектить без действия пользователя |
| Двойной/битый decode искажает sni/host (логическая ошибка) | Tampering | `decodeComponent` только для fragment; `queryParameters` не редекодить `[VERIFIED]` |

## Sources

### Primary (HIGH confidence)
- Локальная эмпирика на SDK проекта (`Dart 3.12.2` / `Flutter 3.44.5`): `uri_probe*.dart`, `socket_probe.dart` — поведение `Uri.parse`, `Uri.fragment`/`decodeComponent`, диапазон порта, `Socket.connect(timeout:)`, `SocketException`
- [XTLS/Xray-core Discussion #716](https://github.com/XTLS/Xray-core/discussions/716) — канонический стандарт `vless://` share-link (параметры type/security/sni/fp/pbk/sid/flow/path/host/serviceName/mode, encryption=none, case-sensitivity, IPv6-скобки, encodeURIComponent)
- [XTLS/Xray VLESS outbound](https://xtls.github.io/en/config/outbounds/vless.html), [sing-box VLESS](https://sing-box.sagernet.org/configuration/outbound/vless/) — семантика полей VLESS
- [api.flutter.dev — Uri class](https://api.flutter.dev/flutter/dart-core/Uri-class.html), [Uri.parse](https://api.flutter.dev/flutter/dart-core/Uri/parse.html) — компоненты URI, IPv6, percent-decoding
- Кодовая база проекта: `lib/.../vpn_config.dart`, `vpn_home_screen.dart`, `server_card.dart`, `vpn_connection_bloc.dart`, `failures.dart`, `di.dart`, `vpn_state.dart`, `.planning/codebase/CONVENTIONS.md`, `ROADMAP.md`, `STATE.md`

### Secondary (MEDIUM confidence)
- `.planning/research/FEATURES.md`, `STACK.md` — контекст экосистемы (tcping как стандарт v2rayNG, VLESS-формат, выбор стека)
- [v2rayNG issues: tcping/real delay](https://github.com/2dust/v2rayNG/issues/3404) — практика TCP-замера без core

### Tertiary (LOW confidence)
- WebSearch-обзор параметров VLESS URI (docsbot/libraries.io) — сверен с первоисточником XTLS, самостоятельно не опорный

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — всё в SDK/уже в pubspec; версии подтверждены локально
- Architecture: HIGH — паттерн повторяет существующие feature (`vpn_connection`/`vpn_logs`), проверен по коду
- Pitfalls: HIGH — каждая ловушка воспроизведена эмпирически на SDK проекта
- VLESS-спека: HIGH (структура/параметры с XTLS #716), MEDIUM для полноты редких параметров (pqv/spx/ech новых версий Xray)

**Research date:** 2026-07-14
**Valid until:** ~2026-08-13 (стабильный домен; ревизия при апгрейде Flutter/Dart SDK или смене стандарта VLESS URI)
