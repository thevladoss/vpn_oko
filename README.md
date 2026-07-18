# osin — нативный VPN на Flutter (Android + iOS)

[![CI](https://github.com/thevladoss/osin/actions/workflows/ci.yml/badge.svg)](https://github.com/thevladoss/osin/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

osin гонит весь трафик (`0.0.0.0/0` и `::/0`) через ваш прокси-сервер на обеих
платформах. Туннель поднимает ядро **sing-box** (`libbox`, v1.13.14): на Android
внутри `VpnService`, на iOS внутри Network Extension. Flutter общается с ядром
через типобезопасный мост Pigeon. Проверено на устройствах — трафик идёт,
заблокированные ресурсы открываются.

Поддержаны VLESS (Reality / XTLS / ws / grpc), VMess, Trojan, Shadowsocks,
Hysteria2. Парсер ссылок и генератор sing-box JSON написаны на Dart и покрыты
тестами.

## Возможности

| Возможность | Как работает |
|-------------|--------------|
| Реальный туннель на Android и iOS | `libbox` берёт TUN-fd от системы и проксирует весь трафик; rx/tx приходят из статистики ядра |
| Подписки | Вставьте subscription-URL из буфера — серверы импортируются скопом (base64 / список ссылок), группируются, обновляются; карточка показывает остаток трафика и срок |
| Автопереключение | Тумблер строит группу `urltest`: ядро само держит лучший сервер по задержке и бесшовно уходит с упавшего, туннель не рвётся |
| Мультипротокол | Один парсер на `vless://` / `vmess://` / `trojan://` / `ss://` / `hysteria2://`; VLESS покрывает Reality, XTLS-flow, ws и grpc |
| Управление серверами | Добавление вставкой из буфера, зашифрованное хранилище, список, переключение активного, удаление |
| Генерация конфига | Чистая Dart-функция `ProxyConfig → sing-box JSON`, отдельные тесты на каждый протокол и транспорт |

## Стек

| Компонент | Версия | Роль |
|-----------|--------|------|
| Flutter / Dart | 3.44.5 / 3.12.2 | UI + host-приложение |
| **sing-box** | v1.13.14 (`libbox`) | Ядро VPN: outbound-протоколы, tun-inbound, роутинг, urltest |
| `pigeon` | `^27.1.1` | Кодоген типобезопасного моста Flutter ↔ Kotlin/Swift |
| `flutter_bloc` | `^9.1.1` | State management, event-driven машина состояний |
| `drift` + `sqlite3_flutter_libs` | `^2.34.2` | Реактивное SQL-хранилище (SQLite3MultipleCiphers) |
| `flutter_secure_storage` | `^10.3.1` | Ключ шифрования БД в Keychain / EncryptedSharedPreferences |
| `http` | `^1.6.0` | Загрузка подписок |
| `google_fonts` | `^8.1.0` | Inter / JetBrainsMono / SpaceGrotesk (офлайн-бандл) |
| `very_good_analysis`, `mocktail`, `bloc_test`, `drift_dev` | dev | Линтинг, моки, тесты, кодоген схемы |

Ядро sing-box и весь Flutter-стек взяты готовыми, версии зафиксированы.

## Сборка

### 1. Dart-слой: анализ и тесты (без ядра)

Весь Dart-слой (парсер, генератор конфига, мапперы, Bloc/Cubit, виджеты)
собирается и тестируется без `libbox`. Тот же набор гоняет CI:

```bash
flutter pub get
flutter analyze
flutter test
```

Регенерация Pigeon — при правке контракта `pigeons/vpn_api.dart`:

```bash
dart run pigeon --input pigeons/vpn_api.dart
```

Схема Drift пересобирается при правке таблиц:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 2. Ядро libbox

Бинарь ядра в git не хранится (88 МБ .aar / 270 МБ .xcframework — не место в
репозитории). Соберите его из исходников sing-box один раз.

Тулчейн: **Go 1.25.0** (go.mod sing-box требует ровно её), форк
**github.com/sagernet/gomobile v0.1.12** (не upstream), **JDK 17** для Android,
Xcode 16+ для iOS.

```bash
go install golang.org/dl/go1.25.0@latest && go1.25.0 download
export PATH="$HOME/sdk/go1.25.0/bin:$PATH" GOTOOLCHAIN=local GOFLAGS=-mod=mod
go install github.com/sagernet/gomobile/cmd/gomobile@v0.1.12
go install github.com/sagernet/gomobile/cmd/gobind@v0.1.12

git clone --depth 1 --branch v1.13.14 https://github.com/SagerNet/sing-box.git
cd sing-box && go mod download && go mod tidy

# Android → libbox.aar
go run ./cmd/internal/build_libbox -target android
# iOS → Libbox.xcframework
go run ./cmd/internal/build_libbox -target apple
```

Положите артефакты:

- Android: `android/app/libs/libbox.aar` (подключается как `implementation(files(...))`)
- iOS: `ios/Frameworks/Libbox.xcframework` (линкуется скриптом ниже)

Готовые сборки libbox также публикуют [singbox-android/libbox](https://github.com/singbox-android/libbox)
и подобные проекты — можно взять оттуда вместо самостоятельной сборки.

### 3. Android

```bash
flutter run
```

VPN-диалог согласия и живой Connect → трафик → Disconnect работают на устройстве
или эмуляторе API 26+.

### 4. iOS

Линковка xcframework в оба таргета — одноразово:

```bash
ruby scripts/add_libbox_to_targets.rb
```

Затем откройте воркспейс, выберите свою команду в Signing & Capabilities
(нужны capability **Network Extensions → Packet Tunnel** и **App Group** на обоих
таргетах), запускайте на устройстве:

```bash
open ios/Runner.xcworkspace
```

Network Extension исполняется только на физическом устройстве — симулятор его не
запускает.

## Структура проекта

```
lib/
├── app/                      composition root (di.dart), MaterialApp (app.dart)
├── core/
│   ├── bridge/               Pigeon vpn_api.g.dart + VpnBridge (демультиплексор)
│   ├── error/                Failure-типы
│   └── theme/                темы, токены, типографика, VpnStatus
└── features/
    ├── vpn_connection/       мост, экран, ирис, автопереключение (domain/data/presentation)
    └── server_config/        парсер, генератор конфига, подписки, хранилище, карточки
pigeons/vpn_api.dart          контракт моста (источник кодогена)
android/app/src/main/kotlin/  VpnService, libbox-интеграция, event bus, host api
android/app/libs/libbox.aar   ядро sing-box (соберите сами, см. выше — не в git)
ios/Runner/ + ios/PacketTunnel/  Swift-мост + NE-таргет с ядром
ios/Frameworks/Libbox.xcframework  ядро sing-box (соберите сами — не в git)
test/                         автотесты: парсер, генератор, подписки, миграции, Bloc, виджеты
.github/workflows/ci.yml      CI: flutter analyze + flutter test
```

## Архитектура

Feature-first clean architecture. Presentation зависит только от domain, data
реализует доменные интерфейсы, весь обмен с native идёт через один Pigeon-мост.
Ключевой поток: ссылка `vless://` (или подписка) парсится в `ProxyConfig`,
`toSingboxJson` собирает конфиг ядра на Dart, строка уходит через `startVpn` в
нативный сервис, `libbox` берёт TUN-fd и проксирует трафик. Пунктирные стрелки —
обратный поток событий (`StatusChanged`, `TrafficChanged`, `Error`).

```mermaid
flowchart TD
  UI["Presentation: VpnHomeScreen + widgets<br/>(iris, server card, subscriptions)"] -->|user intent| BLOC["Bloc/Cubit: VpnConnectionBloc,<br/>ServerListCubit, SubscriptionCubit, AutoSwitchCubit"]
  BLOC -->|calls| UC["Usecases: ConnectVpn, ResolveActiveVpnConfig,<br/>AddSubscription, RefreshSubscription, WatchTraffic"]
  UC -->|domain interfaces| REPO["Repositories: VpnRepository,<br/>ServerRepository, SubscriptionRepository, SettingsRepository"]
  REPO -->|active server / group| GEN["Dart: parseProxyUrl -> ProxyConfig<br/>-> toSingboxJson / toAutoSwitchJson"]
  GEN --> BR["VpnBridge<br/>(single owner of Pigeon stream)"]
  REPO -->|encrypted CRUD| DB["Drift + SQLite3MultipleCiphers<br/>(key in secure storage)"]
  BR -->|VpnHostApi startVpn(singboxConfigJson)| PG["Pigeon generated<br/>Dart Kotlin Swift"]
  PG -.->|EventChannelApi vpnEvents| BR
  PG --> ANDROID["Android: VpnHostApiImpl<br/>-> OsinVpnService"]
  PG --> IOS["iOS: VpnHostApiImpl<br/>-> NETunnelProviderManager"]
  ANDROID --> CORE["libbox core (sing-box)<br/>newCommandServer -> startOrReloadService"]
  CORE --> TUN["OsinPlatformInterface.openTun<br/>-> establish() -> TUN fd -> proxy 0.0.0.0/0"]
  IOS --> NE["PacketTunnelProvider<br/>libbox + setTunnelNetworkSettings"]
  CORE -.->|CommandClient status: rx/tx| PG
  ANDROID -.->|StatusChanged / Error| PG
  NE -.->|NEVPNStatus observer| IOS
  IOS -.->|events| PG
```

Маппинг слоёв на файлы:

| Слой | Файлы | Роль |
|------|-------|------|
| presentation | `lib/features/*/presentation/` | Виджеты + Bloc/Cubit; ирис-индикатор `iris_painter.dart`, шит серверов, подписки, тумблер автопереключения |
| domain | `lib/features/*/domain/` | sealed/immutable entity, usecases, интерфейсы репозиториев, парсеры и генератор конфига |
| data | `lib/features/*/data/` | Реализации репозиториев, мапперы DTO → entity, Drift-хранилище, HTTP-загрузка подписок, датасорсы поверх `VpnBridge` |
| core/bridge | `lib/core/bridge/` | `vpn_api.g.dart` (Pigeon) + `VpnBridge`, единственный подписчик event-канала |
| Android native | `android/.../vpn/`, `android/.../bridge/` | `OsinVpnService`, `OsinPlatformInterface`, `VpnEventBus`, `VpnHostApiImpl` |
| iOS native | `ios/Runner/Bridge/`, `ios/PacketTunnel/` | `VpnHostApiImpl`, `VpnStatusObserver`, `PacketTunnelProvider` + `OsinPlatformInterface` |

## Лицензия

[MIT](LICENSE).
