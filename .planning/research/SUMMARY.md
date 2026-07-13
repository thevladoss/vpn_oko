# Project Research Summary

**Project:** Oko VPN (Flutter Native VPN Prototype)
**Domain:** Flutter-приложение с глубокой нативной интеграцией (Android VpnService, iOS Network Extension, Pigeon bridge); тестовое задание на 48 часов
**Researched:** 2026-07-13
**Confidence:** HIGH

## Executive Summary

Проект относится к категории «прототип VPN-клиента без реального ядра»: ревьюер за 10-15 минут смотрит видео, README и код, поэтому ценность решения определяют живой Android VpnService, чистый типобезопасный мост и честная документация. Скоуп table stakes задан ТЗ дословно, спорных продуктовых вопросов нет. Экспертный подход в этом домене: один Pigeon-контракт как единственный источник истины моста, нативный сервис как источник истины по статусу VPN, Flutter-слой только отображает состояния.

Рекомендованный стек: Flutter 3.44 + pigeon 27.1.1 (`@HostApi` + `@EventChannelApi` с sealed-иерархией событий), flutter_riverpod 3.3.2, sealed classes Dart 3 + equatable вместо freezed, mocktail вместо mockito, very_good_analysis. Единственный кодоген в проекте — pigeon; build_runner не нужен. Android: minSdk 26, targetSdk 36, foregroundServiceType `systemExempted`. iOS: Packet Tunnel entitlement выдаётся self-serve, но требует платный аккаунт и физическое устройство, поэтому skeleton-подход из ТЗ остаётся правильным; при этом Swift-реализация Pigeon-моста делается рабочей.

Главные риски: `addRoute("0.0.0.0", 0)` без ядра убивает интернет на демо (решение по маршруту фиксируется до кода сервиса), события в Flutter с фонового потока роняют приложение (централизованный main-thread эмиттер), гонка «сервис шлёт события до подписки Dart» ломает восстановление UI (снапшот `getStatus()` + replay-буфер), Android 14 крашит сервис без `foregroundServiceType`. Все четыре закрываются архитектурными решениями на ранних фазах, а не отладкой в конце.

## Key Findings

### Recommended Stack

Стек минималистичный: pigeon как единственный кодоген, Riverpod 3 с ручными провайдерами (3-5 штук, генератор избыточен), sealed classes вместо freezed, ручной VLESS-парсер поверх `Uri.parse` вместо json_serializable. Готовые VPN-плагины с pub.dev исключены: ТЗ проверяет умение писать нативный слой самостоятельно. Подробности и версии: `STACK.md`.

**Core technologies:**
- Flutter 3.44 + Dart 3: sealed classes и pattern matching закрывают модель VpnState без кодогена
- pigeon ^27.1.1: типобезопасный мост, `@EventChannelApi` с sealed-событиями поддержан ровно в нужных генераторах (Dart/Kotlin/Swift)
- flutter_riverpod ^3.3.2: `Notifier` + `StreamProvider` оборачивают Pigeon-стримы, тестируется через `ProviderContainer`
- Kotlin 2.x / Swift 5.x: нативные слои по требованию ТЗ
- Android: minSdk 26 (одна ветка кода foreground-сервиса), targetSdk 36, `systemExempted` + permissions `FOREGROUND_SERVICE_SYSTEM_EXEMPTED`, `POST_NOTIFICATIONS`
- Dev: mocktail, very_good_analysis (с override `public_member_api_docs: false`)

### Expected Features

«Пользователь» здесь — проверяющий тестового задания. Table stakes определяет ТЗ; дифференциаторы дают эффект на видео за малую цену; анти-фичи сжигают 48 часов без прибавки к оценке. Подробности: `FEATURES.md`.

**Must have (table stakes, все P1):**
- Экран 5 статусов + Connect/Disconnect с блокировкой в переходных состояниях
- Pigeon-мост: `startVpn`/`stopVpn`/`getStatus` + события `statusChanged`/`logMessage`/`trafficChanged`/`error`
- Android VpnService: `prepare()` consent, Builder → `establish()`, Foreground Service с уведомлением, `onRevoke`
- Живые логи, сервер, таймер подключения, статистика трафика в UI
- VLESS-парсер (`vless://` → `VlessConfig`) с тестами
- iOS: рабочий Swift Pigeon-мост + компилируемый skeleton `PacketTunnelProvider` + доки (entitlements, App Groups)
- README (запуск, архитектура, план интеграции core) + видео 1-3 минуты

**Should have (дифференциаторы, в порядке цена/эффект):**
- Реальный TUN read-loop с подсчётом байтов: трафик из настоящих пакетов вместо мока
- Анимированный статус-индикатор: первое, что видно на видео
- Вставка `vless://` из буфера + карточка конфига, TCP ping сервера, уровни логов с копированием
- Восстановление UI через `getStatus()` при старте/resume
- CI (analyze + test) + mermaid-диаграмма в README

**Defer (v2+, только текст в README):**
- Интеграция sing-box/xray core, рабочий iOS-туннель, форвардинг пакетов (tun2socks)
- Списки серверов, kill switch, split tunneling, автопереподключение, persist настроек

### Architecture Approach

Clean-слои во Flutter (presentation → domain → data) с тремя фичами: `vpn_connection`, `vpn_logs`, `server_config`. Pigeon-контракт в `pigeons/vpn_api.dart` с DTO-суффиксом `Message`; домен генерированный код не импортирует. Один event channel на все события, `VpnBridge` подписывается на него ровно один раз и демультиплексирует в broadcast-стримы. Источник истины по статусу — нативный сервис: `getStatus()` при старте/resume плюс replay-буфер (`MutableSharedFlow(replay=64)`) на Kotlin-стороне закрывают hot restart и гонки подписки. Подробности: `ARCHITECTURE.md`.

**Major components:**
1. Pigeon-контракт (`pigeons/vpn_api.dart`): единственный источник истины моста
2. `VpnBridge` (`core/bridge/`): единственная точка контакта с генерированным кодом, демультиплексор событий
3. `OkoVpnService` (Kotlin): state machine, `Builder.establish()`, foreground-уведомление, `onRevoke`; в одном процессе с Flutter
4. `VpnEventBus` (Kotlin): SharedFlow-транспорт сервис → activity, доставка в sink строго на main thread
5. `VpnHostApiImpl` + `PacketTunnelProvider` (Swift): управление профилем в контейнере, skeleton туннеля в extension-таргете с App Group

### Critical Pitfalls

Топ-5 из 13 (полный список с фазами: `PITFALLS.md`):

1. **`addRoute("0.0.0.0", 0)` без ядра убивает интернет устройства.** Решение до кода сервиса: узкая тестовая подсеть (интернет жив, значок ключа есть) либо полный перехват с read-and-drop и живым подсчётом байтов; выбор влияет на источник `trafficChanged` и описывается в README.
2. **События с фонового потока роняют приложение (`@UiThread` crash).** `onRevoke()` приходит не с main thread. Единый эмиттер: `Handler(Looper.getMainLooper()).post`/`DispatchQueue.main.async`, прямые вызовы sink из сервиса запрещены.
3. **Гонка «сервис шлёт события до подписки Dart».** Hot restart воспроизводит рассинхрон каждый раз. Снапшот в `getStatus()` (статус + `connectedSince` + трафик), вызов при старте/resume, replay в `onListen`.
4. **Android 14: `startForeground()` без `foregroundServiceType` крашит сервис.** `systemExempted` (VPN-приложения явно в eligibility) + permission в манифесте; `startForeground()` первой строкой `onStartCommand()` с уведомлением «Connecting…». Проверка на эмуляторе API 34/35.
5. **Consent-флоу `prepare()` и `onRevoke` не обработаны.** `prepare()` перед каждым стартом; `RESULT_CANCELED` → Error, никогда не оставлять Connecting без выхода. `onRevoke` → полный teardown (close fd → join потока, `stopForeground`, событие Disconnected), переиспользуемый из `stopVpn()` и `onDestroy()`.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Pigeon-контракт и фундамент
**Rationale:** Все слои по обе стороны моста зависят от генерированных типов; контракт — фундамент проекта. Domain-слой — чистый Dart, фиксирует границы до нативного кода.
**Delivers:** Скелет проекта (lint, структура), `pigeons/vpn_api.dart` (3 метода, 4 события sealed-иерархией), кодоген Kotlin+Swift+Dart, echo-реализации на обеих платформах, domain-слой трёх фич (entities, интерфейсы репозиториев, use cases), main-thread эмиттер событий.
**Addresses:** Мост Pigeon, модели `VpnConfig`/`VpnState` (table stakes).
**Avoids:** P12 (генераторы event channel только Kotlin/Swift/Dart, один input-файл), P3 (эмиттер проектируется вместе с мостом), P4 (контракт `getStatus()` со снапшотом: статус + `connectedSince` + трафик).

### Phase 2: Android VpnService
**Rationale:** Главный критерий «сильного решения» из ТЗ и самый рискованный интеграционный шов; закрывается раньше UI-полировки, проверяется руками через логи до готового экрана. 10 из 13 pitfalls живут здесь.
**Delivers:** `OkoVpnService` со state machine, consent-флоу (`prepare()` каждый раз, обработка отказа), Builder → `establish()`, TUN read-loop с подсчётом байтов, foreground-уведомление (`systemExempted`, POST_NOTIFICATIONS), `onRevoke` + единый teardown, `VpnEventBus` с replay.
**Uses:** Kotlin, minSdk 26 / targetSdk 36 из STACK.md.
**Avoids:** P1, P2 (решение по маршруту фиксируется в начале фазы), P5, P6, P7, P8, P9 (сервис в основном процессе), P10.

### Phase 3: Flutter data-слой и UI
**Rationale:** Соединяет домен с мостом; UI стартует на fake-репозитории параллельно фазе 2 и финалится на реальном сервисе.
**Delivers:** `VpnBridge` (одна подписка + демультиплексор), datasources, mappers, repository impl с кэшем статуса, контроллеры, экран: статус-индикатор 5 состояний, кнопки с блокировкой, лог-консоль (ring buffer ~500 строк), таймер от `connectedSince`, панель трафика; `getStatus()` при старте и resume.
**Uses:** flutter_riverpod, sealed `VpnState`.
**Avoids:** P4 (восстановление после hot restart), P13 (таймер от native `connectedSince`, не от Dart-стейта), анти-паттерны «статус живёт во Flutter» и «несколько подписок на генерированный стрим».

### Phase 4: VLESS-парсер и конфиг сервера
**Rationale:** Чистый Dart без платформенных зависимостей; технически параллелится с фазами 2-3, дешёвый и обязательный «плюс» из ТЗ. Разблокирует дифференциаторы (вставка из буфера, ping).
**Delivers:** `VlessConfig`, парсер поверх `Uri.parse` с URL-decode, юнит-тесты (IPv6-хост, percent-encoding, невалидный UUID, отсутствующие параметры), отображение сервера в UI, маскирование UUID в логах.

### Phase 5: iOS: Swift-мост и PacketTunnel skeleton
**Rationale:** Последняя платформенная фаза, чтобы не блокировать Android-демо. По PROJECT.md Pigeon-мост на iOS работает полноценно (события идут из Swift-слоя), туннель остаётся skeleton.
**Delivers:** Swift-реализация `VpnHostApi` + StreamHandler с живыми событиями, extension-таргет `PacketTunnelProvider` (`startTunnel`/`stopTunnel` с `NEPacketTunnelNetworkSettings`), entitlements обоих таргетов, App Group, компиляция extension (`xcodebuild build` зелёный), extension не ломает `flutter run`.
**Avoids:** P11 (симулятор не исполняет NE, подпись extension, entitlements у обоих таргетов), анти-паттерн «логика туннеля в контейнере».

### Phase 6: Подача: README, дифференциаторы, видео
**Rationale:** Формат сдачи; полировка после того, как всё P1 зелёное. Дифференциаторы добавляются в порядке цена/эффект из FEATURES.md, каждый независим и отбрасываем.
**Delivers:** README (запуск, mermaid-архитектура, iOS-доки, план интеграции core с точками подключения, честные ограничения), видео 1-3 минуты; по остатку времени: анимированный индикатор, вставка из буфера, ping, копирование логов, CI.

### Phase Ordering Rationale

- Контракт моста первым: генерированные типы нужны и Dart-, и Kotlin-, и Swift-стороне; менять контракт после реализации сервисов дорого.
- Android раньше Flutter-UI: самый рискованный шов (мост + сервис + системные ограничения Android 14) получает максимум календарного времени; UI на fake-репозитории идёт параллельно.
- VLESS-парсер и domain-слой параллелятся с чем угодно: чистый Dart.
- iOS после Android: ТЗ допускает skeleton, Android-демо важнее; extension не должен сломать сборку в разгар работы над Android.
- Подача последней: видео снимается один раз на готовом UI.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 5 (iOS):** добавление Network Extension таргета в Flutter-проект (взаимодействие с Xcode-конфигурацией Flutter, подпись, embed extension в debug-сборке) описано в источниках MEDIUM-уровня; сценарий «живые события из Swift при skeleton-туннеле» требует решения, откуда Swift-слой берёт статусы (см. Gaps).

Phases with standard patterns (skip research-phase):
- **Phase 1:** официальный пример pigeon покрывает `@EventChannelApi` + sealed события дословно.
- **Phase 2:** VpnService, foreground types, consent — официальные доки Android + 10 pitfalls с verification-критериями уже в PITFALLS.md.
- **Phase 3, 4, 6:** стандартные Flutter-паттерны (Riverpod, `Uri.parse`, README).

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Версии проверены по pub.dev и официальным докам Flutter/Android/Apple; MEDIUM только по точной версии Kotlin в шаблоне Flutter 3.44 |
| Features | HIGH | Table stakes продиктованы ТЗ дословно; MEDIUM по дифференциаторам (анализ экосистемы v2rayNG/Hiddify) |
| Architecture | HIGH | Pigeon-паттерны из официального примера flutter/packages; iOS app↔extension из Apple docs; MEDIUM по деталям systemExempted |
| Pitfalls | HIGH | Android/Flutter/Pigeon подтверждены официальной документацией; iOS NE: Apple docs + community |

**Overall confidence:** HIGH

### Gaps to Address

- **Выбор маршрута для прототипа (узкая подсеть vs 0.0.0.0/0 + read-and-drop):** зафиксировать в начале фазы 2 до кода сервиса; влияет на источник `trafficChanged` и текст README. Рекомендация исследования: read-and-drop с честным подсчётом байтов как дифференциатор, узкая подсеть как запасной вариант для демо.
- **iOS: источник событий при skeleton-туннеле:** без entitlement `saveToPreferences` на устройстве вернёт permission error, значит `NEVPNStatusDidChange` живых статусов не даст. Swift-слою понадобится собственная демо-state-machine, эмитящая статусы/логи в Pigeon-стрим. Решить при планировании фазы 5.
- **Детали генерации Kotlin StreamHandler в pigeon 27.x (MEDIUM):** проверить на echo-мосте в фазе 1; при проблемах откат на `@FlutterApi` коллбеки (то же требование main thread).
- **Точные версии Kotlin/AGP шаблона Flutter 3.44 (MEDIUM):** проверить при scaffold в фазе 1, для прототипа некритично.

## Sources

### Primary (HIGH confidence)
- pub.dev: pigeon 27.1.1, flutter_riverpod 3.3.2, mocktail 1.0.5, very_good_analysis 10.3.0 — версии и возможности
- Официальный README/example pigeon (flutter/packages) — `@EventChannelApi`, sealed-события, генераторы Dart/Kotlin/Swift
- developer.android.com — VpnService (prepare/establish/onRevoke), Foreground service types (`systemExempted` для VPN), target API 36 c 31.08.2026
- docs.flutter.dev — platform channels: main thread для вызовов в сторону Dart; Flutter 3.44 stable
- developer.apple.com — NEPacketTunnelProvider, NETunnelProviderManager, TN3120; entitlement packet-tunnel у обоих таргетов

### Secondary (MEDIUM confidence)
- kean.blog (VPN series) — структура app/extension, App Groups, entitlement self-serve
- Apple Developer Forums — NE не работает в симуляторе; flutter/flutter#161291, #34993 — ограничения EventChannelApi и main-thread крэши
- Экосистема v2rayNG/Hiddify — UI-паттерны категории (tcping, трафик, статус-карточка)

### Tertiary (LOW confidence)
- flutter_vpn_service, VPNclient-engine-flutter — ориентир по разделению платформенных слоёв, требует критического чтения

---
*Research completed: 2026-07-13*
*Ready for roadmap: yes*
