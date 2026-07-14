# Phase 5: iOS-мост и Network Extension — Research

**Researched:** 2026-07-14
**Domain:** iOS NetworkExtension (Packet Tunnel Provider) + Swift Pigeon-мост в Flutter-приложении
**Confidence:** HIGH по среде и структуре проекта (проверено по коду и локальным тулзам); HIGH по строкам конфигурации NE (сверено с Apple docs / kean.blog / SimpleTunnel); MEDIUM по деталям NETunnelProviderManager async-вариантов (Apple doc-страницы JS-рендер, WebFetch не читает — API стабилен с iOS 9, сверен с образцами)

<user_constraints>
## User Constraints

> CONTEXT.md для этой фазы не создан (папка `.planning/phases/05-ios-network-extension/` пуста). Ограничения ниже взяты из locked-решений STATE.md / PROJECT.md и напрямую констрейнят фазу. Планнер обязан их соблюдать; discuss-phase может уточнить помеченные `[ASSUMED]` пункты.

### Locked Decisions (STATE.md · Accumulated Context)
- **iOS делается полноценно:** Swift Pigeon-мост + реальный NE-таргет (PacketTunnelProvider + NETunnelProviderManager), проверка через TestFlight. Apple Developer аккаунт есть (team `Z2GDTXHVZZ` уже прописан в проекте). Это НЕ echo-заглушка — echo фазы 1 заменяется реальным менеджером.
- **Узкий маршрут туннеля** (locked, паритет с Android): туннель поднимается, но `includedRoutes` — узкая тестовая подсеть (Android использует `10.111.222.0/24`), а не `0.0.0.0/0`. Интернет устройства в Connected жив, реальный VPN-core не подключается.
- **Без реального VPN-core:** extension поднимает `NEPacketTunnelNetworkSettings` и завершает `startTunnel` успешно; чтение `packetFlow` опционально (read-and-drop как на Android), форвардинг пакетов вне скоупа (Out of Scope в REQUIREMENTS.md).
- **Pigeon** (@HostApi + @EventChannelApi поверх sealed `VpnEventMessage`) — единственный мост, контракт зафиксирован в фазе 1, не меняется.
- **Bloc** (flutter_bloc) для state management; native — источник истины по статусу.
- **Feature-first Clean Architecture, SOLID, БЕЗ комментариев в коде** (Dart/Kotlin/Swift). Доки/README/commit — русский, идентификаторы — английский.

### Claude's Discretion
- Способ передачи конфига в extension: `NETunnelProviderProtocol.providerConfiguration` vs shared UserDefaults App Group (research рекомендует `providerConfiguration` для конфига + App Group для логов/маркеров).
- Маппинг `NEVPNStatus.reasserting` и `.invalid` в доменные статусы.
- Точное имя App Group (research рекомендует `group.com.example.vpnOko`, консистентно с реальным bundle id).
- Механизм добавления NE-таргета в `Runner.xcodeproj` (research рекомендует Ruby-гем `xcodeproj`, см. Don't Hand-Roll).

### Deferred Ideas (OUT OF SCOPE — не трогать)
- Проксирование реального трафика на iOS-туннеле (EXT-03).
- Интеграция реального core sing-box/xray как xcframework (EXT-02) — только упоминание в README (DOC-03, фаза 6).
- Kill switch, split tunneling, per-app VPN, always-on/reconnect.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **IOS-01** | Swift-реализация Pigeon-моста в приложении: startVpn/stopVpn/getStatus + поток событий работают, демо на iOS показывает статусы/логи из Swift-слоя | Заменить echo `VpnHostApiImpl.swift` на реальный `NETunnelProviderManager`; `VpnEventListener` (уже есть) остаётся эмиттером с main-queue доставкой. На симуляторе NE недоступен → путь ошибки эмитит статус/лог из Swift-слоя (см. Open Q1). Символы моста зафиксированы в 01-01/01-06 |
| **IOS-02** | NE-таргет с PacketTunnelProvider: start/stop туннеля через NETunnelProviderManager, NEPacketTunnelNetworkSettings применяются | Новый app-extension таргет `PacketTunnel` (Pattern 1); `startTunnel`/`stopTunnel`/`setTunnelNetworkSettings` (Code Example 3); менеджер-флоу load→configure→save→**reload**→startVPNTunnel (Pitfall 3, Code Example 4) |
| **IOS-03** | Статусы туннеля из extension доводятся до приложения (NEVPNStatus observer) и дальше во Flutter | KVO/`NEVPNStatusDidChange` на `connection.status` → маппинг в `StatusChangedMessage` → `VpnEventListener.emit` (Code Example 5); `connectedDate` → `connectedSinceEpochMs` |
| **IOS-04** | Capabilities, entitlements (Packet Tunnel), App Groups настроены; сборка готова к TestFlight на устройстве | Два `.entitlements` (Runner + PacketTunnel) с NE + App Groups (Code Example 2); wire `CODE_SIGN_ENTITLEMENTS`; portal-регистрация App ID + capabilities для TestFlight (Pitfall 6, checkpoint:human-verify) |
</phase_requirements>

## Summary

Фаза добавляет второй нативный target в `Runner.xcodeproj` — app-extension `PacketTunnel` с подклассом `NEPacketTunnelProvider` — и заменяет echo-реализацию Swift Pigeon-моста (`ios/Runner/Bridge/VpnHostApiImpl.swift`) на реальный `NETunnelProviderManager`. Контракт Pigeon и `VpnEventListener` (main-queue эмиттер, replay lastStatus, snapshot) из фазы 1 переиспользуются без изменений — меняется только источник событий: вместо синтетической цепочки статусы приходят из `NEVPNStatusDidChange`-наблюдателя за `connection.status`.

Главное ограничение фазы: **Network Extension не исполняется в iOS Simulator** — `saveToPreferences`/`startVPNTunnel` на симуляторе возвращают ошибку. Поэтому автоматизируемая верификация — это **компиляция обоих таргетов** (симулятор `xcodebuild -sdk iphonesimulator` и `flutter build ios --no-codesign`) плюс работа Swift-моста в симуляторе (статусы/логи из Swift-слоя, включая честный путь ошибки «NE недоступен»). Реальный старт туннеля проверяется **только на физическом устройстве через TestFlight** — это требует portal-регистрации двух App ID (`com.example.vpnOko`, `com.example.vpnOko.PacketTunnel`) с capability Network Extensions + App Groups и provisioning-профилей (`checkpoint:human-verify`).

Критическая находка: **реальный iOS bundle id — `com.example.vpnOko` (camelCase), а не `com.example.vpn_oko`**, как указано в задании. Flutter конвертирует подчёркивание в camelCase для iOS. Все производные (extension bundle id, App Group, entitlements) считать от `com.example.vpnOko`.

**Primary recommendation:** Добавить target `PacketTunnel` программно через Ruby-гем `xcodeproj` (1.27.0, идёт с CocoaPods — уже установлен), а не ручной правкой pbxproj и не через Xcode GUI. Extension bundle id `com.example.vpnOko.PacketTunnel`, App Group `group.com.example.vpnOko`, deployment target 13.0 (как Runner), SWIFT_VERSION 5.0. Мост использует completion-handler API (не async — deployment 13.0). Верификация фазы = зелёная компиляция обоих таргетов + Swift-мост в симуляторе; реальный туннель — device/TestFlight checkpoint.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Pigeon HostApi impl (startVpn/stopVpn/getStatus) | App / Container (Runner) | — | Управление профилем доступно только контейнер-приложению, не extension |
| VPN-профиль: создать/настроить/save/load/start | App / Container (Runner) | iOS Preferences (VPN config в Settings) | `NETunnelProviderManager` живёт в приложении; сам профиль — OS-registered state в Settings |
| Подъём/спуск туннеля (startTunnel/stopTunnel, network settings) | Network Extension process (`PacketTunnel`) | — | iOS исполняет код туннеля ТОЛЬКО в отдельном NE-процессе (Anti-Pattern 6 ARCHITECTURE) |
| Наблюдение статуса (NEVPNStatusDidChange → Flutter) | App / Container (Runner) | — | `connection.status` читается со стороны приложения, не из extension |
| Обмен конфигом/логами app↔extension | App Group (shared container) | `providerConfiguration` в профиле | Единственный легальный канал между двумя процессами |
| Entitlements / signing / target-wiring | Build / project config (pbxproj, .entitlements) | Apple Developer portal | NE + App Groups требуют entitlement у ОБОИХ таргетов; TestFlight — portal capabilities |

## Project Constraints (from CLAUDE.md / CONVENTIONS.md)

- **Комментарии в коде запрещены** (Swift тоже) — `very_good_analysis` для Dart; Swift/Kotlin — конвенции платформ, имена несут смысл. [VERIFIED: codebase CONVENTIONS.md]
- **События native→Flutter только с main thread** платформы (Swift: `DispatchQueue.main`) — уже реализовано в `VpnEventListener.emit`. [VERIFIED: codebase]
- **Ошибки:** PlatformException/NE-ошибки → typed Failure в data-слое; UI получает доменные ошибки, не строки платформы. Swift-сторона эмитит `ErrorMessage(code, message)`; маппинг в domain делает Dart data-слой. [VERIFIED: codebase]
- **Импорт `*.g.dart`** разрешён только в `core/bridge/` и `features/*/data/` — extension pigeon НЕ использует (чистый Swift NE-код). [VERIFIED]
- **Native — источник истины по статусу VPN**; `getStatus()` отдаёт снапшот, `onListen` реплеит lastStatus. [VERIFIED: 01-06-SUMMARY]
- **Русский** для README/доков/commit; **английский** для идентификаторов и кода. [VERIFIED: global CLAUDE.md + CONVENTIONS]
- **Test-as-you-go**; mocktail для Dart-моков. Swift NE-код юнит-тестами в этом проекте не покрывается (нет XCTest-инфры для NE; верификация — компиляция + device). [VERIFIED: CONVENTIONS]

## Standard Stack

Фаза НЕ ставит внешних пакетов (npm/PyPI/crates/pub). Использует системные фреймворки Apple и уже установленные тулзы. «Стек» здесь — фреймворки, API и версии тулинга.

### Core (Apple frameworks / API)
| Framework / API | Version / Availability | Purpose | Why Standard |
|-----------------|------------------------|---------|--------------|
| `NetworkExtension` (NEPacketTunnelProvider) | iOS 9.0+ (стабилен) | Подкласс провайдера туннеля в NE-процессе | Единственный API для custom-VPN на iOS [CITED: developer.apple.com/documentation/networkextension/nepackettunnelprovider] |
| `NETunnelProviderManager` : `NEVPNManager` | iOS 9.0+ | Управление профилем и туннелем из приложения | Единственный способ создать/запустить packet-tunnel профиль [CITED: Apple docs] |
| `NEPacketTunnelNetworkSettings` + `NEIPv4Settings` + `NEDNSSettings` + `NEIPv4Route` | iOS 9.0+ | Конфиг сетевых настроек туннеля (адреса, маршруты, DNS, MTU) | Сверено с Apple SimpleTunnel [CITED: raw.githubusercontent.com/ios-sample-code/SimpleTunnel] |
| `NEVPNStatusDidChange` notification + `NEVPNConnection.status` (`NEVPNStatus`) | iOS 8.0+ | Наблюдение статуса туннеля со стороны приложения (IOS-03) | Штатный механизм статусов; `connectedDate` даёт uptime [ASSUMED: training, стабильный API] |
| `pigeon`-сгенерированный Swift (`Messages.g.swift`) | pigeon 27.1.1 (уже в проекте) | HostApi + EventChannel мост | Контракт из фазы 1, символы зафиксированы (01-01-SUMMARY) [VERIFIED: codebase] |

### Supporting (tooling — всё уже установлено локально)
| Tool | Version (verified locally) | Purpose | Notes |
|------|----------------------------|---------|-------|
| Xcode | **26.4.1** (build 17E202) | Компиляция обоих таргетов, archive для TestFlight | iOS SDK 26.4 (device+simulator) [VERIFIED: xcodebuild -version] |
| Swift | 6.3.1 (компилятор) | Язык extension и моста | Проект в language mode `SWIFT_VERSION = 5.0` — strict concurrency off, completion-handler API компилируется без Sendable-ошибок [VERIFIED: codebase + swift --version] |
| Flutter | 3.44.5 stable / Dart 3.12.2 | `flutter build ios --no-codesign` — компиляция Runner + embedded extension | [VERIFIED: flutter --version] |
| CocoaPods | 1.16.2 | Интеграция pods для Runner/RunnerTests | Extension pods НЕ использует → в Podfile не добавляется [VERIFIED: pod --version] |
| **`xcodeproj` (Ruby gem)** | **1.27.0** (идёт с CocoaPods) | Программное добавление NE-таргета в pbxproj без Xcode GUI | Та же библиотека, что использует CocoaPods; безопаснее ручной правки (см. Don't Hand-Roll) [VERIFIED: ruby -e require 'xcodeproj'] |
| Ruby | 2.6.10 (system) | Запуск `xcodeproj`-скрипта | Достаточно для гема 1.27.0 [VERIFIED] |

### Проверенные параметры проекта (из `ios/Runner.xcodeproj/project.pbxproj`)
| Параметр | Значение | Provenance |
|----------|----------|------------|
| iOS bundle id (Runner) | **`com.example.vpnOko`** (НЕ `vpn_oko`) | [VERIFIED: grep pbxproj, строки 396/576/599] |
| DEVELOPMENT_TEAM | `Z2GDTXHVZZ` (реальный, уже прописан) | [VERIFIED: pbxproj] |
| IPHONEOS_DEPLOYMENT_TARGET | `13.0` | [VERIFIED: pbxproj] |
| SWIFT_VERSION | `5.0` | [VERIFIED: pbxproj] |
| objectVersion | `54` (без `PBXFileSystemSynchronizedRootGroup` — файлы добавляются явно) | [VERIFIED: pbxproj] |
| Существующие таргеты | `Runner`, `RunnerTests` | [VERIFIED: pbxproj] |
| Существующие entitlements | НЕТ (ни одного `.entitlements` в проекте) | [VERIFIED: find] |
| Синтетические ID моста фазы 1 | префикс `A0000000000000000000xxxx` (конвенция ручных правок) | [VERIFIED: pbxproj] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Ruby `xcodeproj`-скрипт | Ручная правка pbxproj (как фаза 1) | Полный новый target = ~8 типов объектов (PBXNativeTarget, XCConfigurationList, 3×XCBuildConfiguration, PBXSourcesBuildPhase, PBXFrameworksBuildPhase, «Embed App Extensions» PBXCopyFilesBuildPhase, PBXTargetDependency, PBXContainerItemProxy, .appex PBXFileReference). Руками для 3 файлов было ок; для target — источник тонких ошибок |
| Ruby `xcodeproj`-скрипт | Xcode GUI (File→New→Target→Network Extension) | Запрещено паттерном проекта (безголовый CI-совместимый флоу); требует ручной клик, не воспроизводимо |
| `providerConfiguration` для конфига | Shared UserDefaults App Group | providerConfiguration персистится в профиле и читается extension из коробки; App Group нужен всё равно (IOS-04), но для логов/маркеров |
| completion-handler API | async/await (`loadAllFromPreferences() async`) | async-варианты требуют iOS 15/16+; deployment 13.0 → completion handlers (как SimpleTunnel/kean) |

**Installation:** внешних пакетов нет. Установочные действия — конфигурационные:
```bash
# xcodeproj-гем уже установлен (идёт с CocoaPods 1.16.2). Проверка:
ruby -e "require 'xcodeproj'; puts Xcodeproj::VERSION"   # => 1.27.0

# Компиляция обоих таргетов на симуляторе (основной автогейт фазы):
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -sdk iphonesimulator -configuration Debug build

# Компиляция без подписи (Runner + embedded PacketTunnel):
flutter build ios --no-codesign --debug
```

## Package Legitimacy Audit

**N/A — фаза не устанавливает внешних пакетов.** Используются только системные Apple-фреймворки (`NetworkExtension`, автолинкуется Swift-модулем) и уже установленный локально тулинг (Xcode, Flutter, CocoaPods, гем `xcodeproj` из CocoaPods). Registry-верификация (npm/pip/cargo/pub) не применима — новых зависимостей в `pubspec.yaml`, `Podfile` или иных манифестах не добавляется. slopcheck запускать не над чем.

## Architecture Patterns

### System Architecture Diagram

```
┌──────────────────────── Flutter (Dart) ────────────────────────┐
│  VpnBridge → VpnHostApi.startVpn/stopVpn/getStatus              │
│  vpnEvents(): Stream<VpnEventMessage>  (один EventChannel)      │
└───────────────┬───────────────────────────▲────────────────────┘
       Pigeon HostApi (binary messenger)     │ PigeonEventSink.success (main queue)
┌───────────────▼───────────────────────────┴──── iOS Runner (container app) ────┐
│  AppDelegate.didInitializeImplicitFlutterEngine                                 │
│    VpnHostApiSetup.setUp(api: VpnHostApiImpl)                                   │
│    VpnEventsStreamHandler.register(streamHandler: VpnEventListener.shared)      │
│                                                                                 │
│  VpnHostApiImpl  ──(1) loadAllFromPreferences ──► NETunnelProviderManager       │
│    │             ──(2) configure NETunnelProviderProtocol                       │
│    │                    providerBundleIdentifier = "…vpnOko.PacketTunnel"       │
│    │                    serverAddress = config.host                             │
│    │                    providerConfiguration = {host,port,subnet,…}            │
│    │             ──(3) saveToPreferences ──(4) loadFromPreferences (RELOAD)     │
│    │             ──(5) connection.startVPNTunnel()                              │
│    │                                                                            │
│  VpnStatusObserver ◄── NEVPNStatusDidChange (connection.status, connectedDate)  │
│    │  map NEVPNStatus → VpnStatusMessage → VpnEventListener.emit (main queue)   │
│    │                                                                            │
│  App Group: UserDefaults(suiteName:"group.com.example.vpnOko")  ◄── logs/marker │
└──────────────────────────────┬──────────────────────────────────────────────────┘
              startVPNTunnel triggers system to launch extension process
                               ▼
┌──────────── PacketTunnel (app-extension, SEPARATE PROCESS) ──────────────────────┐
│  PacketTunnelProvider : NEPacketTunnelProvider                                    │
│    startTunnel(options, completionHandler):                                       │
│      read providerConfiguration → build NEPacketTunnelNetworkSettings             │
│        .ipv4Settings = NEIPv4Settings(addresses, subnetMasks)                     │
│        .ipv4Settings.includedRoutes = [NEIPv4Route(10.111.222.0/24)]  ← узкий     │
│        .dnsSettings = NEDNSSettings(servers)                                      │
│        .mtu = 1500                                                                │
│      setTunnelNetworkSettings(settings) { completionHandler(nil) }                │
│      (опц.) packetFlow.readPackets loop → drop + счётчики                         │
│    stopTunnel(reason, completionHandler): teardown → completionHandler()          │
│  App Group: пишет "tunnel up"/логи в тот же suite                                 │
└───────────────────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure
```
ios/
├── Runner/                              # контейнер-приложение (существует)
│   ├── AppDelegate.swift                # регистрация pigeon (не менять)
│   ├── Bridge/
│   │   ├── Messages.g.swift             # pigeon (не менять)
│   │   ├── VpnHostApiImpl.swift         # ЗАМЕНИТЬ echo → NETunnelProviderManager
│   │   ├── VpnEventListener.swift       # переиспользовать (main-queue эмиттер)
│   │   └── VpnStatusObserver.swift      # НОВЫЙ: NEVPNStatusDidChange → emit
│   └── Runner.entitlements              # НОВЫЙ: NE + App Groups
└── PacketTunnel/                        # НОВЫЙ app-extension target
    ├── PacketTunnelProvider.swift       # NEPacketTunnelProvider skeleton
    ├── Info.plist                       # NSExtension: packet-tunnel + PrincipalClass
    └── PacketTunnel.entitlements        # NE + тот же App Group
```

### Pattern 1: Новый app-extension target через Ruby `xcodeproj`
**What:** target `PacketTunnel` (productType `com.apple.product-type.app-extension`, продукт `.appex`) добавляется скриптом на гем `xcodeproj`. Скрипт создаёт target, его 3 build-конфигурации, Sources-фазу с `PacketTunnelProvider.swift`, ставит `PBXTargetDependency` Runner→PacketTunnel и «Embed App Extensions» copy-фазу (`dstSubfolderSpec = 13` — PlugIns) в Runner.
**When to use:** любой headless-флоу добавления нативного target в Flutter iOS без Xcode GUI.
**Trade-offs:** гем валидирует граф объектов и генерирует корректные UUID — надёжнее ручной правки; минус — нужно написать одноразовый Ruby-скрипт (10-40 строк). Скрипт коммитится в репо (воспроизводимость, README DOC-02).

### Pattern 2: Реальный NETunnelProviderManager вместо echo (IOS-01/IOS-02)
**What:** `VpnHostApiImpl.startVpn` выполняет load→configure→save→**reload**→startVPNTunnel; `stopVpn` — `connection.stopVPNTunnel()`; `getStatus` читает `connection.status`/`connectedDate`. `VpnEventListener` (уже есть) не трогается — он остаётся единственной точкой emit с main queue.
**When to use:** штатный флоу управления packet-tunnel профилем из контейнер-приложения.
**Trade-offs:** обязателен reload после save до старта (Pitfall 3), иначе `NEVPNError.configurationStale`.

### Pattern 3: NEVPNStatus observer → Pigeon event (IOS-03)
**What:** отдельный `VpnStatusObserver` подписывается на `NEVPNStatusDidChange` для `manager.connection`, на каждое изменение читает `connection.status`, маппит в `VpnStatusMessage`, зовёт `VpnEventListener.shared.emit(StatusChangedMessage(...))`. Для `.connected` берёт `connection.connectedDate` → `connectedSinceEpochMs`.
**When to use:** статусы туннеля (включая системные reasserting/revoke) должны доходить до Flutter без polling.
**Trade-offs:** notification может прийти не с main thread — emit уже оборачивает в `DispatchQueue.main.async` (безопасно). Наблюдателя надо снять в deinit/cancel.

### Anti-Patterns to Avoid
- **Логика туннеля в Runner-таргете** (ARCHITECTURE Anti-Pattern 6): iOS исполняет туннель ТОЛЬКО в NE-процессе. Runner лишь управляет профилем.
- **startVPNTunnel сразу после saveToPreferences без reload:** гонка конфигурации → `configurationStale`/`configurationInvalid`. Всегда `loadFromPreferences` между save и start.
- **Синхронный вызов `eventSink.success` из notification-колбэка:** notification может прийти с фонового потока → падение. Только через `VpnEventListener.emit` (main queue).
- **Bundle id `com.example.vpn_oko` для extension/App Group:** реальный id — `vpnOko`. Рассинхрон → provisioning не соберётся.
- **Добавление PacketTunnel в Podfile:** extension не использует pods; добавление в Podfile тянет Flutter-фреймворки в extension и ломает embed. Оставить extension вне Podfile.
- **NSExtensionPointIdentifier `…packet-tunnel-provider`:** правильное значение — `com.apple.networkextension.packet-tunnel` (без `-provider`). Ошибочная строка встречается в задании — не копировать.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Добавить NE-таргет в pbxproj | Ручная вставка ~8 типов объектов с самодельными UUID | Ruby-гем `xcodeproj` 1.27.0 (есть с CocoaPods) | Валидирует граф, генерирует UUID, ставит embed+dependency корректно; ручная правка target — источник «target not found»/битого проекта |
| Подъём туннеля / сетевые настройки | Свой сокет/TUN-парсер | `NEPacketTunnelProvider` + `NEPacketTunnelNetworkSettings` | iOS не даёт другого API; свой код в приложении не запустит туннель вовсе |
| Управление VPN-профилем | Прямое редактирование системного VPN-конфига | `NETunnelProviderManager` (load/save/load/start) | Единственный санкционированный путь; профиль появляется в Settings автоматически |
| Статусы туннеля | Polling `getStatus()` таймером | `NEVPNStatusDidChange` observer | Push из системы, ловит revoke/reasserting, точный `connectedDate` |
| Обмен app↔extension | Свой IPC/файл в общем tmp | App Group `UserDefaults(suiteName:)` / `providerConfiguration` | Единственный разрешённый сэндбоксом канал между процессами |
| Линковка NetworkExtension | Явный `-framework` флаг | `import NetworkExtension` (Swift автолинк) | Runner имеет пустую Frameworks-фазу; Swift-модуль автолинкует системный фреймворк |

**Key insight:** на iOS весь VPN-стек — это готовые системные объекты. Единственная «ручная» работа — правильно сшить target-граф Xcode и entitlements; и её тоже отдать `xcodeproj`-гему, а не текстовому редактору.

## Common Pitfalls

### Pitfall 1: Network Extension не исполняется в Simulator
**What goes wrong:** попытка проверить реальный туннель на симуляторе; `saveToPreferences`/`startVPNTunnel` возвращают ошибку, `startTunnel` extension никогда не вызывается.
**Why it happens:** NE-провайдеры на симуляторе не поднимаются в принципе (нет системного демона VPN).
**How to avoid:** цель автогейта — **компиляция** обоих таргетов + Swift-мост эмитит статусы/логи. Реальный туннель → device/TestFlight (checkpoint). На симуляторе путь ошибки менеджера эмитит `ErrorMessage` + `LogMessage("Network Extension недоступен в симуляторе")` — это и есть «статусы/логи из Swift-слоя» для IOS-01 (см. Open Q1).
**Warning signs:** `NEVPNError` domain, code 1 (`configurationInvalid`) при первом же `saveToPreferences` на симуляторе.
[CITED: existing PITFALLS.md P11 + Apple Developer Forums thread 690345]

### Pitfall 2: bundle id `vpnOko` vs `vpn_oko`
**What goes wrong:** extension bundle id / App Group / entitlements объявлены от `com.example.vpn_oko`, а Runner реально `com.example.vpnOko` → provisioning не матчится, TestFlight-архив падает; App Group не совпадает у двух таргетов → shared-контейнер пуст.
**Why it happens:** Android applicationId = `com.example.vpn_oko`, но Flutter конвертирует `_` в camelCase для iOS; задание указывает старую строку.
**How to avoid:** extension = `com.example.vpnOko.PacketTunnel`; App Group = `group.com.example.vpnOko`; сверить с реальным `PRODUCT_BUNDLE_IDENTIFIER` в pbxproj перед написанием entitlements.
**Warning signs:** «Provisioning profile doesn't match bundle identifier»; extension bundle id не префиксован app bundle id.
[VERIFIED: codebase grep pbxproj]

### Pitfall 3: startVPNTunnel сразу после save → configurationStale
**What goes wrong:** `saveToPreferences { manager.connection.startVPNTunnel() }` бросает `NEVPNError.configurationStale`/`configurationInvalid`.
**Why it happens:** после save системный кэш профиля устаревает; connection ссылается на старую конфигурацию.
**How to avoid:** флоу save → `loadFromPreferences` (reload того же менеджера) → `try connection.startVPNTunnel()`. Ловить `try` в do/catch, ошибку → `ErrorMessage`.
**Warning signs:** старт бросает сразу после первого save; со второго раза «работает» (кэш прогрелся).
[CITED: Apple Developer Forums / широко известная готча NEVPNManager]

### Pitfall 4: entitlement Packet Tunnel только у одного таргета
**What goes wrong:** `com.apple.developer.networking.networkextension` = `[packet-tunnel-provider]` прописан только у app или только у extension → на устройстве permission error, extension не грузится.
**Why it happens:** легко забыть второй `.entitlements`.
**How to avoid:** ОБА `.entitlements` (Runner + PacketTunnel) содержат и NE-entitlement, и `com.apple.security.application-groups = [group.com.example.vpnOko]`. Wire `CODE_SIGN_ENTITLEMENTS` в build-конфиги обоих таргетов.
**Warning signs:** «Extension … failed to load»; App Group UserDefaults возвращает nil.
[CITED: Apple docs packet-tunnel-provider + PITFALLS.md P11]

### Pitfall 5: NEVPNStatus.reasserting/invalid не смаплены
**What goes wrong:** UI застревает или прыгает при системных переходах (reasserting при смене сети, invalid при удалении профиля).
**Why it happens:** маппят только 4 «очевидных» статуса.
**How to avoid:** полный маппинг: `.disconnected→disconnected`, `.connecting→connecting`, `.connected→connected`, `.disconnecting→disconnecting`, `.reasserting→connecting` (честно: переустановка), `.invalid→error` (или disconnected + лог). `getStatus()` при `.invalid`/`nil` → disconnected-снапшот.
**Warning signs:** статус «зависает» при переключении Wi-Fi/LTE.
[ASSUMED: training, `NEVPNStatus` enum стабилен с iOS 8]

### Pitfall 6: TestFlight требует portal-регистрации App ID + capabilities
**What goes wrong:** `flutter build ipa`/archive падает подписью: App ID не имеет capability Network Extensions / App Groups; нет distribution-профилей для обоих таргетов.
**Why it happens:** entitlement самообслуживаемый в Xcode (self-serve с 2016), но App ID и профили всё равно надо создать в portal для двух bundle id.
**How to avoid:** зарегистрировать App ID `com.example.vpnOko` и `com.example.vpnOko.PacketTunnel` с Network Extensions + App Groups; включить App Group `group.com.example.vpnOko`; создать distribution provisioning profiles. Это `checkpoint:human-verify` + README DOC-02. Симуляторная/`--no-codesign` компиляция это НЕ требует.
**Warning signs:** «No profiles for 'com.example.vpnOko.PacketTunnel' were found»; capability отсутствует в Identifiers.
[CITED: STACK.md iOS entitlement self-serve + web search Flutter app extension provisioning]

### Pitfall 7: Стейл VPN-профили в Settings при разработке
**What goes wrong:** повторные `saveToPreferences` с разными `localizedDescription` плодят несколько «Oko VPN» профилей в Settings → General → VPN; старый профиль может конфликтовать.
**Why it happens:** каждый новый `NETunnelProviderManager()` без reuse существующего создаёт новый профиль.
**How to avoid:** `loadAllFromPreferences` → переиспользовать первый существующий менеджер, а не всегда создавать новый; один стабильный `localizedDescription`. При отладке чистить профиль через `removeFromPreferences` или переустановку app.
**Warning signs:** несколько одинаковых VPN-строк в Settings; «Multiple configurations».
[ASSUMED: training, стандартная готча NETunnelProviderManager]

### Pitfall 8: Swift 6 strict concurrency ломает completion-handler мост
**What goes wrong:** на Xcode 26 / Swift 6.3 при language mode 6 completion-handler колбэки NE и notification-обсёрверы дают Sendable/isolation-ошибки компиляции.
**Why it happens:** strict concurrency включён в Swift 6 language mode.
**How to avoid:** держать `SWIFT_VERSION = 5.0` (как Runner) и у нового extension-таргета — language mode 5 отключает strict concurrency; код компилируется как раньше. Не поднимать до 6.0 в этой фазе.
**Warning signs:** «Sending 'self' risks causing data races»; «Capture of non-Sendable».
[ASSUMED: training по поведению Swift 6 language mode; проект уже на 5.0 — риск снят выбором]

## Code Examples

Модерн-Swift именование NE (свойства lowerCamel: `ipv4Settings`, `dnsSettings`, `mtu`; в старом SimpleTunnel — `IPv4Settings`/`DNSSettings`, это Swift 2).

### Пример 1: PacketTunnel/Info.plist (NSExtension)
```xml
<!-- Source: developer.apple.com/documentation/networkextension/packet-tunnel-provider [CITED] -->
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.networkextension.packet-tunnel</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).PacketTunnelProvider</string>
</dict>
```

### Пример 2: entitlements (одинаковы у Runner и PacketTunnel)
```xml
<!-- Source: Apple packet-tunnel-provider docs + App Groups [CITED/ASSUMED] -->
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>packet-tunnel-provider</string>
</array>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.example.vpnOko</string>
</array>
```

### Пример 3: PacketTunnelProvider.swift (skeleton, узкий маршрут)
```swift
// Source: сверено с Apple SimpleTunnel PacketTunnelProvider (модерн-именование) [CITED]
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
  override func startTunnel(options: [String: NSObject]?,
                            completionHandler: @escaping (Error?) -> Void) {
    let proto = protocolConfiguration as? NETunnelProviderProtocol
    let server = proto?.serverAddress ?? "10.0.0.1"

    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: server)
    let ipv4 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.255"])
    ipv4.includedRoutes = [NEIPv4Route(destinationAddress: "10.111.222.0",
                                       subnetMask: "255.255.255.0")]
    settings.ipv4Settings = ipv4
    settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1"])
    settings.mtu = 1500

    setTunnelNetworkSettings(settings) { error in
      completionHandler(error)
      // опц.: self.readPackets() — read-and-drop + счётчики (паритет с Android)
    }
  }

  override func stopTunnel(with reason: NEProviderStopReason,
                           completionHandler: @escaping () -> Void) {
    completionHandler()
  }
}
```

### Пример 4: VpnHostApiImpl.startVpn — реальный менеджер (save→RELOAD→start)
```swift
// Source: NETunnelProviderManager флоу [CITED Apple docs + Pitfall 3]
func startVpn(config: VpnConfigMessage,
              completion: @escaping (Result<Void, Error>) -> Void) {
  NETunnelProviderManager.loadAllFromPreferences { managers, error in
    if let error = error { self.fail(error); completion(.success(())); return }
    let manager = managers?.first ?? NETunnelProviderManager()

    let proto = NETunnelProviderProtocol()
    proto.providerBundleIdentifier = "com.example.vpnOko.PacketTunnel"
    proto.serverAddress = config.host
    proto.providerConfiguration = ["host": config.host, "port": config.port]
    manager.protocolConfiguration = proto
    manager.localizedDescription = "Oko VPN"
    manager.isEnabled = true

    manager.saveToPreferences { error in
      if let error = error { self.fail(error); completion(.success(())); return }
      manager.loadFromPreferences { error in          // RELOAD обязателен
        if let error = error { self.fail(error); completion(.success(())); return }
        do {
          self.observer.attach(manager.connection)     // Пример 5
          try manager.connection.startVPNTunnel()
          completion(.success(()))
        } catch { self.fail(error); completion(.success(())) }
      }
    }
  }
}

private func fail(_ error: Error) {
  listener.emit(ErrorMessage(code: "ne_error", message: "\(error.localizedDescription)"))
  listener.emit(StatusChangedMessage(status: .error))
}
```

### Пример 5: NEVPNStatus observer → Pigeon event (IOS-03)
```swift
// Source: NEVPNStatusDidChange + connection.status/connectedDate [ASSUMED training, стабильно]
import NetworkExtension

final class VpnStatusObserver {
  private let listener: VpnEventListener
  private var token: NSObjectProtocol?
  init(listener: VpnEventListener = .shared) { self.listener = listener }

  func attach(_ connection: NEVPNConnection) {
    token = NotificationCenter.default.addObserver(
      forName: .NEVPNStatusDidChange, object: connection, queue: nil) { [weak self] _ in
        self?.report(connection)
    }
    report(connection)
  }

  private func report(_ connection: NEVPNConnection) {
    switch connection.status {
    case .connected:
      let since = connection.connectedDate.map { Int64($0.timeIntervalSince1970 * 1000) }
      listener.emit(StatusChangedMessage(status: .connected, connectedSinceEpochMs: since))
    case .connecting, .reasserting:
      listener.emit(StatusChangedMessage(status: .connecting))
    case .disconnecting:
      listener.emit(StatusChangedMessage(status: .disconnecting))
    case .disconnected:
      listener.emit(StatusChangedMessage(status: .disconnected))
    case .invalid:
      listener.emit(StatusChangedMessage(status: .error))
    @unknown default:
      listener.emit(StatusChangedMessage(status: .disconnected))
    }
  }

  deinit { if let token = token { NotificationCenter.default.removeObserver(token) } }
}
```

### Пример 6: Ruby-скрипт добавления NE-таргета (эскиз)
```ruby
# Source: xcodeproj gem 1.27.0 API [VERIFIED: gem установлен локально]
require 'xcodeproj'
project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner  = project.targets.find { |t| t.name == 'Runner' }

ext = project.new_target(:app_extension, 'PacketTunnel', :ios, '13.0')
ext.build_configurations.each do |c|
  c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.vpnOko.PacketTunnel'
  c.build_settings['INFOPLIST_FILE']            = 'PacketTunnel/Info.plist'
  c.build_settings['CODE_SIGN_ENTITLEMENTS']    = 'PacketTunnel/PacketTunnel.entitlements'
  c.build_settings['SWIFT_VERSION']             = '5.0'
  c.build_settings['DEVELOPMENT_TEAM']          = 'Z2GDTXHVZZ'
end
# + добавить PacketTunnelProvider.swift в ext.source_build_phase
# + runner.add_dependency(ext)
# + «Embed App Extensions» copy phase (dstSubfolderSpec = 13, .appex, RemoveHeadersOnCopy)
# + wire Runner.entitlements в runner build configs
project.save
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Ручная правка pbxproj для нового target | Ruby-гем `xcodeproj` / xcodegen | давно | Надёжный headless-флоу; для 3 файлов ручная правка ещё ок, для target — нет |
| `NEPacketTunnelNetworkSettings.IPv4Settings`/`.DNSSettings` (Swift 2, SimpleTunnel) | `.ipv4Settings`/`.dnsSettings` lowerCamel | Swift 3+ | Копипаст из SimpleTunnel требует переименования свойств |
| completion-handler NETunnelProviderManager | async/await варианты (`… async throws`) | iOS 15/16 | Наш deployment 13.0 → остаёмся на completion handlers |
| Entitlement «требует одобрения Apple» (допущение PROJECT.md) | Self-serve packet-tunnel entitlement с ноября 2016 | 2016 | Одобрение не нужно; реальные барьеры — платный аккаунт (есть) + устройство + симулятор не исполняет NE |

**Deprecated/outdated:**
- `com.apple.networkextension.packet-tunnel-provider` как NSExtensionPointIdentifier — **неверная строка** (в задании). Корректно: `com.apple.networkextension.packet-tunnel`.
- Echo `VpnHostApiImpl` фазы 1 (синтетическая цепочка статусов) — заменяется реальным менеджером; echo можно оставить как fallback для симулятора (Open Q1).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `NEVPNStatus` enum и `.NEVPNStatusDidChange` неизменны, `connection.connectedDate` даёт uptime | Pattern 3 / Example 5 | Низкий — API стабилен с iOS 8; проверяется компиляцией на SDK 26.4 |
| A2 | completion-handler `loadAllFromPreferences`/`saveToPreferences`/`loadFromPreferences` доступны на deployment 13.0 | Example 4 | Низкий — базовые API iOS 9; async-варианты (iOS 15/16) сознательно не используются |
| A3 | На симуляторе `saveToPreferences` возвращает `NEVPNError` (а не крашит) → путь ошибки эмитит статус/лог | Open Q1 / Pitfall 1 | Средний — если крашит, нужен явный `#if targetEnvironment(simulator)` echo-ветвление для IOS-01 |
| A4 | `dstSubfolderSpec = 13` = PlugIns для embed .appex; productType `com.apple.product-type.app-extension` | Pattern 1 / Example 6 | Низкий — гем `xcodeproj` через `new_target(:app_extension)` ставит это сам; ручные числа не пишем |
| A5 | `flutter build ios --no-codesign` компилирует embedded extension как зависимость Runner | Validation | Средний — семантика PBXTargetDependency; если нет, использовать явный `xcodebuild -sdk iphonesimulator build` (компилирует dependency) |
| A6 | App Group `group.com.example.vpnOko` не требует portal-регистрации для симулятор/`--no-codesign` компиляции | Pitfall 6 | Низкий — entitlements не энфорсятся на симуляторе/без подписи; portal нужен для device/TestFlight |
| A7 | Swift language mode 5 (SWIFT_VERSION 5.0) снимает strict-concurrency ошибки на Xcode 26 | Pitfall 8 | Низкий — проект уже на 5.0; extension ставим тоже 5.0 |
| A8 | `providerConfiguration` dict читается extension из `protocolConfiguration` без App Group | Example 3/4 | Низкий — штатное поле профиля; App Group нужен независимо (IOS-04) |

## Open Questions

1. **Источник живых статусов в Swift-слое на СИМУЛЯТОРЕ (IOS-01).**
   - Что знаем: NE на симуляторе не исполняется; `saveToPreferences`/`startVPNTunnel` вернут `NEVPNError`. Реальные статусы `connected` возможны только на устройстве.
   - Что неясно: демо на симуляторе (IOS-01 «статусы/логи из Swift-слоя») — показывать (а) реальный путь ошибки менеджера (`connecting → error` + лог «NE недоступен в симуляторе»), либо (б) сохранить echo-цепочку под `#if targetEnvironment(simulator)` для полного набора статусов connecting→connected→disconnected.
   - Рекомендация: **вариант (а)** — честнее и доказывает, что мост реально дёргает `NETunnelProviderManager` (Swift-слой живой). Полный happy-path connected показывается на устройстве/TestFlight. Решить в discuss-phase; это единственный открытый выбор поведения. (STATE.md Blockers: «источник живых статусов в Swift-слое при туннеле без core решить при планировании фазы».)

2. **Глубина read-loop в extension (счётчики трафика на iOS).**
   - Что знаем: Android read-loop реально считает rx из TUN (AND-05); iOS `packetFlow.readPackets` может делать то же (read-and-drop).
   - Что неясно: нужен ли `trafficChanged` на iOS для демо, или достаточно статусов (IOS-02/03 не требуют трафика явно).
   - Рекомендация: skeleton `startTunnel` без read-loop достаточно для IOS-02 (туннель поднимается). Read-and-drop счётчики — опциональная полировка (паритет с Android), не блокер. Extension-side счётчики доходят до Flutter только через App Group (extension → app → pigeon), что усложняет; отложить.

3. **Portal-регистрация App ID/capabilities — кто выполняет.**
   - Что знаем: TestFlight требует ручной portal-настройки (Pitfall 6); это вне headless-автоматизации.
   - Что неясно: делает ли это пользователь до device-прогона.
   - Рекомендация: `checkpoint:human-verify` перед device/TestFlight; шаги задокументировать в README DOC-02. Автогейт фазы (компиляция) не блокируется.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode + iOS SDK | Компиляция обоих таргетов, archive | ✓ | 26.4.1 / SDK 26.4 | — |
| Swift toolchain | Extension + мост | ✓ | 6.3.1 (lang mode 5) | — |
| Flutter / Dart | `flutter build ios --no-codesign` | ✓ | 3.44.5 / 3.12.2 | — |
| CocoaPods | Pods для Runner | ✓ | 1.16.2 | — |
| Ruby `xcodeproj` gem | Программное добавление NE-таргета | ✓ | 1.27.0 | Ручная правка pbxproj (хуже) |
| iOS Simulator | Компиляция + Swift-мост демо | ✓ | iOS 26.4 booted | — |
| Apple Developer team | Подпись, TestFlight | ✓ | team `Z2GDTXHVZZ` в pbxproj | — |
| Физическое iOS-устройство | Реальный старт туннеля (IOS-02 на device) | ✗ (не в среде агента) | — | TestFlight-прогон пользователем (checkpoint) |
| Portal App IDs + NE/App Group capabilities | TestFlight-архив с подписью | ✗ (не настроено) | — | Ручная регистрация (Pitfall 6, README DOC-02) |

**Missing dependencies with no fallback:** нет — компиляция и Swift-мост полностью доступны локально.
**Missing dependencies with fallback:** физическое устройство и portal-capabilities закрываются device/TestFlight-прогоном пользователя (`checkpoint:human-verify`); на автогейт фазы (компиляция) не влияют.

## Validation Architecture

> `workflow.nyquist_validation = true` (config.json) — секция включена. NE-специфика: реальный туннель не автоматизируется (симулятор его не исполняет), поэтому «полный набор» тестов — это компиляция обоих таргетов + существующие Dart-тесты моста; device/TestFlight — manual-only.

### Test Framework
| Property | Value |
|----------|-------|
| Framework (Dart) | flutter_test (SDK) + mocktail 1.0.5 — уже в проекте |
| Config file | `analysis_options.yaml` (very_good_analysis) |
| Quick run command | `flutter analyze && flutter test` |
| Full suite command | `flutter test && xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -sdk iphonesimulator -configuration Debug build` |
| Swift NE unit tests | НЕТ (нет XCTest-инфры для NE; верификация Swift = компиляция + device) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| IOS-01 | Swift-мост компилируется, статусы/логи из Swift-слоя в симуляторе | compile + manual-sim | `xcodebuild … -sdk iphonesimulator build` + запуск в симуляторе | ✅ (Runner target) |
| IOS-01 | Dart data-слой маппит NE-статусы/ошибки в domain | unit | `flutter test` (мапперы событий, mocktail) | ✅ / ❌ Wave 0 (если нет теста маппера NE-ошибки) |
| IOS-02 | Оба таргета (Runner + PacketTunnel) компилируются | compile | `flutter build ios --no-codesign --debug` и `xcodebuild -sdk iphonesimulator build` | ❌ Wave 0 (target ещё не создан) |
| IOS-02 | Реальный startTunnel/setTunnelNetworkSettings | manual-only (device) | TestFlight-прогон | ❌ device checkpoint |
| IOS-03 | NEVPNStatus observer доводит статус до Flutter | manual-only (device) | TestFlight; на симуляторе — путь ошибки | ❌ device checkpoint |
| IOS-04 | entitlements/App Groups присутствуют, компиляция проходит | compile + grep | `grep packet-tunnel-provider ios/**/*.entitlements` + build | ❌ Wave 0 |
| IOS-04 | Готовность к TestFlight (archive/signing) | manual-only | ручной archive + upload | ❌ device checkpoint |

### Sampling Rate
- **Per task commit:** `flutter analyze && flutter test` (Dart) — быстрый гейт.
- **Per wave merge (iOS-таргеты затронуты):** `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -sdk iphonesimulator -configuration Debug build` — компиляция обоих таргетов.
- **Phase gate:** `flutter build ios --no-codesign --debug` зелёный (Runner + embedded PacketTunnel) + Swift-мост запускается в симуляторе (статусы/логи видны) ДО `/gsd:verify-work`. Реальный туннель — отдельный device/TestFlight checkpoint (не блокирует автогейт).

### Wave 0 Gaps
- [ ] `ios/PacketTunnel/` target ещё не существует — создать (Pattern 1, Ruby `xcodeproj`).
- [ ] `ios/Runner/Runner.entitlements` + `ios/PacketTunnel/PacketTunnel.entitlements` — создать (Code Example 2).
- [ ] Dart-тест маппинга NE-`ErrorMessage`/статусов в domain — проверить, покрыт ли существующим маппером событий; добавить кейс, если нет.
- [ ] Grep-гейт корректных строк: `com.apple.networkextension.packet-tunnel` (без `-provider`), `com.example.vpnOko.PacketTunnel`, `group.com.example.vpnOko`.
- [ ] Skeleton `PacketTunnelProvider.swift` компилируется под iphonesimulator (проверка автогейта).

*Существующая инфра Dart-тестов (flutter_test + mocktail) и pigeon-контракт готовы; Swift NE-код верифицируется компиляцией, не юнитами.*

## Security Domain

> `security_enforcement` в config.json не задан (absent = enabled). Включаю в применимом объёме — VPN-приложение, но без реального core/трафика.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Нет учёток/логина в скоупе фазы |
| V3 Session Management | no | Нет сессий приложения |
| V4 Access Control | yes | Entitlement `com.apple.developer.networking.networkextension` ограничивает, кто поднимает туннель; App Group изолирует shared-контейнер двумя bundle id |
| V5 Input Validation | yes | `config.host`/`port` из Dart валидируются в domain (VLESS-парсер фазы 4); extension не доверяет `providerConfiguration` слепо |
| V6 Cryptography | no | Реальный VPN-крипто вне скоупа (нет core); туннель — skeleton |
| V7 Error Handling / Logging | yes | NE-ошибки → typed `ErrorMessage`, не сырые строки платформы в UI (CONVENTIONS) |

### Known Threat Patterns for iOS NetworkExtension
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Логирование VLESS-URI с UUID-кредами в App Group/логи extension | Information Disclosure | Маскировать UUID (уже правило фазы 4 / PITFALLS security); в extension не логировать `providerConfiguration` целиком |
| Чужой app читает shared-контейнер | Information Disclosure | App Group доступен только таргетам с тем же group entitlement; не класть креды в shared UserDefaults открытым текстом |
| Стейл/подменный VPN-профиль в Settings | Tampering | Переиспользовать существующий менеджер (`loadAllFromPreferences`), стабильный `localizedDescription`; чистить лишние профили |
| Extension грузится без валидной подписи/entitlement | Spoofing / Elevation | Подпись обоих таргетов правильными профилями; entitlement у обоих (Pitfall 4) |

## Sources

### Primary (HIGH confidence)
- Локальный codebase — `ios/Runner.xcodeproj/project.pbxproj` (bundle id `com.example.vpnOko`, team, deployment 13.0, Swift 5.0, objectVersion 54, синтетические ID моста), `ios/Runner/Bridge/*.swift` (echo мост, VpnEventListener), `ios/Runner/Info.plist`, `ios/Podfile`, `.planning/phases/01-01/01-06-SUMMARY` (символы pigeon), CONVENTIONS.md — [VERIFIED]
- Локальный тулинг — `xcodebuild -version` (Xcode 26.4.1), `flutter --version` (3.44.5), `swift --version` (6.3.1), `pod --version` (1.16.2), `ruby -e require 'xcodeproj'` (1.27.0), `xcrun simctl` (iOS 26.4) — [VERIFIED]
- Apple Developer — NEPacketTunnelProvider / packet-tunnel-provider (NSExtensionPointIdentifier `com.apple.networkextension.packet-tunnel`, entitlement `com.apple.developer.networking.networkextension` = `[packet-tunnel-provider]`) — подтверждено через web search Apple docs snippet — [CITED]
- Apple SimpleTunnel `PacketTunnel/PacketTunnelProvider.swift` (NEPacketTunnelNetworkSettings/NEIPv4Settings/NEDNSSettings/NEIPv4Route, setTunnelNetworkSettings, packetFlow) — [CITED: raw.githubusercontent.com/ios-sample-code/SimpleTunnel]

### Secondary (MEDIUM confidence)
- `.planning/research/{STACK,ARCHITECTURE,PITFALLS}.md` — iOS entitlement self-serve, App Groups, симулятор не исполняет NE, app↔extension разделение — [существующий research проекта]
- kean.blog «VPN, Part 2: Packet Tunnel Provider» — структура startTunnel, providerConfiguration, packetFlow — [частично прочитано, MEDIUM]
- WebFetch NETunnelProviderManager/NEPacketTunnelProvider — сигнатуры (модель дала training-ответ, Apple doc-страницы JS-рендер не читаются) — сверено с образцами — [MEDIUM]

### Tertiary (LOW confidence — помечено ASSUMED)
- `NEVPNStatus`/`NEVPNStatusDidChange`/`connectedDate` детали, `dstSubfolderSpec=13`, Swift-6-concurrency поведение — training knowledge, стабильные API; проверяются компиляцией на SDK 26.4 — [ASSUMED]

## Metadata

**Confidence breakdown:**
- Среда/структура проекта: HIGH — всё проверено по коду и локальным тулзам.
- Строки конфигурации NE (Info.plist, entitlements, bundle id): HIGH — сверены с Apple docs snippet и реальным pbxproj; критичная поправка `vpnOko` подтверждена grep.
- NE API surface (NEPacketTunnelProvider/NETunnelProviderManager/NetworkSettings): HIGH — сверено с SimpleTunnel + стабильный iOS 9-API; async-варианты сознательно не используются.
- Маппинг статусов и мелкие свойства (`connectedDate`, reasserting): MEDIUM — training, проверяется компиляцией.
- pbxproj-механика через `xcodeproj`-гем: MEDIUM-HIGH — гем установлен и валиден, конкретный скрипт — эскиз (планнер детализирует).

**Research date:** 2026-07-14
**Valid until:** ~2026-08-14 (30 дней — NetworkExtension API стабилен; Xcode/Flutter могут бампнуться, но deployment 13.0/completion-handler путь устойчив)
