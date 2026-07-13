# Walking Skeleton — Oko VPN

**Phase:** 1
**Generated:** 2026-07-13

## Capability Proven End-to-End

Разработчик запускает приложение, нажимает echo-Connect в debug-harness и видит события `StatusChanged` и `LogMessage`, пришедшие из Kotlin- и Swift-слоя в единый Dart-стрим через типобезопасный pigeon-мост, без единого импорта `*.g.dart` в виджете.

Этот срез прогоняет весь вертикальный стек фазы: контракт → кодоген трёх языков → нативный эмиттер → event channel → демультиплексор → мапперы → репозиторий с replay → usecase → harness. Реального VpnService и Network Extension здесь нет: события синтетические, но путь доставки настоящий.

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Мост Flutter ↔ native | pigeon 27.1.1: `@HostApi VpnHostApi` + `@EventChannelApi VpnEventsApi` поверх `sealed VpnEventMessage` | Единственный источник истины контракта; генерирует Dart+Kotlin+Swift; sealed-события дают exhaustive switch. Решение зафиксировано в PROJECT.md |
| Контракт | один входной файл `pigeons/vpn_api.dart`, выходы только `kotlinOut`+`swiftOut`+`dartOut` | Несколько input-файлов ломают event channels (flutter/flutter#161291); javaOut/objcOut валят генерацию |
| Доменные модели | Dart 3 sealed classes + equatable, immutable | Единственный кодоген в проекте — pigeon; freezed/json_serializable запрещены (CONVENTIONS.md) |
| State management | Bloc (`flutter_bloc`), подключается в Phase 3 | Прямое решение пользователя. В Phase 1 Bloc отсутствует, есть минимальный debug-harness |
| Источник истины по статусу | native (кэш последнего статуса) + Dart-replay в репозитории | Двойная защита от гонки «событие раньше подписки» (BRG-04) |
| Изоляция кодогена | импорт `vpn_api.g.dart` только в `core/bridge/` и `features/*/data/`; мапперы DTO→entity | Домен переживает смену версии pigeon, тестируется без платформы (BRG-03) |
| Доставка событий | только с main thread платформы через централизованный эмиттер | `Handler(Looper.getMainLooper())` / `DispatchQueue.main`; иначе crash `@UiThread` |
| iOS-регистрация | `didInitializeImplicitFlutterEngine` + `engineBridge.applicationRegistrar.messenger()` | Шаблон Flutter 3.44 SceneDelegate; путь через `rootViewController` даёт `MissingPluginException` (#185935) |
| Композиция | ручной composition root `app/di.dart` (класс `AppDependencies`) | 3-5 зависимостей; get_it/injectable избыточны и не в стеке |
| Directory layout | feature-first clean architecture: `lib/features/<feature>/{domain,data,presentation}`, общее в `lib/core/`, `lib/app/` | Требование пользователя (CONVENTIONS.md) |

## Stack Touched in Phase 1

- [x] Project scaffold — pubspec deps (flutter_bloc, equatable, pigeon, mocktail, very_good_analysis), `analysis_options.yaml` на VGA, тест-раннер flutter_test
- [x] «Routing» этого домена — pigeon-контракт + `VpnBridge` (единственная точка контакта с генерированным кодом)
- [x] «Запись» — нативный эмиттер шлёт синтетическую цепочку событий с main thread; «чтение» — Dart-стрим с demux, мапперами и replay последнего статуса; снапшот через `getStatus()`
- [x] UI — минимальный debug-harness, вызывающий echo-Connect через usecase и рисующий стрим `VpnState`/`LogEntry`
- [x] Запуск — `flutter run` на Android-эмуляторе (live echo) плюс компиляция iOS Runner; команда прогона зафиксирована в верификации фазы

## Out of Scope (Deferred to Later Slices)

- Реальный `OkoVpnService`, `VpnService.Builder.establish()`, foreground-сервис, `onRevoke`, read-loop трафика — Phase 2
- Network Extension таргет, `PacketTunnelProvider`, entitlements, App Groups, TestFlight — Phase 5
- UI по DESIGN.md, Bloc-машина состояний, ирис-индикатор, панель логов, таймер — Phase 3
- VLESS-парсер, расширение `VpnConfigMessage` под sni/type/security, tcping — Phase 4
- SDK-бампы (minSdk 26 / targetSdk 36), VPN-permissions (`BIND_VPN_SERVICE`, `FOREGROUND_SERVICE_*`, `POST_NOTIFICATIONS`) — Phase 2
- README, mermaid-диаграмма, CI, видео-демо — Phase 6

## Subsequent Slice Plan

Каждая следующая фаза кладёт один вертикальный срез поверх этого скелета, не трогая архитектурные решения выше:

- Phase 2: Android VpnService — реальный туннель через consent-флоу, foreground-сервис, живые события статусов/логов/трафика
- Phase 3: Flutter UI — экран по DESIGN.md на Bloc, восстановление состояния через `getStatus()`
- Phase 4: VLESS-конфиг — парсер `vless://`, карточка сервера, tcping; `VpnConfigMessage` расширяется полями
- Phase 5: iOS Network Extension — Swift-реализация туннеля в extension-таргете, `NETunnelProviderManager`, TestFlight
- Phase 6: Подача — README, CI GitHub Actions, видео-демо
