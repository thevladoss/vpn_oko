---
phase: 06-podacha
plan: 01
subsystem: docs
tags: [readme, mermaid, ci-badge, ios-network-extension, vpn-core, gomobile]

requires:
  - phase: 01-foundation
    provides: Pigeon-контракт, VpnBridge, доменные модели
  - phase: 02-android-vpnservice
    provides: OkoVpnService.startReadLoop, establish, узкий маршрут 10.111.222.0/24
  - phase: 04-vless
    provides: VlessConfig, парсер vless://, демо-конфиг
  - phase: 05-ios-network-extension
    provides: PacketTunnelProvider.startTunnel, entitlements, App Group, DOC-02
provides:
  - Полный README.md на русском (344 строки)
  - Секции: шапка+CI-бейдж, Запуск, Структура, Пять фаз, open-source vs своё
  - Архитектура: mermaid flowchart + sequenceDiagram + маппинг слой→файлы
  - iOS: capabilities, entitlements, App Groups, app↔extension, ограничение симулятора
  - План интеграции VPN-core: startReadLoop/startTunnel, интерфейс VpnCore, gomobile/JNI, варианты core
  - Ограничения и «что дальше»
affects: [06-02-ci, 06-04-checkpoints]

tech-stack:
  added: []
  patterns:
    - "README на русском, идентификаторы/mermaid/yaml/команды на английском"
    - "Диаграммы через mermaid в fenced-блоке (нативный рендер GitHub)"
    - "CI-бейдж с плейсхолдером <owner>/<repo> под workflow ci.yml/name CI"

key-files:
  created:
    - .planning/phases/06-podacha/06-01-SUMMARY.md
  modified:
    - README.md

key-decisions:
  - "Интерфейс VpnCore описан только в README (эскиз Kotlin/Swift), в код не введён — риск мёртвого кода ловит very_good_analysis"
  - "Заголовки с тире (Russian nominal-predicate) сохранены как грамматически обязательные; стилистический em-dash в прозе не используется"
  - "CI-бейдж с плейсхолдером <owner>/<repo>: git remote не настроен, реальные owner/repo подставит пользователь на сдаче (план 06-04)"

patterns-established:
  - "Раздел ограничений называет границы прямо (нет core, tx=0, узкий маршрут, iOS TestFlight, конфиг display-only) без маркетинга"

requirements-completed: [DOC-01, DOC-02, DOC-03, DOC-04]

duration: 4min
completed: 2026-07-14
---

# Phase 6 Plan 01: README на русском Summary

**Полный README на русском (344 строки): запуск от клона до flutter run, mermaid-архитектура Flutter→Pigeon→VpnService/NE, open-source vs своё, iOS Network Extension, план интеграции VPN-core с точками startReadLoop/startTunnel и честный список ограничений**

## Performance

- **Duration:** 4 min
- **Started:** 2026-07-14T03:40:39Z
- **Completed:** 2026-07-14T03:45:00Z
- **Tasks:** 3
- **Files modified:** 1 (README.md)

## Accomplishments
- README ведёт ревьюера от клона до `flutter run` на Android: требования (Flutter 3.44.5, minSdk 26, targetSdk 36) и команды `pub get` / `run` / `analyze` / `test`
- Две mermaid-диаграммы (flowchart потока Connect + sequenceDiagram) валидны для нативного рендера GitHub; таблица маппинга слой→файлы
- iOS-раздел покрывает bundle id, entitlements (`packet-tunnel-provider`), App Group `group.com.example.vpnOko`, обмен app↔extension и ограничение симулятора с путём к TestFlight
- DOC-03: план интеграции core называет точки `OkoVpnService.startReadLoop` и `PacketTunnelProvider.startTunnel`, эскиз интерфейса `VpnCore`, механику gomobile/JNI (`.aar`/`.xcframework`, «Dart FFI не место интеграции») и варианты core (sing-box первичный)
- Честный раздел «Ограничения»: нет core/трафик не проксируется, tx=0, узкий маршрут 10.111.222.0/24, iOS только TestFlight, конфиг display-only

## Task Commits

Each task was committed atomically:

1. **Task 1: Шапка, бейдж, Запуск, Структура, Пять фаз, open-source vs своё** - `557a93d` (docs)
2. **Task 2: Архитектура + mermaid + iOS-раздел** - `77ab633` (docs)
3. **Task 3: План интеграции VPN-core + Ограничения + Что дальше** - `44725b3` (docs)

## Files Created/Modified
- `README.md` - Полностью перезаписан (заглушка flutter create удалена); 344 строки, 9 секций на русском
- `.planning/phases/06-podacha/06-01-SUMMARY.md` - Этот файл

## Decisions Made
- Интерфейс `VpnCore` описан словами и эскизом сигнатур в README, в код не введён: реальный интерфейс без реализации ловит `very_good_analysis` как мёртвый код (Open Q3 research).
- Тире в заголовках-определениях («Oko VPN — прототип...») сохранено как грамматически обязательное подлежащее-сказуемое русского языка; стилистический em-dash-пауза в прозе не используется по stop-slop.
- CI-бейдж вставлен с плейсхолдером `<owner>/<repo>` и пояснением: git remote не настроен, реальные значения подставляет пользователь после создания публичного репо (план 06-04).
- Флейк google_fonts (Pitfall 1 research) вне скоупа этого плана: локальный self-validating прогон `flutter analyze && flutter test` относится к плану 06-02 (CI).

## Deviations from Plan

None - plan executed exactly as written. Все три задачи выполнены, grep-гейты пройдены, README прошёл проверку на запрещённые маркетинговые формулировки («полноценный VPN», «шифрует трафик» отсутствуют).

## Issues Encountered
None.

## Known Stubs

- `README.md` CI-бейдж: плейсхолдер `<owner>/<repo>` в URL. **Намеренный**: git remote не настроен, реальные owner/repo подставит пользователь на сдаче (план 06-04). README прямо инструктирует заменить плейсхолдер. Не блокирует цель плана.

## User Setup Required
None - no external service configuration required. Создание публичного репозитория и подстановка owner/repo в бейдж — checkpoint плана 06-04.

## Next Phase Readiness
- Путь бейджа `actions/workflows/ci.yml/badge.svg` (name `CI`) согласован с планом 06-02 (CI workflow `ci.yml`).
- README ссылается на `.github/workflows/ci.yml` — файл создаётся планом 06-02.
- Секции iOS и план core готовы к ручной вычитке и рендер-проверке mermaid перед `/gsd:verify-work`.

## Self-Check: PASSED

- FOUND: README.md
- FOUND: .planning/phases/06-podacha/06-01-SUMMARY.md
- FOUND commit: 557a93d, 77ab633, 44725b3

---
*Phase: 06-podacha*
*Completed: 2026-07-14*
