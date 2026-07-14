---
phase: 05-ios-network-extension
fixed_at: 2026-07-14T00:00:00Z
review_path: .planning/phases/05-ios-network-extension/05-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 5: Code Review Fix Report — iOS Network Extension

**Fixed at:** 2026-07-14
**Source review:** .planning/phases/05-ios-network-extension/05-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6 (BL-01, HI-01, ME-01, ME-02, ME-03, LO-01)
- Fixed: 6
- Skipped: 0
- Out of scope (по заданию): LO-02, LO-03

## Fixed Issues

### BL-01: NETunnelProviderManager не удерживается

**Files modified:** `ios/Runner/Bridge/VpnHostApiImpl.swift`
**Commit:** 54b6151
**Applied fix:** Добавлено свойство `private var manager: NETunnelProviderManager?`. Менеджер сохраняется в `self.manager` перед `saveToPreferences`/старт. `stopVpn` переиспользует `self.manager` (`connection.stopVPNTunnel()`); фолбэк грузит существующий менеджер, сохраняет его и навешивает observer до остановки. Требует device-проверки (TestFlight): NE-флоу не исполняется в симуляторе.

### HI-01: attach течёт предыдущим наблюдателем

**Files modified:** `ios/Runner/Bridge/VpnStatusObserver.swift`
**Commit:** 3a75cce
**Applied fix:** Перед `addObserver` снимается предыдущий токен через `removeObserver(token)`. Повторный `startVpn`/реконнект больше не плодит наблюдателей `NEVPNStatusDidChange`.

### ME-01: attach эмитит ложный disconnected после connecting

**Files modified:** `ios/Runner/Bridge/VpnStatusObserver.swift`
**Commit:** eca3b08
**Applied fix:** `attach(_:emitInitial:)` с `emitInitial: Bool = false`. Старт-флоу (`observer.attach(manager.connection)`) больше не вызывает синхронный `report`, поэтому нет отката `connecting → disconnected`. Начальный отчёт включается явно только в сценарии восстановления.

### ME-02: disconnected не доходит после перезапуска приложения

**Files modified:** `ios/Runner/Bridge/VpnHostApiImpl.swift`
**Commit:** 8bd5674
**Applied fix:** `restoreExistingTunnel()` вызывается из `init`: грузит менеджер из `loadAllFromPreferences`, сохраняет в `self.manager`, навешивает observer с `emitInitial: true`. После рестарта при активном туннеле текущий статус и переход в `disconnected` доходят до Flutter. Совместно с фолбэком `stopVpn` (BL-01) закрывает находку. Требует device-проверки (TestFlight).

### ME-03: гонка при чтении snapshot без синхронизации

**Files modified:** `ios/Runner/Bridge/VpnEventListener.swift`
**Commit:** ddd3686
**Applied fix:** Добавлен `NSLock`. `storedStatus`/`rxBytes`/`txBytes` читаются и пишутся под замком (`emit`, `snapshot`, геттер `lastStatus`). Контракт `emit` сохранён: доставка в sink остаётся на `DispatchQueue.main.async`. `StatusChangedMessage` — value-type, снапшот теперь атомарен.

### LO-01: захардкоженный DEVELOPMENT_TEAM

**Files modified:** `scripts/add_packet_tunnel_target.rb`
**Commit:** d0de10d
**Applied fix:** `settings['DEVELOPMENT_TEAM'] = ENV.fetch('DEVELOPMENT_TEAM', 'Z2GDTXHVZZ')`. Фолбэк совпадает с Team ID Runner-таргета, скрипт переносим между аккаунтами.

## Verification Gates

- `flutter analyze` — чисто (No issues found)
- `flutter test` — 147/147 зелёные
- `flutter build ios --no-codesign --debug` — Runner + PacketTunnel.appex собраны (appex встроен в `Runner.app/PlugIns/`)
- `flutter build ios --simulator --debug` — симулятор-ветка собрана
- Grep-инварианты: `private var manager` присутствует; `removeObserver` в `attach` и `deinit`
- Транзитные pod-артефакты (`project.pbxproj`, `contents.xcworkspacedata`) сброшены после сборки — HEAD чист
- Комментариев в Swift нет

**Замечание:** NE-логика BL-01/ME-01/ME-02 проверена компиляцией; полное поведение (retain менеджера, поток статусов, восстановление после рестарта) требует проверки на устройстве через TestFlight — Simulator не исполняет Network Extension (ограничение фазы).

---

_Fixed: 2026-07-14_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
