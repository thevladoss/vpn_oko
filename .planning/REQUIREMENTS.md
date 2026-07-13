# Requirements: Oko VPN — Flutter Native VPN Prototype

**Defined:** 2026-07-13
**Core Value:** Реально работающий Android VpnService с живым потоком статусов и логов из native во Flutter через чистый типобезопасный мост.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Flutter UI

- [ ] **UI-01**: Экран показывает пять статусов VPN: Disconnected, Connecting, Connected, Disconnecting, Error
- [ ] **UI-02**: Кнопки Connect/Disconnect работают и блокируются в переходных состояниях (двойной тап невозможен)
- [ ] **UI-03**: Блок логов показывает события из native в реальном времени (буфер ограничен, автоскролл с отключением при ручной прокрутке)
- [ ] **UI-04**: Экран показывает выбранный сервер и таймер времени подключения (тикает от connectedAt, переживает пересоздание виджета)
- [ ] **UI-05**: Экран показывает статистику трафика rx/tx из событий trafficChanged
- [ ] **UI-06**: UI реализует дизайн-концепцию DESIGN.md: ирис-индикатор состояния, тёмная и светлая темы, staggered-вход, haptics
- [ ] **UI-07**: UI восстанавливает актуальное состояние через getStatus() при старте приложения (VPN живёт в сервисе)
- [ ] **UI-08**: Логи имеют уровни (info/warning/error) с цветовой маркировкой и кнопку копирования в буфер

### Мост Flutter ↔ Native

- [x] **BRG-01**: Pigeon-контракт объявляет методы startVpn(config), stopVpn(), getStatus() (@HostApi)
- [x] **BRG-02**: События native→Flutter идут одним стримом через @EventChannelApi с sealed-иерархией: StatusChanged, LogMessage, TrafficChanged, VpnError
- [ ] **BRG-03**: Domain-слой изолирован от кодогена: типы Pigeon получают суффикс Message, импорт *.g.dart разрешён только в core/bridge и features/*/data, мапперы переводят DTO в доменные entity
- [x] **BRG-04**: События отправляются только с main thread платформы; последний статус реплеится новому подписчику, getStatus() отдаёт снапшот (status, connectedSince, счётчики) — гонка «событие раньше подписки» исключена

### Android

- [ ] **AND-01**: VpnService.prepare() вызывается перед каждым стартом; отказ пользователя переводит в статус Error с внятным логом
- [ ] **AND-02**: VpnService.Builder конфигурирует туннель: addAddress, addRoute, addDnsServer, establish; маршрут выбран так, чтобы Connected не убивал интернет устройства без VPN-core
- [ ] **AND-03**: Foreground Service запускается с уведомлением, foregroundServiceType=systemExempted, POST_NOTIFICATIONS запрашивается на Android 13+
- [ ] **AND-04**: VPN корректно останавливается (закрытие TUN fd, остановка foreground); onRevoke обрабатывается и доводит статус Disconnected до Flutter
- [ ] **AND-05**: Read-loop TUN-дескриптора считает реальные байты и шлёт trafficChanged раз в секунду
- [ ] **AND-06**: Все переходы состояний и ключевые действия сервиса логируются событиями logMessage во Flutter

### iOS

- [ ] **IOS-01**: Swift-реализация Pigeon-моста в основном приложении: startVpn/stopVpn/getStatus и поток событий работают, демо на iOS показывает статусы/логи из Swift-слоя
- [ ] **IOS-02**: Network Extension таргет с PacketTunnelProvider: start/stop туннеля через NETunnelProviderManager, NEPacketTunnelNetworkSettings применяются
- [ ] **IOS-03**: Статусы туннеля из extension доводятся до приложения (NEVPNStatus observer) и дальше во Flutter
- [ ] **IOS-04**: Capabilities, entitlements (Packet Tunnel), App Groups настроены; сборка готова к прогону через TestFlight на устройстве

### VLESS

- [ ] **VLS-01**: Парсер vless://-ссылки создаёт модель VlessConfig (uuid, host, port, type, security, sni, name); кривые ссылки дают внятные ошибки
- [ ] **VLS-02**: Пользователь может вставить vless:// из буфера обмена и увидеть карточку распарсенного конфига
- [ ] **VLS-03**: Приложение измеряет задержку сервера через TCP connect time (tcping) с таймаутом

### Доменное ядро

- [x] **CORE-01**: Доменные модели VpnConfig, VpnState, VpnEvent — sealed/immutable, ошибки обрабатываются на всех слоях и доводятся до UI-состояния Error

### Тесты

- [ ] **QA-01**: Unit-тесты VLESS-парсера: валидные ссылки, кривые ссылки, edge cases
- [ ] **QA-02**: Unit-тесты Bloc-машины состояний: переходы, реакция на error и onRevoke-сценарий

### Подача

- [ ] **DOC-01**: README: инструкция запуска, mermaid-диаграмма архитектуры Flutter → Pigeon → VpnService / Network Extension, что взято open-source и что написано самостоятельно
- [ ] **DOC-02**: README-раздел iOS: capabilities, entitlements, App Groups, взаимодействие app ↔ extension, ограничения симулятора
- [ ] **DOC-03**: README-раздел «План интеграции VPN-core»: sing-box / xray / libv2ray, Android .aar, iOS .xcframework, FFI/JNI/gomobile, точки подключения в коде (интерфейс VpnCore)
- [ ] **DOC-04**: CI GitHub Actions: flutter analyze + flutter test, бейдж в README
- [ ] **DOC-05**: Видео-демо 1–3 минуты: запуск, Connect, статусы/логи/трафик, Disconnect

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Расширения

- **EXT-01**: Скорость трафика B/s поверх счётчиков rx/tx
- **EXT-02**: Интеграция реального VPN-core (sing-box/xray) через .aar / .xcframework
- **EXT-03**: Проксирование реального трафика на iOS-туннеле
- **EXT-04**: Импорт конфига по QR-коду, список серверов

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Полная интеграция Xray/sing-box core | ТЗ явно освобождает; 20+ часов без прибавки к оценке — вместо этого DOC-03 |
| Форвардинг пакетов из TUN (mini-tun2socks) | Ядро tun2socks — недели работы; read-loop честно считает и дропает |
| Kill switch, split tunneling, per-app VPN | Продуктовые фичи вне критериев ТЗ; упоминание в README как направления |
| Автопереподключение / always-on | Конфликтует с корректной обработкой onRevoke; reconnect только вручную |
| Аккаунты, подписки, локализация, персист настроек, onboarding | Инфраструктура, которую ревьюер тестового не оценивает |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BRG-01 | Phase 1 | Complete |
| BRG-02 | Phase 1 | Complete |
| BRG-03 | Phase 1 | Pending |
| BRG-04 | Phase 1 | Complete |
| CORE-01 | Phase 1 | Complete |
| AND-01 | Phase 2 | Pending |
| AND-02 | Phase 2 | Pending |
| AND-03 | Phase 2 | Pending |
| AND-04 | Phase 2 | Pending |
| AND-05 | Phase 2 | Pending |
| AND-06 | Phase 2 | Pending |
| UI-01 | Phase 3 | Pending |
| UI-02 | Phase 3 | Pending |
| UI-03 | Phase 3 | Pending |
| UI-04 | Phase 3 | Pending |
| UI-05 | Phase 3 | Pending |
| UI-06 | Phase 3 | Pending |
| UI-07 | Phase 3 | Pending |
| UI-08 | Phase 3 | Pending |
| QA-02 | Phase 3 | Pending |
| VLS-01 | Phase 4 | Pending |
| VLS-02 | Phase 4 | Pending |
| VLS-03 | Phase 4 | Pending |
| QA-01 | Phase 4 | Pending |
| IOS-01 | Phase 5 | Pending |
| IOS-02 | Phase 5 | Pending |
| IOS-03 | Phase 5 | Pending |
| IOS-04 | Phase 5 | Pending |
| DOC-01 | Phase 6 | Pending |
| DOC-02 | Phase 6 | Pending |
| DOC-03 | Phase 6 | Pending |
| DOC-04 | Phase 6 | Pending |
| DOC-05 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 33 total (при первичном подсчёте указано 32; пересчёт по списку даёт 33)
- Mapped to phases: 33
- Unmapped: 0 ✓

---
*Requirements defined: 2026-07-13*
*Last updated: 2026-07-13 — traceability заполнена roadmapper (6 фаз)*
