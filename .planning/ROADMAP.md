# Roadmap: Oko VPN

## Overview

Путь за 48 часов: сначала Pigeon-контракт и доменное ядро (фундамент, от которого зависят обе платформы), затем Android VpnService как главный критерий «сильного решения» и самый рискованный интеграционный шов. Поверх реального сервиса собирается Flutter UI по DESIGN.md (ирис-индикатор, живые логи, трафик), к нему подключается VLESS-парсер с карточкой сервера. iOS идёт после Android: полноценный Swift-мост плюс реальный Network Extension таргет с проверкой через TestFlight. Финал: README, CI и видео-демо.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 1: Фундамент и Pigeon-мост** - Типобезопасный контракт моста, доменное ядро, echo-реализации на обеих платформах
- [ ] **Phase 2: Android VpnService** - Реальный туннель, foreground-сервис, живые события статусов/логов/трафика
- [ ] **Phase 3: Flutter UI** - Экран по DESIGN.md: ирис-индикатор, кнопки, логи, таймер, трафик, восстановление состояния
- [ ] **Phase 4: VLESS-конфиг сервера** - Парсер vless://, карточка конфига, tcping, тесты парсера
- [ ] **Phase 5: iOS-мост и Network Extension** - Swift-реализация моста, PacketTunnelProvider, entitlements, TestFlight-готовность
- [ ] **Phase 6: Подача** - README с диаграммой и планом интеграции core, CI, видео-демо

## Phase Details

### Phase 1: Фундамент и Pigeon-мост
**Goal**: Типобезопасный мост Flutter ↔ native работает на обеих платформах, доменное ядро зафиксировано до нативного кода
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: BRG-01, BRG-02, BRG-03, BRG-04, CORE-01
**Success Criteria** (what must be TRUE):
  1. `flutter run` на Android и на iOS показывает echo-события StatusChanged и LogMessage, пришедшие из Kotlin- и Swift-слоя в единый Dart-стрим
  2. `getStatus()` возвращает снапшот (status, connectedSince, счётчики трафика) на обеих платформах
  3. Hot restart не теряет состояние: последний статус реплеится новому подписчику, событие, отправленное до подписки Dart, доходит до слушателя
  4. Domain-слой компилируется без импорта `*.g.dart`; сгенерированный код виден только в core/bridge и features/*/data, DTO носят суффикс Message
  5. Ошибка из native доводится до доменного состояния Error через sealed/immutable-модели VpnConfig, VpnState, VpnEvent
**Plans**: 7 plans
Plans:
- [ ] 01-01-PLAN.md — Контракт pigeon, кодоген трёх языков, зависимости стека (BRG-01, BRG-02)
- [ ] 01-02-PLAN.md — Доменное ядро: sealed/immutable модели, интерфейсы, usecases (CORE-01)
- [ ] 01-03-PLAN.md — VpnBridge демультиплексор, мапперы DTO→entity, датасорсы (BRG-02, BRG-03)
- [ ] 01-04-PLAN.md — Репозитории с replay, composition root, debug-harness (BRG-03, BRG-04)
- [ ] 01-05-PLAN.md — Android echo-мост: регистрация, main-thread эмиттер, replay (BRG-01, BRG-02, BRG-04)
- [ ] 01-06-PLAN.md — iOS echo-мост: регистрация Runner, main-queue эмиттер, replay (BRG-01, BRG-02, BRG-04)
- [ ] 01-07-PLAN.md — Живая end-to-end проверка echo-моста, phase gate (BRG-02, BRG-04)

### Phase 2: Android VpnService
**Goal**: Реальный VPN-туннель на Android поднимается через consent-флоу, живёт в foreground-сервисе и шлёт живые события во Flutter
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: AND-01, AND-02, AND-03, AND-04, AND-05, AND-06
**Success Criteria** (what must be TRUE):
  1. Тап Connect вызывает системный consent-диалог `prepare()`; согласие ведёт к Connected со значком VPN в статус-баре, отказ даёт статус Error с внятной строкой в логах
  2. В статусе Connected интернет устройства продолжает работать: решение по маршруту (узкая подсеть либо read-and-drop) зафиксировано в начале фазы
  3. Уведомление foreground-сервиса видно с момента Connecting; на Android 13+ запрошен POST_NOTIFICATIONS; на эмуляторе API 34/35 сервис не крашится (foregroundServiceType=systemExempted)
  4. Счётчики trafficChanged растут от реальных байтов из TUN read-loop с периодом раз в секунду
  5. Disconnect и системный отзыв VPN (onRevoke) доводят статус Disconnected до Flutter через единый teardown; каждый переход состояния виден событием logMessage
**Plans**: TBD

### Phase 3: Flutter UI
**Goal**: Пользователь управляет VPN с одного экрана: ирис-индикатор пяти состояний, живые логи, таймер, трафик, восстановление после перезапуска
**Mode:** mvp
**Depends on**: Phase 1 (мост и домен), Phase 2 (финальная проверка на реальном сервисе; старт на fake-репозитории параллельно Phase 2)
**Requirements**: UI-01, UI-02, UI-03, UI-04, UI-05, UI-06, UI-07, UI-08, QA-02
**Success Criteria** (what must be TRUE):
  1. Ирис-индикатор и текстовый бейдж показывают все пять статусов; тёмная и светлая темы, staggered-вход и haptics соответствуют DESIGN.md
  2. Кнопка Connect/Disconnect блокируется в Connecting и Disconnecting, двойной тап невозможен; unit-тесты Bloc-переходов (включая error и сценарий onRevoke) зелёные
  3. Панель логов показывает события в реальном времени: уровни info/warning/error с цветовой маркировкой, автоскролл отключается при ручной прокрутке, кнопка копирования работает
  4. Карточка сервера, таймер от connectedSince (переживает пересоздание виджета) и плитки rx/tx из trafficChanged обновляются вживую
  5. Перезапуск приложения при работающем VPN восстанавливает Connected через `getStatus()`
**Plans**: TBD
**UI hint**: yes

### Phase 4: VLESS-конфиг сервера
**Goal**: Пользователь вставляет vless://-ссылку и видит распарсенный конфиг сервера с измеренной задержкой
**Mode:** mvp
**Depends on**: Phase 1 (доменные модели), Phase 3 (экран для карточки сервера); парсер и тесты параллелятся с Phase 2-3
**Requirements**: VLS-01, VLS-02, VLS-03, QA-01
**Success Criteria** (what must be TRUE):
  1. Вставка vless:// из буфера обмена показывает карточку конфига (name, host:port, type, security, sni); UUID в логах маскируется
  2. Кривая ссылка даёт понятную ошибку в UI, приложение не падает
  3. Задержка сервера измеряется через TCP connect time с таймаутом и отображается на карточке
  4. Unit-тесты парсера зелёные: валидные ссылки, кривые ссылки, IPv6-хост, percent-encoding, невалидный UUID, отсутствующие параметры
**Plans**: TBD

### Phase 5: iOS-мост и Network Extension
**Goal**: Демо на iOS работает: статусы и логи идут из Swift-слоя, туннель стартует и останавливается через реальный Network Extension таргет
**Mode:** mvp
**Depends on**: Phase 1 (Pigeon-контракт); выполняется после Phase 2-4, чтобы Android-демо не ждало iOS
**Requirements**: IOS-01, IOS-02, IOS-03, IOS-04
**Success Criteria** (what must be TRUE):
  1. Приложение запускается на iOS: Connect ведёт через Connecting к Connected, статусы и логи из Swift-слоя видны на Flutter-экране
  2. Extension-таргет с PacketTunnelProvider стартует и останавливает туннель через NETunnelProviderManager, NEPacketTunnelNetworkSettings применяются
  3. Смена статуса туннеля из extension доходит до Flutter-экрана через NEVPNStatus observer
  4. Packet Tunnel entitlements и App Group настроены у обоих таргетов; архив собирается и готов к прогону через TestFlight на устройстве
**Plans**: TBD

### Phase 6: Подача
**Goal**: Ревьюер запускает проект по README за минуты и получает полную картину архитектуры, ограничений и плана интеграции core
**Mode:** mvp
**Depends on**: Phase 1-5 (видео снимается один раз на готовом приложении)
**Requirements**: DOC-01, DOC-02, DOC-03, DOC-04, DOC-05
**Success Criteria** (what must be TRUE):
  1. README ведёт от клона репозитория до запущенной Android-сборки; mermaid-диаграмма описывает путь Flutter → Pigeon → VpnService / Network Extension; указано, что взято open-source и что написано самостоятельно
  2. Раздел iOS покрывает capabilities, entitlements, App Groups, взаимодействие app ↔ extension и ограничения симулятора
  3. Раздел «План интеграции VPN-core» называет точки подключения в коде: интерфейс VpnCore, Android .aar, iOS .xcframework, FFI/JNI/gomobile
  4. CI GitHub Actions (flutter analyze + flutter test) зелёный, бейдж виден в README
  5. Видео 1-3 минуты показывает запуск, Connect, статусы/логи/трафик, Disconnect
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Фундамент и Pigeon-мост | 0/7 | Not started | - |
| 2. Android VpnService | 0/TBD | Not started | - |
| 3. Flutter UI | 0/TBD | Not started | - |
| 4. VLESS-конфиг сервера | 0/TBD | Not started | - |
| 5. iOS-мост и Network Extension | 0/TBD | Not started | - |
| 6. Подача | 0/TBD | Not started | - |

---
*Создано: 2026-07-13*
*Гранулярность: standard, режим: mvp*
