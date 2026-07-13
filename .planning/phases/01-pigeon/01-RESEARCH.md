# Phase 1: Фундамент и Pigeon-мост — Research

**Researched:** 2026-07-13
**Domain:** Flutter ↔ native типобезопасный мост (pigeon 27.x, @HostApi + @EventChannelApi), echo-реализация Kotlin/Swift, доменное ядро на Dart 3 sealed + equatable
**Confidence:** HIGH

## Summary

Фаза строит фундамент: единый pigeon-контракт `pigeons/vpn_api.dart`, кодоген в Dart/Kotlin/Swift, echo-реализации моста на обеих платформах (без VpnService и Network Extension), доменное ядро (VpnState/VpnConfig/VpnEvent) и data-слой с демультиплексором событий и replay последнего статуса. Реального VPN нет: Kotlin и Swift на вызов `startVpn`/`stopVpn` шлют синтетическую цепочку `StatusChanged`/`LogMessage` в один event-стрим, `getStatus()` отдаёт кэшированный снапшот, новый подписчик получает replay последнего статуса.

Главная неопределённость проекта (STATE.md: «генерация Kotlin StreamHandler в pigeon 27.x проверяется на echo-мосте; запасной вариант @FlutterApi») закрыта: по официальному примеру pigeon подтверждено, что 27.x генерирует StreamHandler-класс `<Method>StreamHandler` с `PigeonEventSink<T>` и статическим `register(...)` для Kotlin **и** Swift. Метод `vpnEvents()` → класс `VpnEventsStreamHandler`. Запасной вариант `@FlutterApi` НЕ нужен. Отдельно закрыт риск регистрации на iOS: проект собран на новом шаблоне Flutter 3.44 (SceneDelegate + `FlutterImplicitEngineDelegate`), где `binaryMessenger` берётся из `engineBridge.applicationRegistrar.messenger()` внутри `didInitializeImplicitFlutterEngine`, а не из `rootViewController as! FlutterViewController` (устаревший путь из примера pigeon).

**Primary recommendation:** Один входной файл `pigeons/vpn_api.dart` с `@HostApi VpnHostApi` (startVpn/stopVpn — `@async void`; `getStatus()` возвращает снапшот-класс `VpnStatusSnapshotMessage`) и `@EventChannelApi VpnEventsApi { VpnEventMessage vpnEvents(); }` поверх `sealed class VpnEventMessage`; kotlinOut + swiftOut (без javaOut/objcOut); генерация `dart run pigeon --input pigeons/vpn_api.dart`; echo-эмиттер централизован и шлёт события строго с main thread; `VpnBridge` — единственная точка подписки на `vpnEvents()`, принимает stream через конструктор для тестируемости; домен не импортирует `*.g.dart`.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BRG-01 | Pigeon-контракт объявляет `startVpn(config)`, `stopVpn()`, `getStatus()` (@HostApi) | Verified-синтаксис `@HostApi` + `@async` (Code Example 1); `getStatus()` расширен до снапшот-класса `VpnStatusSnapshotMessage` ради BRG-04 |
| BRG-02 | События native→Flutter одним стримом через @EventChannelApi, sealed: StatusChanged, LogMessage, TrafficChanged, VpnError | Verified `sealed class` + `@EventChannelApi` (Code Example 1); генератор Kotlin/Swift/Dart подтверждён; демультиплексор в `VpnBridge` (Code Example 5) |
| BRG-03 | Domain изолирован: суффикс Message, импорт `*.g.dart` только в core/bridge и features/*/data, мапперы DTO→entity | Правило импорта — Project Constraints; мапперы (Code Example 7); анти-паттерн «домен импортирует g.dart» из ARCHITECTURE.md |
| BRG-04 | События только с main thread; replay последнего статуса; `getStatus()` — снапшот (status, connectedSince, счётчики) | Kotlin `Handler(Looper.getMainLooper())` / Swift `DispatchQueue.main` (Code Examples 3–4); native-кэш + replay в `onListen`; Dart-replay в repository (Code Example 6) |
| CORE-01 | Доменные модели VpnConfig, VpnState, VpnEvent — sealed/immutable; ошибки доводятся до UI-состояния Error | Dart 3 `sealed class` + equatable (Code Example 8); typed Failure в data-слое |

**Граница фазы (важно для планировщика):** echo-мост на iOS живёт в Runner-приложении (Swift `VpnHostApiImpl` + `VpnEventsStreamHandler`), это НЕ требования IOS-01..04 (реальный Network Extension — Phase 5) и НЕ AND-01..06 (реальный VpnService — Phase 2). Symmetric echo на Android — только регистрация в `MainActivity` + синтетический эмиттер, без `OkoVpnService`, без манифест-permissions VPN и без FGS. SDK-бампы (minSdk 26 / targetSdk 36) и VPN-permissions относятся к Phase 2 — в Phase 1 не трогать, echo-мост компилируется на дефолтных SDK шаблона.
</phase_requirements>

## Project Constraints (from CLAUDE.md / CONVENTIONS.md)

Директивы проекта имеют силу locked-решений. План не должен предлагать подходы, которые им противоречат.

- **Feature-first clean architecture:** `lib/features/<feature>/{domain,data,presentation}`, общее — `lib/core/`, `lib/app/`. Дерево из ARCHITECTURE.md.
- **SOLID + конструкторная инъекция:** зависимости через абстракции domain; presentation не знает про data; composition root в `lib/app/di.dart`.
- **Комментарии в коде запрещены** (Dart/Kotlin/Swift). `analysis_options.yaml`: `very_good_analysis` + `public_member_api_docs: false`.
- **State management — Bloc (`flutter_bloc`)**, не Riverpod. Бизнес-логика в Bloc/Cubit; виджеты — только BlocBuilder/BlocListener. (В Phase 1 Bloc ещё нет — UI/Bloc в Phase 3; Phase 1 готовит data/domain и composition root.)
- **Domain-модели: sealed classes + equatable, immutable.** Никакого freezed/json_serializable — единственный кодоген pigeon.
- **Pigeon:** контракт в `pigeons/vpn_api.dart`; типы контракта с суффиксом `Message`; импорт `*.g.dart` разрешён ТОЛЬКО в `core/bridge/` и `features/*/data/`; мапперы DTO→entity.
- **События native→Flutter — только с main thread платформы** (Kotlin `Handler(Looper.getMainLooper())`/`Dispatchers.Main`; Swift `DispatchQueue.main`).
- **Ошибки:** `PlatformException` → typed Failure в data-слое; UI получает доменные ошибки, не строки платформы.
- **Native — источник истины по статусу VPN.**
- **Именование:** Dart `lowerCamelCase`/`UpperCamelCase`, файлы `snake_case.dart`; Kotlin/Swift — конвенции платформ. Код/идентификаторы — английский; доки/коммиты — русский.
- **Тесты test-as-you-go:** код → тесты → прогон в том же заходе; перед коммитом весь набор зелёный. mocktail для моков.
- **Git:** атомарные коммиты, conventional commits с русским описанием.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Контракт моста (методы, события, DTO) | Build-time codegen (`pigeons/`) | — | Единственный источник истины; генерирует Dart+Kotlin+Swift |
| Команды startVpn/stopVpn/getStatus | Native (Kotlin/Swift echo-impl) | Dart data (invoke через VpnBridge) | Исполнение команды — на платформе; Dart только вызывает |
| Стрим событий (emit) | Native (echo-эмиттер) | — | Источник событий; на echo-фазе синтетический |
| Стрим событий (consume + демультиплекс) | Dart data (`VpnBridge`) | — | Одна подписка на `vpnEvents()`, раздача broadcast по sealed-типу |
| Кэш последнего статуса + replay | Native (source of truth) | Dart data (repository кэш) | Двойная защита от гонки «событие раньше подписки» (BRG-04) |
| Доменные модели VpnState/VpnConfig/VpnEvent | Dart domain | — | Чистый Dart, sealed+equatable, без зависимости на pigeon |
| Маппинг DTO→entity | Dart data (mappers) | — | Изоляция домена от кодогена (BRG-03) |
| DI / composition root | Dart app (`app/di.dart`) | — | Связывание слоёв, инверсия зависимостей |
| main-thread доставка событий | Native (эмиттер) | — | Требование platform channels; иначе crash |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| pigeon | 27.1.1 | Типобезопасный мост, @HostApi + @EventChannelApi | Официальный кодоген команды Flutter; единственный поддержанный путь к sealed event channels для Kotlin/Swift/Dart. `[VERIFIED: pub.dev — dart pub add --dry-run → pigeon 27.1.1]` |
| flutter_bloc | 9.1.1 | State management (используется с Phase 3) | Прямое решение пользователя. `[VERIFIED: pub.dev — dry-run → flutter_bloc 9.1.1, bloc 9.2.1]` |
| equatable | 2.1.0 | Value equality доменных моделей | sealed + equatable закрывают `==`/`hashCode` без кодогена. `[VERIFIED: pub.dev — dry-run → equatable 2.1.0]` |

### Supporting (dev)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| mocktail | 1.0.5 | Моки без кодогена | Мок `VpnHostApi` в тестах репозитория/датасорса. `[VERIFIED: pub.dev — dry-run → mocktail 1.0.5]` |
| very_good_analysis | 10.3.0 | Линтинг | Строгий линт; override `public_member_api_docs: false`. `[VERIFIED: pub.dev — dry-run → very_good_analysis 10.3.0]` |
| bloc_test | 10.0.0 | Тесты Bloc-переходов | Формально Phase 3 (QA-02); в Phase 1 не обязателен. `[VERIFIED: pub.dev — dry-run → bloc_test 10.0.0]` |
| flutter_test | SDK | Unit-тесты | Мапперы, домен-модели, replay-репозиторий |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| @EventChannelApi | Сырые EventChannel + ручной StreamHandler | Теряется типобезопасность — главный аргумент выбора pigeon. Брать только при баге генерации |
| @EventChannelApi | @FlutterApi-коллбеки | Нет семантики подписки/отписки; STATE.md держал как fallback — теперь НЕ нужен, генерация подтверждена |
| sealed + equatable | freezed 3.x | build_runner ради 3–4 моделей; конфликтует с «единственный кодоген — pigeon» |
| mocktail | mockito | Требует @GenerateMocks + build_runner |

**Installation:**
```bash
flutter pub add flutter_bloc equatable
flutter pub add --dev pigeon mocktail very_good_analysis
# Генерация после описания контракта:
dart run pigeon --input pigeons/vpn_api.dart
```

`analysis_options.yaml` (заменить текущий `include: package:flutter_lints/flutter.yaml`):
```yaml
include: package:very_good_analysis/analysis_options.yaml
linter:
  rules:
    public_member_api_docs: false
analyzer:
  exclude:
    - "**/*.g.dart"
```
(Исключение `*.g.dart` из анализа — генерированный код не проходит строгий VGA-линт и его не редактируют вручную.)

## Package Legitimacy Audit

Все пакеты — pub.dev (Dart-экосистема), не npm/PyPI. slopcheck ориентирован на npm/PyPI и здесь неприменим; вместо него — проверка через официальные источники (флаттеровская команда / felangel / Very Good Ventures) + подтверждение существования и версии через `dart pub add --dry-run`.

| Package | Registry | Издатель | Source Repo | Проверка | Disposition |
|---------|----------|----------|-------------|----------|-------------|
| pigeon 27.1.1 | pub.dev | flutter.dev (official) | github.com/flutter/packages | dry-run + официальный README/example | Approved |
| flutter_bloc 9.1.1 | pub.dev | bloclibrary.dev (felangel) | github.com/felangel/bloc | dry-run | Approved |
| bloc 9.2.1 | pub.dev | bloclibrary.dev | github.com/felangel/bloc | dry-run | Approved |
| equatable 2.1.0 | pub.dev | felangel | github.com/felangel/equatable | dry-run | Approved |
| mocktail 1.0.5 | pub.dev | felangel | github.com/felangel/mocktail | dry-run | Approved |
| very_good_analysis 10.3.0 | pub.dev | Very Good Ventures | github.com/VeryGoodOpenSource/very_good_analysis | dry-run | Approved |
| bloc_test 10.0.0 | pub.dev | bloclibrary.dev | github.com/felangel/bloc | dry-run | Approved |

**Packages removed:** none. **Packages flagged suspicious:** none. Все — mainstream Flutter-экосистема, издатели верифицированы на pub.dev.

## Architecture Patterns

### System Architecture Diagram

```
[UI tap / app start]  (UI и Bloc — Phase 3; в Phase 1 — минимальный debug-harness)
        │ вызовы use cases                    ▲ Stream<VpnState> / Stream<LogEntry>
   ┌────┴──────────────── domain ─────────────┴────┐
   │ WatchVpnState · ConnectVpn · DisconnectVpn     │
   │ VpnRepository (interface)                      │
   │ entities: VpnState(sealed) · VpnConfig · Log   │
   └────┬───────────────────────────────────────────┘
        │ interface                            ▲ mapped entities
   ┌────┴──────────────── data ───────────────┴────┐
   │ VpnRepositoryImpl (кэш last + replay)          │
   │ VpnNativeDatasource · mappers (DTO→entity)     │
   └────┬───────────────────────────────────────────┘
        │ VpnConfigMessage / вызовы             ▲ VpnEventMessage (sealed)
   ┌────┴──────────── core/bridge ────────────┴─────┐
   │ VpnBridge: ЕДИНСТВЕННАЯ подписка на vpnEvents() │
   │   → демультиплекс по sealed-типу → broadcast    │
   │   startVpn/stopVpn/getStatus → VpnHostApi        │
   └────┬───────────────────────────────────────────┘
        │ Pigeon binary messenger (генерир. Dart/Kotlin/Swift)
   ┌────┴─────────── Android echo ───────┬──── iOS echo (Runner) ────┐
   │ MainActivity.configureFlutterEngine │ AppDelegate.didInitialize- │
   │  VpnHostApi.setUp(...)              │  ImplicitFlutterEngine     │
   │  VpnEventsStreamHandler.register    │  VpnHostApiSetup.setUp      │
   │ VpnHostApiImpl (echo startVpn →     │  VpnEventsStreamHandler.    │
   │  синтетич. StatusChanged/LogMessage)│   register (messenger)      │
   │ VpnEventBus (last-status + emit)    │ VpnHostApiImpl (echo)       │
   │  → Handler(mainLooper).post → sink  │  → DispatchQueue.main → sink│
   └─────────────────────────────────────┴────────────────────────────┘
```

Реальный use case echo-фазы: tap/старт → `startVpn` → native эмитит `LogMessage("starting")` → `StatusChanged(connecting)` → `StatusChanged(connected, connectedSince=now)`; повторная подписка/hot restart → `getStatus()` снапшот + replay последнего статуса в `onListen`.

### Recommended Project Structure (срез Phase 1)
```
pigeons/
└── vpn_api.dart                       # контракт: VpnHostApi, VpnEventsApi, DTO, sealed VpnEventMessage, enum
lib/
├── main.dart                          # bootstrap: CompositionRoot + минимальный debug-harness
├── app/
│   ├── app.dart                       # MaterialApp (тема — Phase 3)
│   └── di.dart                        # composition root: bridge → datasource → repo → usecases
├── core/
│   ├── bridge/
│   │   ├── vpn_api.g.dart             # dartOut (генерируется, коммитится)
│   │   └── vpn_bridge.dart            # единственная подписка + демультиплексор
│   └── error/
│       ├── failures.dart              # доменные Failure
│       └── vpn_exception.dart         # PlatformException → typed
└── features/
    ├── vpn_connection/{domain,data}   # VpnState/VpnConfig/TrafficStats, VpnRepository, usecases, mapper, repo impl
    └── vpn_logs/{domain,data}         # LogEntry, LogRepository, mapper, repo impl
test/
└── features/.../data/mappers/*        # мапперы; domain/entities/*; data/repositories/replay
android/app/src/main/kotlin/com/example/vpn_oko/
├── MainActivity.kt                    # регистрация HostApi + StreamHandler
└── bridge/
    ├── Messages.g.kt                  # kotlinOut (генерируется)
    ├── VpnHostApiImpl.kt              # echo startVpn/stopVpn/getStatus
    ├── VpnEventListener.kt            # : VpnEventsStreamHandler()
    └── VpnEventBus.kt                 # object: last-status + emit(main thread)
ios/Runner/
├── AppDelegate.swift                  # регистрация в didInitializeImplicitFlutterEngine
└── Bridge/
    ├── Messages.g.swift               # swiftOut (генерируется)
    ├── VpnHostApiImpl.swift           # echo
    └── VpnEventListener.swift         # : VpnEventsStreamHandler
```
Пакет Android — `com.example.vpn_oko` (текущий шаблон). iOS — новый шаблон SceneDelegate (`AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate`), учтено в регистрации.

### Pattern 1: Единый контракт с суффиксом Message + снапшот в getStatus
**What:** Все типы контракта с суффиксом `Message`; события — `sealed class VpnEventMessage` с подклассами; `getStatus()` возвращает НЕ enum, а `VpnStatusSnapshotMessage` (status + connectedSince + счётчики) под BRG-04.
**When to use:** всегда при кодогене — генерированные типы не совпадают с требованиями домена.
**Trade-offs:** дублирование моделей + мапперы; взамен домен переживает смену версии pigeon и тестируется без платформы. (Полный код — Code Example 1.)

### Pattern 2: Один event channel + демультиплексор в VpnBridge
**What:** все 4 типа событий идут одним `vpnEvents()` как sealed-иерархия; `VpnBridge` подписывается РОВНО один раз и раздаёт broadcast по типам через exhaustive `switch`.
**When to use:** когда важен порядок событий и несколько фич слушают один источник (vpn_connection + vpn_logs).
**Trade-offs:** один канал вместо четырёх — проще lifecycle, сохраняется порядок; минус — switch в одном месте (компилятор проверяет полноту по sealed). (Code Example 5.)
**Тестируемость (refinement):** `vpnEvents()` — top-level функция генерированного кода, её нельзя замокать. `VpnBridge` должен принимать `Stream<VpnEventMessage>` и `VpnHostApi` через конструктор; реальный `vpnEvents()` подставляется в composition root, а тесты подают контролируемый `StreamController`.

### Pattern 3: Native — источник истины + двойной replay (BRG-04)
**What:** последний статус кэшируется на native (`VpnEventBus` last-status) и реплеится новому подписчику в `onListen`; дополнительно repository кэширует `VpnState` и `watchState()` отдаёт кэш первым. `getStatus()` — снапшот из native-кэша.
**When to use:** любой event-мост — broadcast без replay теряет статус для поздних подписчиков (hot restart, resume).
**Trade-offs:** немного кода за двойную защиту, закрывает все гонки старта. (Code Examples 3, 6.)

### Pattern 4: Централизованный main-thread эмиттер (BRG-04 / Pitfall 3)
**What:** единственная точка отправки в sink; каждый вызов обёрнут в `Handler(Looper.getMainLooper()).post {}` (Kotlin) / `DispatchQueue.main.async {}` (Swift). Прямые вызовы `sink.success` из другого места запрещены.
**When to use:** всегда для событий в сторону Dart. На echo-фазе синтетические события уже идут через эмиттер — паттерн валидируется здесь, до реального сервиса. (Code Examples 3–4.)

### Pattern 5: Composition root без лишних зависимостей
**What:** `app/di.dart` — простой Dart-класс `AppDependencies`, создаётся в `main()`, держит синглтоны (VpnBridge, datasource, repos, usecases). Bloc-провайдеры (Phase 3) будут читать из него через `BlocProvider`.
**When to use:** 3–5 зависимостей — get_it/injectable избыточны и не в утверждённом стеке.
**Trade-offs:** ручная проводка вместо DI-контейнера; для прототипа проще и прозрачнее. (Code Example 9.)

### Anti-Patterns to Avoid
- **Домен импортирует `vpn_api.g.dart`:** привязка к кодогену. → суффикс Message + мапперы, entity со своей семантикой.
- **Несколько подписок на `vpnEvents()`:** каждая — новый EventChannel-subscription, гонки onListen/onCancel. → одна подписка в VpnBridge.
- **`sink.success` из фонового потока:** crash `@UiThread`. → только через централизованный main-thread эмиттер.
- **Статус живёт только во Flutter:** ложный Connected после hot restart. → source of truth на native + getStatus + replay.
- **`VpnBridge` сам вызывает `vpnEvents()` внутри конструктора:** нетестируемо. → inject stream.
- **javaOut/objcOut при event channels:** генерация упадёт. → только kotlinOut + swiftOut.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Сериализация Map через мост | Ручной MethodChannel/EventChannel + `Map<String,Object?>` | pigeon @HostApi/@EventChannelApi | Типобезопасность, генерация Kotlin/Swift/Dart, sealed-события |
| Value equality моделей | Ручные `==`/`hashCode` | equatable | Ошибки в hashCode ломают Set/сравнения в тестах |
| Демультиплекс событий | `if (e is X)` в каждой фиче | Один VpnBridge + exhaustive `switch` по sealed | Компилятор ловит незакрытые ветки; порядок сохранён |
| Replay/broadcast | Ручной список слушателей | `StreamController.broadcast` + кэш last (Dart) / SharedFlow replay (Kotlin) | Утечки подписок, потерянные события |
| Моки в тестах | Ручные фейки на каждый метод | mocktail | Без кодогена, `when/verify` из коробки |
| main-thread доставка | `runOnUiThread` вразнобой | Один эмиттер с `Handler(mainLooper)` / `DispatchQueue.main` | Единая точка — единственное место риска crash |

**Key insight:** на echo-фазе весь риск — в мосте и потоках, не в бизнес-логике. Каждая ручная реализация из таблицы добавляет класс багов, который pigeon/equatable/streams уже закрыли.

## Common Pitfalls

### Pitfall 1: События из фонового потока → crash `@UiThread`
**What goes wrong:** `sink.success(...)` вызван не с main thread (в реальном сервисе — из read-loop/`onRevoke`; на echo — из корутины/таймера). Android: «Methods marked with @UiThread must be executed on the main thread».
**Why it happens:** platform channels требуют main thread при вызове в сторону Dart; генерированный sink это не скрывает.
**How to avoid:** централизованный эмиттер, `Handler(Looper.getMainLooper()).post {}` / `DispatchQueue.main.async {}`. Валидируется уже на echo — синтетические события идут через ту же обёртку.
**Warning signs:** crash при эмите с таймера/корутины, тогда как вызов с UI-кнопки работает.

### Pitfall 2: Гонка «событие раньше подписки»
**What goes wrong:** native эмитит `connected` до того, как Dart подписался (холодный старт, hot restart) — событие теряется, UI показывает Disconnected.
**Why it happens:** event channel доставляет только активному подписчику, буфера нет.
**How to avoid:** native хранит last-status; `onListen` реплеит его первым; `getStatus()` снапшот при старте/resume; repository кэширует и отдаёт кэш первым.
**Warning signs:** после hot restart UI Disconnected при «живом» echo-статусе; статус прыгает при resume.

### Pitfall 3: Генерация под неподдержанные генераторы / несколько input-файлов
**What goes wrong:** javaOut/objcOut с event channels → провал генерации. Несколько input-файлов с event channels — известные проблемы (flutter/flutter#161291).
**Why it happens:** «сгенерировал и забыл»; генератор закрывает сериализацию, но не все таргеты.
**How to avoid:** ОДИН файл `pigeons/vpn_api.dart`; только kotlinOut + swiftOut + dartOut; версия pigeon зафиксирована (27.1.1); команда генерации — в README/скрипт.
**Warning signs:** ошибка генерации при указании javaOut; события пропадают после hot restart (лечится replay).

### Pitfall 4: Регистрация pigeon на iOS через устаревший `rootViewController`
**What goes wrong:** пример pigeon берёт messenger из `window?.rootViewController as! FlutterViewController`. В шаблоне Flutter 3.44 (SceneDelegate) на момент старта rootViewController может быть недоступен → crash/`MissingPluginException` (flutter/flutter#185935).
**Why it happens:** порядок инициализации engine изменился с UIScene lifecycle.
**How to avoid:** регистрировать в `didInitializeImplicitFlutterEngine(_ engineBridge:)`; messenger — `engineBridge.applicationRegistrar.messenger()`. (Code Example 4.)
**Warning signs:** `MissingPluginException` на iOS при работающем Android; nil rootViewController в AppDelegate.

### Pitfall 5: Замена main.dart без изоляции слоёв
**What goes wrong:** соблазн держать состояние и вызовы моста прямо в виджете.
**Why it happens:** «Hello World» шаблон, echo хочется показать быстро.
**How to avoid:** даже debug-harness Phase 1 ходит через composition root → usecase → repository → VpnBridge. UI (Phase 3) заменит harness, слои не тронутся.
**Warning signs:** импорт `vpn_api.g.dart` или `VpnBridge` в виджете; `startVpn` вызывается из `onPressed` напрямую.

## Code Examples

### Code Example 1 — Pigeon-контракт `pigeons/vpn_api.dart`
```dart
// Source: pigeon example (github.com/flutter/packages/.../example/app/pigeons/messages.dart
//         + pigeons/event_channel_tests.dart) — sealed class {}, extends, @EventChannelApi, @async
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/core/bridge/vpn_api.g.dart',
  kotlinOut: 'android/app/src/main/kotlin/com/example/vpn_oko/bridge/Messages.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.example.vpn_oko.bridge'),
  swiftOut: 'ios/Runner/Bridge/Messages.g.swift',
  swiftOptions: SwiftOptions(),
  dartPackageName: 'vpn_oko',
))

enum VpnStatusMessage { disconnected, connecting, connected, disconnecting, error }

class VpnConfigMessage {
  VpnConfigMessage({
    required this.host,
    required this.port,
    required this.userId,
    required this.serverName,
  });
  String host;
  int port;
  String userId;
  String serverName;
}

class VpnStatusSnapshotMessage {
  VpnStatusSnapshotMessage({
    required this.status,
    this.connectedSinceEpochMs,
    required this.rxBytes,
    required this.txBytes,
  });
  VpnStatusMessage status;
  int? connectedSinceEpochMs;
  int rxBytes;
  int txBytes;
}

sealed class VpnEventMessage {}

class StatusChangedMessage extends VpnEventMessage {
  StatusChangedMessage({required this.status, this.connectedSinceEpochMs});
  VpnStatusMessage status;
  int? connectedSinceEpochMs;
}

class LogMessage extends VpnEventMessage {
  LogMessage({required this.text, required this.timestampMillis, required this.level});
  String text;
  int timestampMillis;
  String level;
}

class TrafficChangedMessage extends VpnEventMessage {
  TrafficChangedMessage({required this.rxBytes, required this.txBytes});
  int rxBytes;
  int txBytes;
}

class ErrorMessage extends VpnEventMessage {
  ErrorMessage({required this.code, required this.description});
  String code;
  String description;
}

@HostApi()
abstract class VpnHostApi {
  @async
  void startVpn(VpnConfigMessage config);
  @async
  void stopVpn();
  VpnStatusSnapshotMessage getStatus();
}

@EventChannelApi()
abstract class VpnEventsApi {
  VpnEventMessage vpnEvents();
}
```
Генерация: `dart run pigeon --input pigeons/vpn_api.dart`. Метод `vpnEvents()` → Dart-функция `Stream<VpnEventMessage> vpnEvents()`; Kotlin/Swift StreamHandler-класс — `VpnEventsStreamHandler`.
Примечание по полям: официальный event-пример использует `final`-поля с конструктором для подклассов события; для data-классов допустимы и non-null поля с `required`-конструктором, и классический стиль `late`. Точную допустимость non-null полей codegen проверит немедленно — при ошибке переключиться на `late`-поля. `[VERIFIED: pigeon example — sealed class {} + extends; @async; @ConfigurePigeon]`

### Code Example 2 — Kotlin: регистрация в `MainActivity`
```kotlin
// Source: pigeon example MainActivity.kt (configureFlutterEngine + setUp + StreamHandler.register)
package com.example.vpn_oko

import com.example.vpn_oko.bridge.VpnHostApi
import com.example.vpn_oko.bridge.VpnEventsStreamHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    val messenger = flutterEngine.dartExecutor.binaryMessenger
    VpnHostApi.setUp(messenger, VpnHostApiImpl())
    VpnEventsStreamHandler.register(messenger, VpnEventListener())
  }
}
```
`[VERIFIED: pigeon example — ExampleHostApi.setUp(binaryMessenger, api); StreamEventsStreamHandler.register(binaryMessenger, handler)]`

### Code Example 3 — Kotlin: echo-эмиттер + StreamHandler (main thread + replay)
```kotlin
// Source: pigeon example EventListener (: <Method>StreamHandler(), PigeonEventSink, Handler(Looper.getMainLooper()))
package com.example.vpn_oko.bridge

import android.os.Handler
import android.os.Looper
import com.example.vpn_oko.bridge.*

object VpnEventBus {
  private val listeners = mutableSetOf<(VpnEventMessage) -> Unit>()
  var lastStatus: StatusChangedMessage = StatusChangedMessage(status = VpnStatusMessage.DISCONNECTED)
    private set
  var snapshot: VpnStatusSnapshotMessage =
    VpnStatusSnapshotMessage(status = VpnStatusMessage.DISCONNECTED, rxBytes = 0, txBytes = 0)
    private set

  fun addListener(l: (VpnEventMessage) -> Unit) { listeners += l; l(lastStatus) }
  fun removeListener(l: (VpnEventMessage) -> Unit) { listeners -= l }

  fun emit(event: VpnEventMessage) {
    if (event is StatusChangedMessage) {
      lastStatus = event
      snapshot = VpnStatusSnapshotMessage(
        status = event.status,
        connectedSinceEpochMs = event.connectedSinceEpochMs,
        rxBytes = snapshot.rxBytes, txBytes = snapshot.txBytes,
      )
    }
    listeners.toList().forEach { it(event) }
  }
}

class VpnEventListener : VpnEventsStreamHandler() {
  private val mainHandler = Handler(Looper.getMainLooper())
  private var sink: PigeonEventSink<VpnEventMessage>? = null
  private val forward: (VpnEventMessage) -> Unit = { e -> mainHandler.post { sink?.success(e) } }

  override fun onListen(p0: Any?, sink: PigeonEventSink<VpnEventMessage>) {
    this.sink = sink
    VpnEventBus.addListener(forward)
  }

  override fun onCancel(p0: Any?) {
    VpnEventBus.removeListener(forward)
    sink = null
  }
}
```
`addListener` реплеит `lastStatus` подписчику сразу (закрывает Pitfall 2). `emit` вызывается echo-impl-ом из любого потока; доставка — `mainHandler.post`. Имена enum-констант в Kotlin — UPPER_CASE (`VpnStatusMessage.DISCONNECTED`). `[VERIFIED: pigeon example — onListen(p0, sink), PigeonEventSink.success, register]`

### Code Example 4 — Swift: регистрация (новый шаблон) + echo StreamHandler
```swift
// Source: Flutter breaking-changes/uiscenedelegate (didInitializeImplicitFlutterEngine,
//         engineBridge.applicationRegistrar.messenger()) + pigeon example StreamHandler
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    VpnHostApiSetup.setUp(binaryMessenger: messenger, api: VpnHostApiImpl())
    VpnEventsStreamHandler.register(with: messenger, streamHandler: VpnEventListener.shared)
  }
}

class VpnEventListener: VpnEventsStreamHandler {
  static let shared = VpnEventListener()
  private var eventSink: PigeonEventSink<VpnEventMessage>?
  private(set) var lastStatus = StatusChangedMessage(status: .disconnected)

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<VpnEventMessage>) {
    eventSink = sink
    emit(lastStatus)
  }
  override func onCancel(withArguments arguments: Any?) { eventSink = nil }

  func emit(_ event: VpnEventMessage) {
    if let s = event as? StatusChangedMessage { lastStatus = s }
    DispatchQueue.main.async { [weak self] in self?.eventSink?.success(event) }
  }
}
```
Ключевое отличие от примера pigeon: messenger берётся из `engineBridge.applicationRegistrar.messenger()`, регистрация — в `didInitializeImplicitFlutterEngine`, НЕ через `rootViewController`. Swift-setup HostApi называется `VpnHostApiSetup.setUp(binaryMessenger:api:)` (в Kotlin — `VpnHostApi.setUp`). `[VERIFIED: Flutter docs uiscenedelegate — applicationRegistrar.messenger(); pigeon example — StreamEventsStreamHandler.register(with:streamHandler:), ExampleHostApiSetup.setUp]`

### Code Example 5 — Dart: `VpnBridge` (одна подписка + демультиплекс, тестируемый)
```dart
// core/bridge/vpn_bridge.dart  — импорт vpn_api.g.dart разрешён (core/bridge)
import 'dart:async';
import 'package:vpn_oko/core/bridge/vpn_api.g.dart';

class VpnBridge {
  VpnBridge({required VpnHostApi hostApi, required Stream<VpnEventMessage> events})
      : _hostApi = hostApi {
    _sub = events.listen(_dispatch);
  }

  final VpnHostApi _hostApi;
  late final StreamSubscription<VpnEventMessage> _sub;
  final _status = StreamController<StatusChangedMessage>.broadcast();
  final _logs = StreamController<LogMessage>.broadcast();
  final _traffic = StreamController<TrafficChangedMessage>.broadcast();
  final _errors = StreamController<ErrorMessage>.broadcast();

  Stream<StatusChangedMessage> get statusEvents => _status.stream;
  Stream<LogMessage> get logEvents => _logs.stream;
  Stream<TrafficChangedMessage> get trafficEvents => _traffic.stream;
  Stream<ErrorMessage> get errorEvents => _errors.stream;

  Future<void> startVpn(VpnConfigMessage config) => _hostApi.startVpn(config);
  Future<void> stopVpn() => _hostApi.stopVpn();
  Future<VpnStatusSnapshotMessage> getStatus() => _hostApi.getStatus();

  void _dispatch(VpnEventMessage e) {
    switch (e) {
      case StatusChangedMessage(): _status.add(e);
      case LogMessage(): _logs.add(e);
      case TrafficChangedMessage(): _traffic.add(e);
      case ErrorMessage(): _errors.add(e);
    }
  }

  Future<void> dispose() async {
    await _sub.cancel();
    await _status.close(); await _logs.close();
    await _traffic.close(); await _errors.close();
  }
}
```
В composition root: `VpnBridge(hostApi: VpnHostApi(), events: vpnEvents())`. В тестах: `VpnBridge(hostApi: MockVpnHostApi(), events: controller.stream)`.

### Code Example 6 — Dart: repository с replay кэша (BRG-04)
```dart
// features/vpn_connection/data/repositories/vpn_repository_impl.dart
class VpnRepositoryImpl implements VpnRepository {
  VpnRepositoryImpl(this._ds) {
    _ds.states.listen((s) { _last = s; _controller.add(s); });
  }
  final VpnNativeDatasource _ds;
  final _controller = StreamController<VpnState>.broadcast();
  VpnState _last = const VpnDisconnected();

  @override
  Stream<VpnState> watchState() async* {
    yield _last;
    yield* _controller.stream;
  }

  @override
  Future<void> syncStatus() async {
    _last = (await _ds.currentStatus()).toEntity();
    _controller.add(_last);
  }
}
```

### Code Example 7 — Dart: маппер DTO→entity (BRG-03, чистый, тестируемый)
```dart
// features/vpn_connection/data/mappers/vpn_event_mapper.dart
VpnState statusToEntity(StatusChangedMessage m) => switch (m.status) {
      VpnStatusMessage.disconnected => const VpnDisconnected(),
      VpnStatusMessage.connecting => const VpnConnecting(),
      VpnStatusMessage.connected => VpnConnected(
          connectedSince: DateTime.fromMillisecondsSinceEpoch(m.connectedSinceEpochMs ?? 0)),
      VpnStatusMessage.disconnecting => const VpnDisconnecting(),
      VpnStatusMessage.error => const VpnError('unknown'),
    };

LogEntry logToEntity(LogMessage m) => LogEntry(
      text: m.text,
      level: LogLevel.values.byName(m.level),
      time: DateTime.fromMillisecondsSinceEpoch(m.timestampMillis),
    );
```

### Code Example 8 — Dart: доменные модели (CORE-01, sealed + equatable)
```dart
// features/vpn_connection/domain/entities/vpn_state.dart
import 'package:equatable/equatable.dart';

sealed class VpnState extends Equatable {
  const VpnState();
  @override
  List<Object?> get props => const [];
}
class VpnDisconnected extends VpnState { const VpnDisconnected(); }
class VpnConnecting extends VpnState { const VpnConnecting(); }
class VpnConnected extends VpnState {
  const VpnConnected({required this.connectedSince});
  final DateTime connectedSince;
  @override
  List<Object?> get props => [connectedSince];
}
class VpnDisconnecting extends VpnState { const VpnDisconnecting(); }
class VpnError extends VpnState {
  const VpnError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
```

### Code Example 9 — Dart: composition root (`app/di.dart`)
```dart
// app/di.dart — единственное место связывания слоёв
import 'package:vpn_oko/core/bridge/vpn_api.g.dart';
import 'package:vpn_oko/core/bridge/vpn_bridge.dart';

class AppDependencies {
  AppDependencies()
      : _bridge = VpnBridge(hostApi: VpnHostApi(), events: vpnEvents()) {
    final ds = VpnNativeDatasource(_bridge);
    vpnRepository = VpnRepositoryImpl(ds);
    watchVpnState = WatchVpnState(vpnRepository);
    connectVpn = ConnectVpn(vpnRepository);
    disconnectVpn = DisconnectVpn(vpnRepository);
  }
  final VpnBridge _bridge;
  late final VpnRepository vpnRepository;
  late final WatchVpnState watchVpnState;
  late final ConnectVpn connectVpn;
  late final DisconnectVpn disconnectVpn;
}
```
В Phase 3 `main()` оборачивает дерево в `BlocProvider`, читающий usecases из `AppDependencies`.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Сырые MethodChannel/EventChannel + `Map<String,Object?>` | pigeon @HostApi + @EventChannelApi (sealed события) | pigeon 22+ (event channels); 27.x — стабильно | Типобезопасность, генерация 3 языков, exhaustive switch |
| @FlutterApi-коллбеки для событий | @EventChannelApi с onListen/onCancel | pigeon event channels | Семантика подписки/отписки из коробки; STATE.md-fallback снят |
| iOS: `window.rootViewController as! FlutterViewController` для messenger | `engineBridge.applicationRegistrar.messenger()` в `didInitializeImplicitFlutterEngine` | Flutter UIScene (шаблон 3.44) | rootViewController-путь ломается на новом шаблоне (#185935) |

**Deprecated/outdated:**
- Регистрация pigeon через rootViewController в новом iOS-шаблоне — приводит к `MissingPluginException`.
- mockito/@GenerateMocks — заменён mocktail (без build_runner).
- freezed для 3–4 моделей — заменён Dart 3 sealed + equatable.

## Runtime State Inventory

Не применимо: Phase 1 — greenfield (свежий Flutter-скаффолд, никаких rename/refactor/migration). Существующий код: `lib/main.dart` («Hello World»), дефолтные `MainActivity.kt`/`AppDelegate.swift`, `analysis_options.yaml` (flutter_lints). Всё это заменяется/дополняется, но не мигрируется как данные.
- **Stored data:** None — базы/датасторов нет.
- **Live service config:** None — внешних сервисов нет.
- **OS-registered state:** None — сервисов/задач ОС нет (VpnService — Phase 2).
- **Secrets/env vars:** None — секретов нет; демо-VLESS зашивается позже (Phase 4).
- **Build artifacts:** `pubspec.lock` пересоберётся при `pub add`; генерированные `*.g.*` создаются впервые. Стейл-артефактов нет.

## Common-sense Security Domain

`security_enforcement` в config.json отсутствует → считается включённым. Для echo-фазы поверхность атаки минимальна (нет сети, нет реального туннеля, нет парсинга внешнего ввода — VLESS в Phase 4, VpnService-permission в Phase 2).

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | частично | Контракт типизирован pigeon; echo-конфиг зашит, внешнего ввода нет |
| V6 Cryptography | no | Крипто нет на этой фазе |
| V7 Logging | да (проактивно) | Не логировать секреты: `LogMessage` на echo-фазе не должен содержать реальных кред (UUID VLESS — Phase 4, там маскировать) |

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Утечка кред в логах моста | Information Disclosure | Не класть UUID/полный VLESS URI в `LogMessage`; на echo — синтетические тексты |
| Экспорт компонентов Android | Elevation of Privilege | `BIND_VPN_SERVICE` + `exported=false` — Phase 2; в Phase 1 новых экспортируемых компонентов не добавляем |

Основные VPN-контроли (BIND_VPN_SERVICE, foregroundServiceType, POST_NOTIFICATIONS, onRevoke) относятся к Phase 2 — см. PITFALLS.md.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Весь Dart-слой + codegen | ✓ | 3.44.5 stable | — |
| Dart SDK | Codegen, тесты | ✓ | 3.12.2 | — |
| pigeon | Генерация моста | ✓ (pub) | 27.1.1 | — |
| Xcode | Компиляция iOS echo | ✓ | 26.4.1 | — |
| Android SDK | Компиляция Kotlin echo | ✓ | present (`~/Library/Android/sdk`) | — |
| adb (PATH) | Запуск на эмуляторе/устройстве | ✗ (не в PATH) | — | `~/Library/Android/sdk/platform-tools/adb`; для codegen+компиляции+unit-тестов не нужен |
| Android emulator / iOS simulator | End-to-end прогон echo | не проверено | — | Верификация Phase 1 достаточна на уровне codegen + `flutter analyze` + `flutter test` + компиляция обеих платформ; live-прогон echo — опциональная ручная проверка |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** adb не в PATH (полный путь известен); эмулятор/симулятор для live-echo не подтверждён — не блокирует основную верификацию фазы.

## Validation Architecture

`workflow.nyquist_validation: true` → секция включена.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) + mocktail 1.0.5 |
| Config file | none (дефолт flutter_test); тесты в `test/` |
| Quick run command | `flutter test test/features/vpn_connection/data` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CORE-01 | VpnState/VpnConfig/VpnEvent — равенство (equatable), иммутабельность | unit | `flutter test test/features/vpn_connection/domain/entities/vpn_state_test.dart` | ❌ Wave 0 |
| BRG-03 | Маппер StatusChangedMessage→VpnState (все 5 статусов, connectedSince) | unit | `flutter test test/features/vpn_connection/data/mappers/vpn_event_mapper_test.dart` | ❌ Wave 0 |
| BRG-03 | Маппер LogMessage→LogEntry (уровни, timestamp) | unit | `flutter test test/features/vpn_logs/data/mappers/log_mapper_test.dart` | ❌ Wave 0 |
| BRG-02 | VpnBridge демультиплексирует sealed-события в правильные broadcast-стримы | unit | `flutter test test/core/bridge/vpn_bridge_test.dart` | ❌ Wave 0 |
| BRG-04 | VpnRepositoryImpl отдаёт last-статус первым (replay); syncStatus обновляет кэш | unit | `flutter test test/features/vpn_connection/data/repositories/vpn_repository_impl_test.dart` | ❌ Wave 0 |
| BRG-01 | startVpn/stopVpn/getStatus проксируются в VpnHostApi (mock) | unit | `flutter test test/core/bridge/vpn_bridge_test.dart` | ❌ Wave 0 |

Тесты на этой фазе — чистый Dart с mocktail-моком `VpnHostApi` и `StreamController` для событий; платформа не нужна. Kotlin/Swift echo проверяются компиляцией + (опционально) ручным прогоном, не unit-тестами Dart. Bloc-тесты (QA-02) — Phase 3.

### Sampling Rate
- **Per task commit:** `flutter analyze && flutter test test/<изменённый каталог>`
- **Per wave merge:** `flutter test`
- **Phase gate:** `flutter analyze` без ошибок + `flutter test` зелёный + `dart run pigeon --input pigeons/vpn_api.dart` без ошибок + сборка Android (`flutter build apk --debug` или compile) и iOS (`flutter build ios --no-codesign` / `xcodebuild` Runner) проходят.

### Wave 0 Gaps
- [ ] `test/features/vpn_connection/domain/entities/vpn_state_test.dart` — CORE-01
- [ ] `test/features/vpn_connection/data/mappers/vpn_event_mapper_test.dart` — BRG-03
- [ ] `test/features/vpn_logs/data/mappers/log_mapper_test.dart` — BRG-03
- [ ] `test/core/bridge/vpn_bridge_test.dart` — BRG-01/BRG-02 (mock VpnHostApi + StreamController)
- [ ] `test/features/vpn_connection/data/repositories/vpn_repository_impl_test.dart` — BRG-04 (fake datasource)
- [ ] `test/helpers/` — общие фейки (FakeVpnNativeDatasource, MockVpnHostApi)
- [ ] Framework install: `flutter pub add --dev mocktail` (bloc_test — при добавлении Bloc в Phase 3)

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Non-null поля в data-классах pigeon (`String host;` с required-конструктором) генерируются корректно в 27.1.1 | Code Example 1 | LOW — codegen падает немедленно; фикс: перейти на `late`-поля или nullable |
| A2 | Swift HostApi-setup называется `VpnHostApiSetup.setUp` (по паттерну `ExampleHostApiSetup`); Kotlin — `VpnHostApi.setUp` | Code Example 2, 4 | LOW — точное имя видно в сгенерированном Messages.g.swift сразу после первого прогона |
| A3 | `engineBridge.applicationRegistrar.messenger()` доступен в момент `didInitializeImplicitFlutterEngine` для регистрации pigeon | Code Example 4 | MEDIUM — verified из офиц. docs для method channels; для pigeon setUp путь идентичен (тот же messenger), но точный порядок проверить прогоном на симуляторе |
| A4 | Kotlin enum-константы генерируются UPPER_CASE (`VpnStatusMessage.DISCONNECTED`) | Code Example 3 | LOW — видно в Messages.g.kt; при lowerCamel поправить обращения |
| A5 | Верификация echo-фазы на уровне codegen+analyze+test+компиляция достаточна без обязательного live-прогона на устройстве | Environment Availability, Validation | MEDIUM — live-прогон доказывает мост end-to-end; если планировщик хочет гарантию BRG-02/04 «руками», добавить checkpoint с эмулятором |

## Open Questions (RESOLVED)

1. **Точные имена сгенерированных Swift/Kotlin символов (setUp, enum-константы).**
   - What we know: паттерн из официального примера — Kotlin `VpnHostApi.setUp`, Swift `VpnHostApiSetup.setUp`, StreamHandler `VpnEventsStreamHandler`, sink `PigeonEventSink<T>`.
   - What's unclear: точный кейс enum-констант и возможные суффиксы — видно только после первого `dart run pigeon`.
   - RESOLVED: план 01-01 (задача T2) генерирует контракт первой задачей и передаёт точные имена символов в SUMMARY вниз по волнам (планы 03/05/06). Снимает A2/A4.

2. **Live end-to-end echo (BRG-02/BRG-04 «руками»).**
   - What we know: unit-тесты покрывают демультиплекс, replay, мапперы; компиляция обеих платформ проверяется в phase gate.
   - What's unclear: доступность эмулятора/симулятора для прогона реального стрима из Kotlin/Swift в Dart.
   - RESOLVED: план 01-07 (задача T2) — `checkpoint:human-verify`: запуск на эмуляторе Android, echo-Connect, StatusChanged/LogMessage в debug-harness; при недоступности эмулятора фиксируется в README как ограничение.

3. **Формат VpnConfigMessage под будущий VLESS.**
   - What we know: echo-конфиг зашит; поля host/port/userId/serverName достаточны для echo.
   - What's unclear: полный набор VLESS-полей (sni, type, security, pbk) появится в Phase 4.
   - RESOLVED: контракт под VLESS сейчас не расширяется (решение зафиксировано в 01-01); Phase 4 добавит поля, мапперы поглотят изменение.

## Sources

### Primary (HIGH confidence)
- [pigeon README — flutter/packages](https://raw.githubusercontent.com/flutter/packages/main/packages/pigeon/README.md) — @EventChannelApi только Swift/Kotlin/Dart; abstract class без `Stream<>`
- [pigeon example README + MainActivity.kt + AppDelegate.swift](https://github.com/flutter/packages/tree/main/packages/pigeon/example/app) — генерируемые `StreamEventsStreamHandler`, `PigeonEventSink<T>`, `onListen(p0, sink)`/`onCancel`, `.success`/`.endOfStream`, `Handler(Looper.getMainLooper())` / `DispatchQueue.main`, `register(...)`, `ExampleHostApi.setUp` / `ExampleHostApiSetup.setUp`
- [pigeon event_channel_tests.dart](https://raw.githubusercontent.com/flutter/packages/main/packages/pigeon/pigeons/event_channel_tests.dart) — `sealed class PlatformEvent {}` + `class IntEvent extends PlatformEvent { final ... }`, `@EventChannelApi`
- [Flutter — UISceneDelegate adoption](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate) — `didInitializeImplicitFlutterEngine`, `engineBridge.applicationRegistrar.messenger()`
- pub.dev через `dart pub add --dry-run` — версии: pigeon 27.1.1, flutter_bloc 9.1.1, bloc 9.2.1, equatable 2.1.0, mocktail 1.0.5, very_good_analysis 10.3.0, bloc_test 10.0.0
- Локальный toolchain — Flutter 3.44.5, Dart 3.12.2, Xcode 26.4.1, Kotlin 2.3.20 / AGP 9.0.1 (settings.gradle.kts), пакет `com.example.vpn_oko`, iOS deployment target 13.0

### Secondary (MEDIUM confidence)
- [flutter/flutter#185935](https://github.com/flutter/flutter/issues/185935) — `MissingPluginException` при неправильной регистрации после UIScene-миграции
- [flutter/flutter#161291](https://github.com/flutter/flutter/issues/161291) — ограничения @EventChannelApi при нескольких input-файлах
- Проектные research-доки: STACK.md, ARCHITECTURE.md, PITFALLS.md (2026-07-13)

### Tertiary (LOW confidence)
- нет — все ключевые claim'ы подтверждены официальными источниками или dry-run

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — все версии подтверждены `dart pub add --dry-run` в этом проекте
- Pigeon event-channel синтаксис + генерируемые имена: HIGH — сверено с официальным example (Dart/Kotlin/Swift)
- iOS-регистрация (новый шаблон): HIGH — официальный breaking-changes doc; точный вызов pigeon-setUp — MEDIUM (A3, проверить прогоном)
- Architecture / patterns: HIGH — из research-доков + официальных примеров
- Pitfalls: HIGH — Android/Flutter/pigeon подтверждены офиц. доками
- Точные сгенерированные символы (enum-кейс, setUp-суффикс): MEDIUM — снимается первым codegen (Open Question 1)

**Research date:** 2026-07-13
**Valid until:** 2026-08-12 (30 дней; pigeon/Flutter — умеренно быстрый темп, следить за минорами pigeon 27.x)
