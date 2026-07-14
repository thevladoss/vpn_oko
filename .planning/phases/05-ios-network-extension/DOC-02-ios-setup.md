# iOS Network Extension — setup и запуск (handoff для README, DOC-02)

Заметка для фазы 6 (README-раздел iOS). Описывает capabilities, entitlements, App Groups, взаимодействие app ↔ extension и ограничение симулятора.

## Архитектура iOS

```
Runner.app (контейнер)                    PacketTunnel.appex (extension-процесс)
  AppDelegate (FlutterImplicitEngine)       PacketTunnelProvider : NEPacketTunnelProvider
  Bridge/VpnHostApiImpl.swift                 startTunnel → setTunnelNetworkSettings
    NETunnelProviderManager                     (NEPacketTunnelNetworkSettings +
    load → save → loadFromPreferences →          NEIPv4Settings узкий маршрут 10.111.222.0/24)
    connection.startVPNTunnel/stopVPNTunnel     stopTunnel
  Bridge/VpnStatusObserver.swift
    NEVPNStatusDidChange → VpnStatusMessage
  Bridge/VpnEventListener.swift (main-queue emit) → Pigeon EventChannel → Flutter
       │ App Group: group.com.example.vpnOko (обмен app ↔ extension)
```

## Bundle identifiers
- Контейнер: `com.example.vpnOko`
- Extension: `com.example.vpnOko.PacketTunnel`
- App Group: `group.com.example.vpnOko`

## Capabilities / Entitlements
Оба таргета несут (`ios/Runner/Runner.entitlements`, `ios/PacketTunnel/PacketTunnel.entitlements`):
- `com.apple.developer.networking.networkextension` → `packet-tunnel-provider`
- `com.apple.security.application-groups` → `group.com.example.vpnOko`

Extension Info.plist (`ios/PacketTunnel/Info.plist`):
- `NSExtensionPointIdentifier` = `com.apple.networkextension.packet-tunnel` (без `-provider`)
- `NSExtensionPrincipalClass` = `$(PRODUCT_MODULE_NAME).PacketTunnelProvider`

## Готовность к TestFlight (шаги пользователя)
1. В Apple Developer portal зарегистрировать два App ID: `com.example.vpnOko` и `com.example.vpnOko.PacketTunnel`, включить у обоих capability Network Extensions и App Groups (`group.com.example.vpnOko`).
2. Provisioning profiles для обоих таргетов (team `Z2GDTXHVZZ` уже прописан в проекте).
3. `flutter build ipa` (или Xcode Archive схемы Runner) → загрузка в App Store Connect → TestFlight.
4. На устройстве: установить из TestFlight, дать VPN-разрешение, Connect.

## Ограничение симулятора (важно)
iOS Simulator **не хостит packet-tunnel Network Extension**: `simctl install` приложения со встроенным NE-appex падает с `Invalid placeholder attributes`. Это ограничение платформы Apple, не проекта. Поэтому:
- **Автоматически проверено**: обе цели (Runner + PacketTunnel.appex) компилируются под device и simulator; строки bundle id / entitlements / App Group корректны; Dart-маппинг NE-статусов и ошибок покрыт unit-тестами.
- **Проверяется на устройстве (TestFlight)**: реальный старт туннеля через `NETunnelProviderManager` → `PacketTunnelProvider.startTunnel`, применение `NEPacketTunnelNetworkSettings`, доведение `NEVPNStatus` до Flutter-экрана.
- На симуляторе Swift-мост исполняет честный путь ошибки: `connecting → error` + лог «Network Extension недоступен в симуляторе» (доказывает реальный вызов `NETunnelProviderManager.loadAllFromPreferences`).

## Что написано самостоятельно / что системное
- Самостоятельно: `PacketTunnelProvider.swift` (skeleton туннеля с узким маршрутом), `VpnHostApiImpl.swift` (реальный NETunnelProviderManager-флоу), `VpnStatusObserver.swift` (NEVPNStatus→Flutter), entitlements, `scripts/add_packet_tunnel_target.rb` (добавление NE-таргета через гем xcodeproj).
- Системное/сгенерированное: `Messages.g.swift` (Pigeon-кодоген), framework `NetworkExtension` (Apple).
