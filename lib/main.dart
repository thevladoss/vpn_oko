import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vpn_oko/app/app.dart';
import 'package:vpn_oko/app/di.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_config.dart';
import 'package:vpn_oko/features/vpn_connection/domain/entities/vpn_state.dart';
import 'package:vpn_oko/features/vpn_logs/domain/entities/log_entry.dart';

const VpnConfig _demoConfig = VpnConfig(
  host: 'echo.oko.vpn',
  port: 443,
  userId: '00000000-0000-0000-0000-000000000000',
  serverName: 'Echo Server',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = AppDependencies();
  unawaited(dependencies.syncStatus());
  runApp(OkoApp(home: DebugHarness(dependencies: dependencies)));
}

class DebugHarness extends StatefulWidget {
  const DebugHarness({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  State<DebugHarness> createState() => _DebugHarnessState();
}

class _DebugHarnessState extends State<DebugHarness> {
  final List<LogEntry> _logs = <LogEntry>[];
  late final Stream<VpnState> _stateStream;
  StreamSubscription<LogEntry>? _logSubscription;

  @override
  void initState() {
    super.initState();
    _stateStream = widget.dependencies.watchVpnState();
    _logSubscription = widget.dependencies.watchLogs().listen(_onLog);
  }

  void _onLog(LogEntry entry) {
    if (!mounted) {
      return;
    }
    setState(() => _logs.insert(0, entry));
  }

  @override
  void dispose() {
    unawaited(_logSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oko VPN — echo harness')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder<VpnState>(
              stream: _stateStream,
              builder: (context, snapshot) =>
                  Text('Status: ${_describeState(snapshot.data)}'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        unawaited(widget.dependencies.connectVpn(_demoConfig)),
                    child: const Text('Echo Connect'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        unawaited(widget.dependencies.disconnectVpn()),
                    child: const Text('Echo Disconnect'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Logs:'),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final entry = _logs[index];
                  return Text('[${entry.level.name}] ${entry.text}');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _describeState(VpnState? state) => switch (state) {
      null => '—',
      VpnDisconnected() => 'Disconnected',
      VpnConnecting() => 'Connecting',
      VpnConnected(:final connectedSince) => 'Connected since $connectedSince',
      VpnDisconnecting() => 'Disconnecting',
      VpnError(:final message) => 'Error: $message',
    };
