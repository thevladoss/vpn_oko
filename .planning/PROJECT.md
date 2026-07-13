# Oko VPN — Flutter Native VPN Prototype

## What This Is

Прототип VPN-приложения на Flutter с нативной интеграцией Android/iOS. Выполняется по тестовому заданию «Flutter-разработчик: Native VPN Prototype» (срок 48 часов, сдача: GitHub + README + видео-демо). Приложение поднимает реальный Android VpnService через типобезопасный мост Flutter↔native, показывает живые статусы, логи и трафик из нативного слоя; на iOS мост работает полноценно, Network Extension таргет с PacketTunnelProvider проверяется через TestFlight.

## Core Value

Реально работающий Android VpnService с живым потоком статусов и логов из native во Flutter через чистый типобезопасный мост — это главный критерий «сильного решения» в ТЗ.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Экран с пятью статусами VPN: Disconnected, Connecting, Connected, Disconnecting, Error
- [ ] Кнопки Connect / Disconnect с корректной блокировкой в переходных состояниях
- [ ] Живой блок логов и ошибок (события из native в реальном времени)
- [ ] Отображение выбранного сервера и таймера времени подключения
- [ ] Отображение статистики трафика (события trafficChanged)
- [ ] Мост Pigeon: методы startVpn(config), stopVpn(), getStatus()
- [ ] События из native: statusChanged, logMessage, trafficChanged, error
- [ ] Android VpnService c VpnService.Builder: addAddress, addRoute, addDnsServer, establish
- [ ] Android Foreground Service с уведомлением и корректным lifecycle
- [ ] Корректная остановка VPN и обработка onRevoke
- [ ] iOS: Swift-реализация Pigeon-моста в основном приложении — startVpn/stopVpn/getStatus и поток событий (statusChanged, logMessage, trafficChanged, error) реально работают, приложение запускается на iOS и показывает статусы/логи из Swift-слоя
- [ ] iOS: реальный Network Extension таргет с PacketTunnelProvider — start/stop туннеля через NETunnelProviderManager, статусы из extension в приложение; проверка на устройстве через TestFlight (аккаунт Apple Developer есть)
- [ ] iOS: README-раздел про capabilities, entitlements, App Groups, взаимодействие app ↔ extension
- [ ] Парсинг VLESS-ссылки (vless://) в модель VlessConfig с тестами
- [ ] Модели VpnConfig и VpnState, обработка ошибок на всех слоях
- [ ] README: инструкция запуска, описание архитектуры Flutter → bridge → VpnService / Network Extension, план интеграции VPN-core (sing-box / xray / libv2ray)
- [ ] Современный, красивый UI (сверх ТЗ — «дизайн не важен», но делаем сильную подачу)

### Out of Scope

- Полная интеграция VLESS/Xray/sing-box core — ТЗ явно говорит «не обязательно»; вместо этого README описывает точки подключения core (Android .aar, iOS framework, FFI/JNI/gomobile)
- Проксирование реального трафика через iOS-туннель — туннель поднимается и останавливается (NEPacketTunnelProvider через TestFlight), но без VPN-core пакеты не обрабатываются; симулятор Network Extension не исполняет — разработка через устройство/TestFlight
- Продуктовые функции (аккаунты, подписки, список стран, kill switch, split tunneling) — это прототип для демонстрации архитектуры и native bridge
- Реальное шифрование/проксирование трафика — туннель поднимается и маршрутизирует, но без VPN-core трафик не проксируется

## Context

- Каталог уже содержит свежий каркас `flutter create` (default counter app) — кода, который нужно сохранять, нет
- Формат сдачи: публичный репозиторий GitHub/GitLab, README с инструкцией запуска, видео 1–3 минуты (запуск, Connect, статусы/логи, Disconnect)
- Критерий «сильного решения» из ТЗ: реально поднимается Android VpnService; Foreground Service; статусы/логи из native во Flutter; чистая архитектура; понятное описание iOS и VPN-core
- Open-source библиотеки разрешены, но в README нужно указать, что использовано и что написано самостоятельно
- Пользователь требует: feature-first clean architecture, SOLID и ООП-принципы, современный красивый нативный мост (Pigeon), без комментариев в коде

## Constraints

- **Timeline**: 48 часов на выполнение — скоуп строго по ТЗ с точечными улучшениями (UI, тесты парсера)
- **Tech stack**: Flutter (Dart), Kotlin для Android, Swift для iOS — требование ТЗ
- **Архитектура**: feature-first clean architecture, SOLID, ООП — требование пользователя
- **State management**: Bloc (flutter_bloc) — прямое указание пользователя
- **iOS-проверка**: устройство через TestFlight (аккаунт Apple Developer есть); симулятор Network Extension не исполняет
- **Мост**: Pigeon (типобезопасный кодоген) вместо сырых MethodChannel — современный подход, разрешён ТЗ
- **Стиль кода**: без комментариев в коде — требование пользователя
- **Язык документации**: русский (ТЗ и коммуникация на русском); идентификаторы и код — английский

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Pigeon вместо сырых MethodChannel/EventChannel | Типобезопасность, кодоген для трёх платформ, современный стандарт; ТЗ допускает «MethodChannel + EventChannel или Pigeon» | — Pending |
| События native→Flutter через Pigeon @EventChannelApi (либо FlutterApi callback) | Единый контракт моста в одном .dart-файле, без ручной сериализации | — Pending |
| iOS: реальный NE-таргет с PacketTunnelProvider, проверка через TestFlight | Аккаунт Apple Developer есть (подтверждено пользователем); entitlement self-serve; симулятор NE не исполняет — тестируем на устройстве | — Pending |
| iOS-мост Pigeon реализуется полноценно (Swift HostApi + события) | Требование пользователя: корректный мост на обеих платформах; демо на iOS показывает статусы/логи из Swift | — Pending |
| State management: Bloc (flutter_bloc) | Прямое указание пользователя; research предлагал Riverpod, Bloc — заявленная альтернатива, ложится на ту же архитектуру | — Pending |
| Маршрут TUN: узкая тестовая подсеть, не 0.0.0.0/0 | Выбор пользователя: интернет устройства живёт в Connected, демо не выглядит сломанным; счётчики трафика — пингом в подсеть туннеля; честное описание в README | — Pending |
| Демо-конфиг VLESS: зашитый пример в коде | Выбор пользователя: фейковый uuid/host в репо; реальную ссылку можно вставить из буфера на демо | — Pending |
| README на русском; ТЗ-docx не коммитится | Выбор пользователя: ревьюер русскоязычный; условия оплаты не место в публичном репо | — Pending |
| VLESS: парсер ссылки + модель конфига без реального core | ТЗ: «плюсом будет парсинг VLESS-ссылки»; полная интеграция вне скоупа | — Pending |
| UI делаем современным и красивым, хотя ТЗ говорит «дизайн не важен» | Дифференциатор кандидата; mobile-design скилл, тёмная тема, аккуратные статусные состояния | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-07-13 after initialization*
