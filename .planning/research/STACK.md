# Stack Research

**Domain:** Flutter-приложение с глубокой нативной интеграцией (Android VpnService, iOS Network Extension, Pigeon bridge)
**Researched:** 2026-07-13
**Confidence:** HIGH (версии проверены по pub.dev, официальным докам Flutter/Android/Apple)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Flutter | 3.44 (stable) | UI + host-приложение | Текущий stable (docs.flutter.dev, май 2026). Dart 3: sealed classes и pattern matching закрывают модель VpnState без кодогена. Confidence: HIGH |
| pigeon | ^27.1.1 | Типобезопасный мост Flutter↔native | Официальный кодоген от команды Flutter, версия 27.1.1 опубликована в июле 2026. `@HostApi` для startVpn/stopVpn/getStatus, `@EventChannelApi` для потоков событий. Единый контракт в одном .dart-файле, генерирует Kotlin + Swift + Dart. Confidence: HIGH |
| flutter_bloc | ^9.1.1 | State management | **Решение пользователя (override research):** бизнес-логика на Bloc. `Bloc<VpnEvent, VpnUiState>` подписывается на Pigeon-стрим репозитория, UI через `BlocBuilder`/`BlocListener`. Riverpod (исходная рекомендация research) перенесён в Alternatives. Confidence: HIGH |
| Kotlin | 2.x (из шаблона Flutter 3.44) | Android: VpnService, Foreground Service | Требование ТЗ. Шаблон Flutter 3.44 генерирует Kotlin DSL + AGP 8.x, ничего менять не нужно. Confidence: MEDIUM (точную версию шаблона не проверял, для прототипа некритично) |
| Swift | 5.x / Xcode 16+ | iOS: PacketTunnelProvider skeleton | Требование ТЗ. `NEPacketTunnelProvider` + `NETunnelProviderManager` — единственный API для VPN-туннелей на iOS, стабилен годами. Confidence: HIGH |

### Android-параметры (не пакеты, но решения уровня стека)

| Параметр | Значение | Rationale |
|----------|----------|-----------|
| compileSdk / targetSdk | 36 | Google Play с 31.08.2026 требует API 36 для новых приложений. Проект сдаётся прямо на границе дедлайна, таргетироваться ниже нет смысла. Confidence: HIGH |
| minSdk | 26 | Flutter поднял дефолт до 24 (issue flutter/flutter#170807 закрыт). Подъём до 26 убирает все ветвления: `NotificationChannel` и `startForegroundService` обязательны с API 26, код foreground-сервиса пишется в одну ветку. Требование пользователя «без комментариев» + чистый код выигрывают от отсутствия `Build.VERSION` проверок. Confidence: HIGH |
| foregroundServiceType | `systemExempted` | Официальные доки Android явно перечисляют «VPN apps (configured using Settings > Network & Internet > VPN)» в критериях eligibility для `FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED`. Требуется permission `FOREGROUND_SERVICE_SYSTEM_EXEMPTED`. Confidence: HIGH |
| Permissions | `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SYSTEM_EXEMPTED`, `POST_NOTIFICATIONS` (runtime, API 33+) | POST_NOTIFICATIONS запрашивается в рантайме на Android 13+, иначе уведомление foreground-сервиса молча не показывается. Сервис объявляется с `android:permission="android.permission.BIND_VPN_SERVICE"` и intent-filter `android.net.VpnService`. Confidence: HIGH |

### iOS-параметры

| Параметр | Значение | Rationale |
|----------|----------|-----------|
| Entitlement | Network Extensions → Packet Tunnel | Self-serve с ноября 2016: capability включается прямо в Xcode (Signing & Capabilities) или на developer.apple.com, спецодобрение Apple не нужно. Реальные ограничения другие: платный аккаунт Apple Developer и физическое устройство (Simulator Network Extension не исполняет). Это уточняет допущение PROJECT.md «entitlement требует одобрения Apple» — одобрение не нужно, skeleton-подход всё равно оправдан из-за платного аккаунта и устройства. Confidence: HIGH (Apple Developer Forums + kean.blog + доки Apple) |
| App Groups | Обязательны для app ↔ extension | Единственный канал обмена данными между контейнером и PacketTunnelProvider (общий UserDefaults / файлы). В README описать, в skeleton заложить. Confidence: HIGH |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| equatable | ^2.0 | Value equality для VlessConfig/VpnConfig | Тесты парсера сравнивают конфиги целиком; equatable даёт `==`/`hashCode` без кодогена. Confidence: MEDIUM (патч-версию не проверял) |
| mocktail | ^1.0.5 | Моки в unit-тестах | Без кодогена и build_runner, в отличие от mockito. Мокать Pigeon HostApi в тестах репозитория. Версия 1.0.5 актуальна. Confidence: HIGH |
| flutter_test | SDK | Unit/widget тесты | Входит в SDK. Приоритет тестов: VLESS-парсер (чистый Dart, быстрые тесты), маппинг статусов, Notifier-логика. Confidence: HIGH |
| very_good_analysis | ^10.3.0 | Линтинг | Строже flutter_lints, сигнал качества для ревьюера тестового задания. Обязательный override: `public_member_api_docs: false` — правило включено в VGA 10.3.0 и конфликтует с требованием «без комментариев в коде». Confidence: HIGH (проверено по analysis_options.10.3.0.yaml) |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| pigeon CLI | Генерация моста | `dart run pigeon --input pigeons/vpn_api.dart`. Один входной файл, выходы: `lib/.../vpn_api.g.dart`, `android/.../VpnApi.g.kt`, `ios/.../VpnApi.g.swift`. Запуск разовый, build_runner не нужен |
| Xcode 16+ | Компиляция iOS skeleton | Network Extension target добавляется через File → New → Target → Network Extension → Packet Tunnel |
| adb + `flutter run` | Проверка VpnService | VPN-диалог согласия (`VpnService.prepare`) показывается только на устройстве/эмуляторе, юнит-тестами не покрывается |

## Мост Pigeon: события native → Flutter

Решение: `@EventChannelApi` с sealed-иерархией событий. Проверено по официальному README pigeon (июль 2026):

- Event channels поддержаны в генераторах Swift, Kotlin и Dart — ровно наши платформы.
- Метод объявляется без `Stream<>`: `VpnEvent streamVpnEvents();` внутри `abstract class` с аннотацией `@EventChannelApi`. Dart-сторона получает готовый `Stream<VpnEvent>`.
- Наследование от пустого `sealed`-родителя разрешено в тех же трёх генераторах: `sealed class VpnEvent` + подклассы `StatusChanged`, `LogMessage`, `TrafficChanged`, `VpnError`. Один стрим, типизированный `switch` по событиям на Dart-стороне.
- На Kotlin-стороне pigeon генерирует StreamHandler-класс с sink; события отправляются с main thread (требование platform channels — в VpnService слать через `Handler(Looper.getMainLooper())`). Confidence: MEDIUM для деталей генерации, HIGH для самой поддержки фичи.

Почему не `@FlutterApi` callbacks: FlutterApi требует держать ссылку на Dart-API из нативного кода и вызывать методы поштучно, без семантики подписки/отписки. EventChannelApi даёт lifecycle onListen/onCancel из коробки, что совпадает с моделью «UI подписался на статусы — UI ушёл — поток закрылся». FlutterApi оставить для случаев запрос-ответ, инициированных нативом (здесь таких нет).

## Installation

```bash
# Runtime
flutter pub add flutter_bloc equatable

# Dev
flutter pub add --dev pigeon mocktail very_good_analysis

# Генерация моста (после описания pigeons/vpn_api.dart)
dart run pigeon --input pigeons/vpn_api.dart
```

`analysis_options.yaml`:

```yaml
include: package:very_good_analysis/analysis_options.yaml
linter:
  rules:
    public_member_api_docs: false
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| flutter_bloc 9.1.1 (выбран пользователем) | flutter_riverpod 3.3.2 | Research изначально рекомендовал Riverpod за меньший бойлерплейт, но пользователь явно выбрал Bloc: явная event-driven машина состояний хорошо читается ревьюером тестового задания. VPN-статусы ложатся на `Bloc`/`Cubit` без потерь |
| Ручные провайдеры | riverpod_generator 4.0.4 + riverpod_annotation 4.0.3 | Кодоген оправдан на проектах с десятками провайдеров. Здесь провайдеров 3-5; build_runner watch ради них — лишний процесс в 48-часовом окне |
| Dart 3 sealed classes + equatable | freezed 3.2.5 + freezed_annotation 3.1.0 | freezed стоит брать, если нужен `copyWith` на многих моделях и есть привычка к его workflow. Для двух-трёх моделей sealed class + equatable закрывают равенство и pattern matching без build_runner. Итог: единственный кодоген в проекте — pigeon, это чистая история для README |
| `@EventChannelApi` | Сырые EventChannel + StreamHandler вручную | Только если pigeon упрётся в баг генерации. Ручной канал теряет типобезопасность — главный аргумент выбора pigeon в ТЗ |
| minSdk 26 | minSdk 24 (дефолт Flutter) | Если нужен охват старых устройств. Для прототипа охват не критерий, чистота кода — критерий |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| json_serializable 6.14.0 | В скоупе нет JSON: VLESS-ссылка — это URI (`vless://uuid@host:port?params#name`), парсится через `Uri.parse` + валидация. Тянуть build_runner ради нуля JSON-моделей | Ручной парсер поверх `Uri` с юнит-тестами |
| foregroundServiceType `specialUse` | Требует декларацию в Play Console и `PROPERTY_SPECIAL_USE_FGS_SUBTYPE`; предназначен для кейсов, не покрытых другими типами. VPN покрыт явно | `systemExempted` (VPN apps перечислены в eligibility официальных доков) |
| Сырые MethodChannel/EventChannel | Ручная сериализация Map<String, Object?>, ошибки типов в рантайме. ТЗ допускает, но pigeon прямо назван современным вариантом | pigeon 27.x |
| mockito | Требует `@GenerateMocks` + build_runner | mocktail 1.0.5 |
| Плагины-обёртки VPN с pub.dev (flutter_vpn и подобные) | ТЗ проверяет умение писать нативный слой самому; готовый плагин обнуляет смысл задания | Собственный VpnService + PacketTunnelProvider через pigeon |
| provider (пакет) | Легаси-подход, Riverpod 3 — его прямой преемник от того же автора | flutter_riverpod 3.3.2 |

## Stack Patterns by Variant

**Если ревьюер попросит показать Bloc-компетенцию:**
- Замена точечная: `Cubit<VpnState>` подписывается на тот же Pigeon-стрим, UI переходит на `BlocBuilder`
- Архитектура data/domain слоёв не меняется — мост и репозиторий не зависят от state management

**Если появится время на реальный VPN-core (вне 48ч):**
- Android: sing-box/libXray как .aar, вызывается из VpnService, fd от `establish()` передаётся в core
- iOS: тот же core как xcframework внутри PacketTunnelProvider
- Мост менять не придётся: контракт startVpn(config)/события уже покрывает интеграцию — аргумент для README

**Если тестовое устройство только эмулятор:**
- Android Emulator корректно поднимает VpnService (ключ в диалоге согласия) — демо-видео снимается на эмуляторе
- iOS Simulator Network Extension не запускает — skeleton проверяется только компиляцией, это и есть план

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| pigeon 27.1.1 | Flutter 3.44 / Dart 3.x | Sealed-классы событий требуют генераторов Swift/Kotlin/Dart — все три в скоупе |
| flutter_riverpod 3.3.2 | Dart 3.x | Riverpod 3 включает `ProviderContainer` overrides для тестов, доппакеты не нужны |
| very_good_analysis 10.3.0 | Текущий Dart 3.x | Включает `public_member_api_docs` — отключить в analysis_options |
| targetSdk 36 | minSdk 26, AGP 8.x | FGS type обязателен при targetSdk 34+; `systemExempted` работает и на 35/36 |
| mocktail 1.0.5 | flutter_test (SDK) | Кодоген не нужен |

## Sources

- [pub.dev/packages/pigeon](https://pub.dev/packages/pigeon) — версия 27.1.1, поддержка @EventChannelApi (HIGH)
- [Официальный README pigeon (flutter/packages)](https://raw.githubusercontent.com/flutter/packages/main/packages/pigeon/README.md) — event channels на Swift/Kotlin/Dart, sealed-иерархии событий, @FlutterApi (HIGH)
- [pub.dev/packages/flutter_riverpod](https://pub.dev/packages/flutter_riverpod) — 3.3.2 (HIGH); [riverpod_generator](https://pub.dev/packages/riverpod_generator) — 4.0.4 + riverpod_annotation 4.0.3 (HIGH)
- [pub.dev/packages/freezed](https://pub.dev/packages/freezed) — 3.2.5 + freezed_annotation 3.1.0 (HIGH); [json_serializable](https://pub.dev/packages/json_serializable) — 6.14.0 (HIGH)
- [pub.dev/packages/mocktail](https://pub.dev/packages/mocktail) — 1.0.5 (HIGH); [flutter_bloc](https://pub.dev/packages/flutter_bloc) — 9.1.1 (HIGH)
- [pub.dev/packages/very_good_analysis](https://pub.dev/packages/very_good_analysis) — 10.3.0 (HIGH); [analysis_options.10.3.0.yaml](https://raw.githubusercontent.com/VeryGoodOpenSource/very_good_analysis/main/lib/analysis_options.10.3.0.yaml) — public_member_api_docs включён (HIGH); [flutter_lints](https://pub.dev/packages/flutter_lints) — 6.0.0 (HIGH)
- [docs.flutter.dev/install/archive](https://docs.flutter.dev/install/archive) — Flutter 3.44 stable (HIGH)
- [developer.android.com — Foreground service types](https://developer.android.com/develop/background-work/services/fg-service-types) — VPN apps в eligibility systemExempted (HIGH)
- [developer.android.com — Target API requirements](https://developer.android.com/google/play/requirements/target-sdk) + [Play Console Help](https://support.google.com/googleplay/android-developer/answer/11926878) — API 36 для новых приложений с 31.08.2026 (HIGH)
- [flutter/flutter#170807](https://github.com/flutter/flutter/issues/170807) — minSdk 21→24 закрыт/смержен (MEDIUM: релиз с дефолтом 24 не зафиксирован)
- [Apple Developer Forums thread 67613](https://developer.apple.com/forums/thread/67613) + [kean.blog VPN series](https://kean.blog/post/vpn-configuration-manager) — packet-tunnel entitlement self-serve с 2016, Simulator не поддержан (HIGH)
- [NEPacketTunnelProvider](https://developer.apple.com/documentation/networkextension/nepackettunnelprovider), [Network Extension docs](https://developer.apple.com/documentation/networkextension) — API skeleton (HIGH)

---
*Stack research for: Flutter Native VPN Prototype (Oko VPN)*
*Researched: 2026-07-13*
