import 'package:mocktail/mocktail.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/connect_vpn.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/disconnect_vpn.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/sync_status.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/watch_traffic.dart';
import 'package:vpn_osin/features/vpn_connection/domain/usecases/watch_vpn_state.dart';

class MockWatchVpnState extends Mock implements WatchVpnState {}

class MockWatchTraffic extends Mock implements WatchTraffic {}

class MockConnectVpn extends Mock implements ConnectVpn {}

class MockDisconnectVpn extends Mock implements DisconnectVpn {}

class MockSyncStatus extends Mock implements SyncStatus {}
