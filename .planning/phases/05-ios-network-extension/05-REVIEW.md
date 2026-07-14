---
phase: 05-ios-network-extension
reviewed: 2026-07-14T00:00:00Z
depth: deep
files_reviewed: 7
files_reviewed_list:
  - ios/PacketTunnel/PacketTunnelProvider.swift
  - ios/Runner/Bridge/VpnHostApiImpl.swift
  - ios/Runner/Bridge/VpnStatusObserver.swift
  - ios/PacketTunnel/Info.plist
  - ios/Runner/Runner.entitlements
  - ios/PacketTunnel/PacketTunnel.entitlements
  - scripts/add_packet_tunnel_target.rb
findings:
  blocker: 1
  high: 1
  medium: 3
  low: 3
  total: 8
status: issues_found
---

# Phase 5: Code Review Report — iOS Network Extension

**Reviewed:** 2026-07-14
**Depth:** deep (cross-file: VpnEventListener, Messages.g.swift, AppDelegate, project.pbxproj)
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Ревью Swift-слоя фазы 5 (реальный `NETunnelProviderManager`-мост, `PacketTunnelProvider`-скелет,
`NEVPNStatus`-observer, entitlements/App Groups, xcodeproj-скрипт). Проверял по чек-листу iOS NE:
корректность NE-флоу, вызов completionHandler, полнота маппинга статусов, утечки NotificationCenter,
retain-семантику менеджера, точность bundle id.

Сильные стороны подтверждены: NE-флоу правильный (`loadAllFromPreferences` → configure →
`saveToPreferences` → `loadFromPreferences` reload перед стартом → `startVPNTunnel`), reload перед
стартом присутствует (не тот классический баг), `completionHandler`/`completion` вызывается на всех
путях без висяков, маппинг `NEVPNStatus` полный (6 веток + `@unknown`), эмиссия в стрим уходит на
main queue, bundle id везде точный (`com.example.vpnOko.PacketTunnel`, App Group
`group.com.example.vpnOko`, не `vpn_oko`), entitlements обоих таргетов согласованы.

Главная проблема — жизненный цикл `NETunnelProviderManager` и observer. Менеджер не хранится как
свойство (локальная переменная в замыкании), что нарушает явное требование фазы «manager хранится» и
документированное требование Apple к времени жизни. Отсюда следствия: observer привязан к транзитному
`connection`, повторный `attach` течёт, `stopVpn` работает с другим экземпляром менеджера и не
навешивает observer. Всё это подрывает надёжность живого потока статусов — ключевую ценность проекта.

## Blocker Issues

### BL-01: `NETunnelProviderManager` не удерживается — локальная переменная вместо свойства

**File:** `ios/Runner/Bridge/VpnHostApiImpl.swift:36-61`
**Issue:** Менеджер существует только как локальная переменная `manager` внутри замыкания
`loadAllFromPreferences`. После завершения замыкания единственная сильная ссылка на менеджер
исчезает. Apple документирует требование удерживать сильную ссылку на `NETunnelProviderManager`,
пока нужен его `connection`/`NETunnelProviderSession` и доставка `NEVPNStatusDidChange`; иначе
сессия/уведомления могут перестать работать. Это прямо нарушает требование фазы «manager хранится».

Следствия, наблюдаемые в коде:
- `observer.attach(manager.connection)` (строка 60) привязывается к `connection`, чей владелец
  (`manager`) освобождается сразу после замыкания. Observer держит только сам `connection` (через
  захват в замыкании), но не менеджер.
- `stopVpn` (строки 80-82) не переиспользует стартовый менеджер, а грузит свежий
  `loadAllFromPreferences` и зовёт `stopVPNTunnel()` на `managers?.first?.connection` — другом
  экземпляре. Стабильность доставки `disconnected` в observer, навешанный на стартовый `connection`,
  становится зависимой от того, жив ли ещё стартовый менеджер.

Итог: живой поток статусов (`StatusChanged`) — основная ценность проекта — держится на неудерживаемом
объекте. Симптом «start не срабатывает / статусы не доходят» — классический для этого анти-паттерна.

**Fix:**
```swift
final class VpnHostApiImpl: VpnHostApi {
  private let listener: VpnEventListener
  private let observer = VpnStatusObserver()
  private var manager: NETunnelProviderManager?   // удержать менеджер

  // ... в startVpn:
  let manager = managers?.first ?? NETunnelProviderManager()
  self.manager = manager                          // сохранить перед save/start
  // ... configure ...
  manager.saveToPreferences { ... manager.loadFromPreferences { ...
      self.observer.attach(manager.connection)
      try manager.connection.startVPNTunnel()
  } }

  // в stopVpn переиспользовать self.manager вместо свежего loadAll:
  if let manager = self.manager {
    manager.connection.stopVPNTunnel()
  } else {
    NETunnelProviderManager.loadAllFromPreferences { managers, _ in
      let m = managers?.first
      m.map { self.manager = $0; self.observer.attach($0.connection) }
      m?.connection.stopVPNTunnel()
    }
  }
}
```

## High Issues

### HI-01: `VpnStatusObserver.attach` течёт предыдущим наблюдателем при повторном вызове

**File:** `ios/Runner/Bridge/VpnStatusObserver.swift:11-20`
**Issue:** `attach` перезаписывает `token` новым наблюдателем, не снимая предыдущий через
`removeObserver`. `removeObserver` вызывается только в `deinit`, но `observer` — долгоживущее свойство
`VpnHostApiImpl` (живёт всё время работы приложения), поэтому `deinit` практически не наступает.
Каждый повторный `startVpn` (реконнект, retry после ошибки, повторное подключение) добавляет ещё один
наблюдатель `NEVPNStatusDidChange` поверх старого. Старые замыкания продолжают срабатывать →
дубли `StatusChangedMessage` в стриме + рост числа наблюдателей (утечка NotificationCenter).

**Fix:**
```swift
func attach(_ connection: NEVPNConnection) {
  if let token = token {
    NotificationCenter.default.removeObserver(token)
  }
  token = NotificationCenter.default.addObserver(
    forName: .NEVPNStatusDidChange, object: connection, queue: nil
  ) { [weak self] _ in self?.report(connection) }
  report(connection)
}
```

## Medium Issues

### ME-01: `attach` эмитит немедленный `report` — ложный `disconnected` после `connecting`

**File:** `ios/Runner/Bridge/VpnStatusObserver.swift:19`, `ios/Runner/Bridge/VpnHostApiImpl.swift:60-61`
**Issue:** В `startVpn` порядок такой: сверху эмитится `StatusChanged(.connecting)` (строка 15), затем
в самом низу `observer.attach(manager.connection)` синхронно вызывает `report(connection)`. На момент
`attach` туннель ещё не запущен (`startVPNTunnel()` идёт следующей строкой), поэтому
`connection.status` == `.disconnected` (или `.invalid`), и `report` эмитит
`StatusChanged(.disconnected)` (или `.error`). UI получает последовательность
`connecting → disconnected → connecting → connected`: промежуточный откат из `connecting` в
`disconnected` — видимый глитч статуса и перетирание `listener.lastStatus`.

**Fix:** не эмитить начальный `report` в старт-флоу (навешивать observer до `startVPNTunnel`, но без
немедленного отчёта), либо сделать начальный `report` опциональным параметром `attach(..., emitInitial: Bool = false)`
и включать его только для сценария восстановления статуса, а не для только что созданного соединения.

### ME-02: `stopVpn` не навешивает observer — `disconnected` не доходит после перезапуска приложения

**File:** `ios/Runner/Bridge/VpnHostApiImpl.swift:80-85`
**Issue:** Observer навешивается только в `startVpn`. Если приложение перезапущено при активном
туннеле и пользователь жмёт Stop, `stopVpn` грузит менеджер и зовёт `stopVPNTunnel()`, но observer в
этой сессии не навешан ни на какое `connection`. Переход в `disconnected` не эмитится в стрим
`VpnEventBus`; `getStatus()`-снапшот вернёт дефолтный `lastStatus` (`.disconnected` из фазы 1), а не
реальный переход. Flutter теряет событие завершения на сессии, где `startVpn` не вызывался.

**Fix:** в `stopVpn` (после загрузки/переиспользования менеджера) навесить observer на его
`connection` до вызова `stopVPNTunnel()`, чтобы поймать переход в `disconnected`. При реализации
BL-01 (хранимый менеджер + observer) это закрывается автоматически.

### ME-03: `getStatus`/`snapshot` читают общее мутируемое состояние без синхронизации

**File:** `ios/Runner/Bridge/VpnHostApiImpl.swift:88-90`, `ios/Runner/Bridge/VpnEventListener.swift:20-39`
**Issue:** `snapshot()` читает `lastStatus`, `rxBytes`, `txBytes` тремя отдельными обращениями.
`emit()` мутирует эти же поля синхронно на треде вызывающего — а `emit` дёргается из колбэков
`NEVPNStatusDidChange` (`queue: nil` → тред постинга, потенциально фоновый) и из NE-completion.
`getStatus` (Pigeon-sync) исполняется на платформенном треде. Синхронизации нет — гонка данных при
одновременном чтении снапшота и записи статуса; снапшот может смешать поля из разных моментов.
Требование фазы «снапшот консистентен» строго не выполняется (значения-типы не крашат, но снапшот
может быть неатомарным).

**Fix:** защитить чтение/запись общего состояния сериальной очередью или `NSLock`:
```swift
private let stateLock = NSLock()
func emit(_ event: VpnEventMessage) {
  stateLock.lock(); defer { stateLock.unlock() }
  // ... мутации lastStatus/rxBytes/txBytes ...
}
func snapshot() -> VpnStatusSnapshotMessage {
  stateLock.lock(); defer { stateLock.unlock() }
  return VpnStatusSnapshotMessage(...)
}
```
(Прим.: файл `VpnEventListener.swift` — из фазы 1, вне формального скоупа ревью, но гонка проявляется
через `getStatus` фазы 5; фикс уместнее в listener.)

## Low Issues

### LO-01: Захардкоженный `DEVELOPMENT_TEAM` в xcodeproj-скрипте

**File:** `scripts/add_packet_tunnel_target.rb:24`
**Issue:** `settings['DEVELOPMENT_TEAM'] = 'Z2GDTXHVZZ'` — специфичный для конкретного аккаунта Team ID
зашит в скрипт. Не секрет (Team ID не конфиденциален), но ломает переносимость: другой контрибьютор,
прогнав скрипт, получит чужой Team ID и провал автоподписи. Runner-таргет свой Team ID не переопределяет,
рассинхрон.
**Fix:** читать из окружения с фолбэком:
```ruby
settings['DEVELOPMENT_TEAM'] = ENV.fetch('DEVELOPMENT_TEAM', 'Z2GDTXHVZZ')
```

### LO-02: Молчаливый фолбэк позиции фазы «Embed App Extensions» при отсутствии «Thin Binary»

**File:** `scripts/add_packet_tunnel_target.rb:45-48`
**Issue:** `runner.build_phases.move(embed_phase, thin_binary_index) if thin_binary_index` — если фаза
`Thin Binary` не найдена (`thin_binary_index` == nil), embed-фаза остаётся в конце списка (после
любого thinning), молча, без предупреждения. На проекте, где Flutter-фаза переименована/отсутствует,
embed окажется в неверной позиции без диагностики.
**Fix:** логировать предупреждение в ветке `else`, чтобы рассинхрон был заметен:
```ruby
if thin_binary_index
  runner.build_phases.move(embed_phase, thin_binary_index)
else
  warn 'WARNING: "Thin Binary" phase not found — Embed App Extensions left at end'
end
```

### LO-03: Ошибки `startVpn`/`stopVpn` не пробрасываются через Pigeon `Result` (by design)

**File:** `ios/Runner/Bridge/VpnHostApiImpl.swift:27,32,48,56,62,64,85`
**Issue:** Все ветки, включая ошибочные, завершаются `completion(.success(()))`; сбой доводится только
через event-стрим (`ErrorMessage` + `StatusChanged(.error)`). Это осознанный контракт
(`startVpn = Future<void>`, ошибки через шину событий) и не проглатывание — событие эмитится. Отмечаю
для сведения вызывающих: Dart-`await startVpn()` никогда не бросит `PlatformException` на NE-ошибке,
статус ошибки надо ловить исключительно подпиской на стрим.
**Fix:** не требуется (соответствует дизайну); зафиксировать в README, что клиент обязан слушать
`VpnError`/`StatusChanged(.error)`, не полагаясь на исход `Future`.

---

_Reviewed: 2026-07-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
