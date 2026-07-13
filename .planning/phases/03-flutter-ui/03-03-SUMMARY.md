---
phase: 03-flutter-ui
plan: 03
subsystem: ui
tags: [flutter_bloc, bloc_test, mocktail, equatable, presentation, vpn]

# Dependency graph
requires:
  - phase: 03-flutter-ui (plan 03-02)
    provides: VpnStatus enum в lib/core/theme
  - phase: 01-foundation / 02-android
    provides: domain usecases (WatchVpnState, ConnectVpn, DisconnectVpn, SyncStatus) и VpnRepository.watchTraffic()
provides:
  - VpnConnectionBloc — статус-машина presentation-слоя поверх usecases
  - VpnConnectionState (status/connectedSince/rx/tx/errorMessage) + isBusy + copyWith
  - sealed VpnConnectionEvent (VpnStarted/VpnStateReceived/VpnTrafficReceived/ConnectRequested/DisconnectRequested)
  - WatchTraffic usecase-обёртка над VpnRepository.watchTraffic()
  - 6 unit-сценариев QA-02 + тест-хелпер mock_vpn_usecases
affects: [03-05, 03-06, 03-07, 03-08, 03-09]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bloc подписывается на два бесконечных стрима через internal-события (.listen → add), не через двойной emit.forEach"
    - "copyWith с явными флагами clearConnectedSince/clearError для обнуления nullable-полей"
    - "Bloc принимает usecases публичными final-полями через initializing formals (обход prefer_initializing_formals на named-параметрах)"

key-files:
  created:
    - lib/features/vpn_connection/domain/usecases/watch_traffic.dart
    - lib/features/vpn_connection/presentation/bloc/vpn_connection_event.dart
    - lib/features/vpn_connection/presentation/bloc/vpn_connection_state.dart
    - lib/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart
    - test/features/vpn_connection/presentation/bloc/vpn_connection_bloc_test.dart
    - test/helpers/mock_vpn_usecases.dart
  modified: []

key-decisions:
  - "Usecases инъектятся публичными final-полями (required this.x): named-параметры не могут быть private, а initializer-list _x = x зажигает prefer_initializing_formals — публичные поля дают чистый flutter analyze без ignore-комментариев"
  - "VpnConnected с connectedSince == null маппится с clearConnectedSince: true — copyWith(connectedSince: null) не отличит null от «не передано»"
  - "rx/tx не сбрасываются при смене статуса — трафик обновляет только VpnTrafficReceived"

patterns-established:
  - "Pattern 1 (03-RESEARCH): internal-события для подписки на N бесконечных стримов; StreamSubscription в полях, отмена в close()"
  - "close() async с await обеих cancel() — обход discarded_futures"

requirements-completed: [UI-01, UI-02, UI-05, UI-07, QA-02]

# Metrics
duration: 11min
completed: 2026-07-14
---

# Phase 3 Plan 3: VpnConnectionBloc + QA-02 Summary

**VpnConnectionBloc — статус-машина UI на internal-событиях: syncStatus-восстановление, маппинг пяти статусов, гейт двойного тапа и onRevoke, покрытая шестью сценариями QA-02 через bloc_test + mocktail**

## Performance

- **Duration:** ~11 min
- **Started:** 2026-07-14T01:26:30+03:00
- **Completed:** 2026-07-14T01:36:46+03:00
- **Tasks:** 2
- **Files modified:** 6 (все созданы)

## Accomplishments
- VpnConnectionBloc подписывается на watchVpnState и watchTraffic через internal-события (Pattern 1), обходя ловушку двойного emit.forEach (Pitfall 1) — трафик и статус живут параллельно
- syncStatus() зовётся ровно раз на VpnStarted до подписки (UI-07), в try/catch с маппингом Failure в status error (T-3-03)
- Гейт isBusy блокирует ConnectRequested/DisconnectRequested в connecting/disconnecting (UI-02); onRevoke (VpnDisconnected из стрима) не вызывает disconnectVpn
- WatchTraffic usecase-обёртка (симметрия с WatchVpnState); VpnConnectionState с copyWith на флагах обнуления
- 6 сценариев QA-02 + 4 усиливающих теста (трафик, позитивный connect, close-cancel) зелёные; весь набор 77 тестов зелёный, flutter analyze чист

## Task Commits

1. **Task 1: WatchTraffic usecase + события + state** - `5851eff` (feat)
2. **Task 2 (TDD RED): падающие сценарии QA-02** - `89e4a2c` (test)
3. **Task 2 (TDD GREEN): VpnConnectionBloc** - `7b9ff54` (feat)

_TDD: RED (test) → GREEN (feat). REFACTOR не понадобился — код чист с первого прохода._

## Files Created/Modified
- `lib/features/vpn_connection/domain/usecases/watch_traffic.dart` - usecase-обёртка над VpnRepository.watchTraffic()
- `lib/features/vpn_connection/presentation/bloc/vpn_connection_event.dart` - sealed VpnConnectionEvent (5 подтипов)
- `lib/features/vpn_connection/presentation/bloc/vpn_connection_state.dart` - VpnConnectionState + isBusy + copyWith(clearConnectedSince/clearError)
- `lib/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart` - статус-машина: подписки, маппинг статусов, гейты, close()
- `test/features/vpn_connection/presentation/bloc/vpn_connection_bloc_test.dart` - 6 сценариев QA-02 + трафик/connect/close
- `test/helpers/mock_vpn_usecases.dart` - mocktail-моки пяти usecases

## Decisions Made
- **Публичные final-поля usecases вместо приватных.** named-параметры Dart не могут быть private (`this._x` для named запрещён), а initializer-list `_x = x` зажигает `prefer_initializing_formals` в very_good_analysis. Публичные поля + `required this.x` дают чистый analyze без ignore-комментариев (комментарии запрещены проектом).
- **VpnConnected(connectedSince: null) → clearConnectedSince: true.** copyWith не различает переданный null и «не передано»; явный флаг гарантирует обнуление.
- **rx/tx переживают смену статуса.** Обновляются только VpnTrafficReceived; при disconnect последние значения остаются (приемлемо для прототипа, не тестируется).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Публичные поля usecases вместо приватного initializer-list из 03-RESEARCH Pattern 1**
- **Found during:** Task 2 (реализация Bloc)
- **Issue:** Приватный initializer-list `_watchVpnState = watchVpnState` (как в примере research) зажёг 6 info-варнингов `prefer_initializing_formals`; named-параметр не может быть private (`this._x` для named невалиден), поэтому suggestion линтера неисполним. Автогейт требует чистый `flutter analyze`.
- **Fix:** Поля usecases сделаны публичными final с initializing formals `required this.watchVpnState`; тело обращается к полям напрямую.
- **Files modified:** lib/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart
- **Verification:** flutter analyze — No issues found; поведение и внешний API конструктора (named required) не изменились.
- **Committed in:** `7b9ff54` (GREEN-коммит Task 2)

**2. [Rule 3 - Blocking] close() переведён в async с await cancel()**
- **Found during:** Task 2 (реализация close())
- **Issue:** `_stateSub?.cancel(); _trafficSub?.cancel();` в синхронном close() зажгли `discarded_futures` (cancel() возвращает Future).
- **Fix:** close() сделан async, обе cancel() ожидаются перед super.close().
- **Files modified:** lib/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart
- **Verification:** flutter analyze чист; тест «close отменяет подписки» зелёный (hasListener == false).
- **Committed in:** `7b9ff54` (GREEN-коммит Task 2)

---

**Total deviations:** 2 auto-fixed (обе Rule 3 - blocking, линтерные гейты)
**Impact on plan:** Обе правки — устранение линтерных блокеров автогейта без изменения контракта Bloc. Scope не расширен: границы (только bloc + WatchTraffic usecase + тесты) соблюдены, виджеты/экран/di не тронуты.

## Issues Encountered
- `unawaited(...)` корректно снимает `discarded_futures` для fire-and-forget connect/disconnect; ложным был не он, а необёрнутые cancel() в close() — разобрано по номерам строк из flutter analyze.

## User Setup Required
None - внешняя конфигурация не требуется.

## Next Phase Readiness
- VpnConnectionBloc готов к внедрению в OkoApp/MultiBlocProvider (план 03-05+): требует расширения AppDependencies полем WatchTraffic и передачи демо-VpnConfig (вне границ этого плана).
- Виджеты (IrisIndicator, ConnectButton, ConnectionTimer, TrafficPanel) читают этот state через BlocBuilder/BlocSelector — контракт state стабилен.
- Границы плана соблюдены: presentation/widgets и screens не создавались.

---
*Phase: 03-flutter-ui*
*Completed: 2026-07-14*

## Self-Check: PASSED
- Все 6 файлов на диске (FOUND).
- Все 3 коммита в истории (5851eff, 89e4a2c, 7b9ff54 — FOUND).
- flutter analyze: No issues found; flutter test: 77/77 зелёные.
