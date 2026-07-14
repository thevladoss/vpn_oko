# Plan 05-03 Summary — Phase-gate iOS + device/TestFlight checkpoint

**Plan:** 05-03 (auto phase-gate + checkpoint:human-verify device)
**Status:** complete (автогейт зелёный; реальный туннель — TestFlight-checkpoint для пользователя)
**Requirements:** IOS-01, IOS-02, IOS-03, IOS-04
**Self-Check:** PASSED

## Task 1 — автогейт (прогнан оркестратором)

| Проверка | Результат |
|----------|-----------|
| `flutter build ios --no-codesign --debug` (device) | ✅ Built Runner.app + встроенный PacketTunnel.appex |
| `flutter build ios --simulator --debug` | ✅ Built (симулятор-ветка честного error-path компилируется) |
| `flutter test` | ✅ 147/147 (Dart-маппинг NE-статусов/ошибок в domain) |
| `flutter analyze` | ✅ No issues |
| Grep bundle id `com.example.vpnOko.PacketTunnel` | ✅ 2 файла |
| Grep `com.apple.networkextension.packet-tunnel` (без -provider) в appex Info.plist | ✅ присутствует |
| Grep App Group `group.com.example.vpnOko` | ✅ 2 файла |
| Grep неверный `com.example.vpn_oko` | ✅ 0 (отсутствует) |
| Entitlements обоих таргетов с `packet-tunnel-provider` | ✅ Runner.entitlements + PacketTunnel.entitlements |
| appex Info.plist: BundleIdentifier/ExtensionPoint/PrincipalClass | ✅ com.example.vpnOko.PacketTunnel / com.apple.networkextension.packet-tunnel / PacketTunnel.PacketTunnelProvider |

DOC-02 handoff-заметка для README (фаза 6) создана: `DOC-02-ios-setup.md`.

## Task 2 — device/TestFlight checkpoint (граница ручной проверки пользователя)

### Подтверждённое оркестратором ограничение платформы
iOS Simulator **не хостит packet-tunnel Network Extension**: `xcrun simctl install` приложения со встроенным NE-appex падает с `Invalid placeholder attributes / Failed to create app extension placeholder for PacketTunnel.appex`. Это ограничение Apple (packet-tunnel-provider не исполняется в симуляторе), не дефект проекта. appex Info.plist корректен (плейсхолдеры резолвятся, principal class валиден).

### Что проверяет пользователь на устройстве через TestFlight
Реальный runtime NE недостижим на симуляторе — консолидируется в device-проверке (аккаунт Apple Developer есть):
1. **IOS-02**: Connect → `NETunnelProviderManager.startVPNTunnel` → `PacketTunnelProvider.startTunnel` → `NEPacketTunnelNetworkSettings` (узкий маршрут 10.111.222.0/24) применяются; иконка VPN в статус-баре.
2. **IOS-03**: смена `NEVPNStatus` из connection доходит до Flutter-экрана (ирис-индикатор проходит статусы).
3. **IOS-01 happy-path**: статусы/логи из Swift-слоя на устройстве (в симуляторе — честный error-path «NE недоступен в симуляторе»).
4. **IOS-04**: регистрация двух App ID + capabilities в portal, provisioning, archive, TestFlight-upload — по DOC-02-ios-setup.md.

## Требования — вердикт
- **IOS-01** ✅ реальный Swift-мост (NETunnelProviderManager) + честный симулятор error-path; код компилируется под device+simulator. Happy-path runtime — device.
- **IOS-02** ✅ NE-таргет PacketTunnel + startTunnel/setTunnelNetworkSettings компилируются и встраиваются; реальный старт — device.
- **IOS-03** ✅ VpnStatusObserver (NEVPNStatusDidChange) → VpnEventBus → Flutter реализован и компилируется; runtime-переходы — device.
- **IOS-04** ✅ entitlements/App Groups обоих таргетов присутствуют, компиляция проходит, строки корректны; portal/archive/TestFlight — шаги пользователя (DOC-02).

## Итог
iOS-сторона собрана полностью: реальный Network Extension таргет с PacketTunnelProvider, Swift-мост на NETunnelProviderManager, NEVPNStatus observer, entitlements/App Groups обоих таргетов, готовность к TestFlight. Всё автоматизируемое (компиляция обоих таргетов, корректность строк, Dart-маппинг) проверено оркестратором. Реальный туннель на устройстве — единственная позиция, требующая ручной проверки пользователя через TestFlight (симулятор NE не исполняет по дизайну Apple). Цель фазы 5 достигнута на автоматизируемом уровне; runtime-подтверждение — за пользователем.
