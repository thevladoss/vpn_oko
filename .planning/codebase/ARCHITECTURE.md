# Architecture

Целевая архитектура (детали и паттерны — `.planning/research/ARCHITECTURE.md`; state management скорректирован решением пользователя: Bloc вместо Riverpod).

## Слои

```
Flutter presentation (widgets + Bloc)
        │ events                ▲ states
Flutter domain (usecases, entities, repository interfaces)
        │ interface             ▲ Stream<VpnState>/Stream<LogEntry>
Flutter data (repository impl, mappers, datasource)
        │                       ▲
core/bridge/VpnBridge (единственный владелец Pigeon-стрима, демультиплексор)
        │ VpnHostApi            ▲ vpnEvents(): Stream<VpnEventMessage>
Pigeon generated (Dart / Kotlin / Swift)
        │                       ▲
Android: MainActivity → OkoVpnService     iOS: AppDelegate → NETunnelProviderManager
  (VpnService, state machine, Builder,      (VpnHostApiImpl, NEVPNStatus observer)
   Foreground notification, TUN read-loop,          │
   onRevoke, VpnEventBus SharedFlow)          PacketTunnelProvider (NE extension)
```

## Структура

- `pigeons/vpn_api.dart` — контракт: VpnHostApi (startVpn/stopVpn/getStatus), @EventChannelApi vpnEvents, sealed VpnEventMessage
- `lib/app/` — MaterialApp, тема, composition root (di)
- `lib/core/bridge/` — vpn_api.g.dart + VpnBridge; `lib/core/error/` — Failure-типы; `lib/core/theme/` — темы из DESIGN.md
- `lib/features/vpn_connection/` — domain (VpnState, VpnConfig, TrafficStats, VpnRepository, usecases), data (datasource, mappers, repository impl), presentation (VpnConnectionBloc, экран, виджеты: ирис-индикатор, кнопка, таймер, трафик)
- `lib/features/vpn_logs/` — domain (LogEntry, LogRepository), data, presentation (LogsBloc, панель логов)
- `lib/features/server_config/` — VLESS-парсер, VlessConfig, карточка сервера, tcping
- `android/app/src/main/kotlin/` — VpnApi.g.kt, VpnHostApiImpl, VpnEventStreamHandler, OkoVpnService, VpnEventBus, ConnectionStateMachine
- `ios/Runner/` — VpnApi.g.swift, VpnHostApiImpl, StreamHandler; `ios/PacketTunnel/` — NE-таргет с PacketTunnelProvider; App Group между ними

## Ключевые правила

- Native — источник истины по статусу; Flutter восстанавливается через getStatus() (снапшот: status, connectedSince, счётчики) + replay последнего статуса
- Один event channel на все события; на стрим подписывается только VpnBridge
- Порядок сборки: контракт Pigeon → domain → Android-сервис → data → presentation → VLESS → iOS → подача
