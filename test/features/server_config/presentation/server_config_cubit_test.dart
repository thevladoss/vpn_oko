import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_oko/features/server_config/domain/entities/latency_result.dart';
import 'package:vpn_oko/features/server_config/domain/entities/vless_config.dart';
import 'package:vpn_oko/features/server_config/domain/entities/vless_parse_result.dart';
import 'package:vpn_oko/features/server_config/domain/repositories/latency_probe.dart';
import 'package:vpn_oko/features/server_config/presentation/cubit/server_config_cubit.dart';
import 'package:vpn_oko/features/server_config/presentation/cubit/server_config_state.dart';

import '../../../helpers/fake_clipboard_source.dart';
import '../../../helpers/fake_latency_probe.dart';

class _GatedProbe implements LatencyProbe {
  _GatedProbe(this._gate);

  final Completer<void> _gate;

  @override
  Future<LatencyResult> measure(String host, int port) async {
    await _gate.future;
    return const LatencyMeasured(Duration(milliseconds: 10));
  }
}

const _validLink =
    'vless://b831381d-6324-4d53-ad4f-8cda48b30811@example.com:443'
    '?type=tcp&security=reality&sni=www.microsoft.com#Tokyo';

const _expectedConfig = VlessConfig(
  uuid: 'b831381d-6324-4d53-ad4f-8cda48b30811',
  host: 'example.com',
  port: 443,
  transport: 'tcp',
  security: 'reality',
  sni: 'www.microsoft.com',
  name: 'Tokyo',
);

void main() {
  late FakeClipboardSource clipboard;
  late FakeLatencyProbe probe;

  setUp(() {
    clipboard = FakeClipboardSource();
    probe = FakeLatencyProbe();
  });

  blocTest<ServerConfigCubit, ServerConfigState>(
    'blank clipboard emits error(empty) and never measures',
    build: () {
      clipboard.textToReturn = '   ';
      return ServerConfigCubit(clipboard: clipboard, probe: probe);
    },
    act: (cubit) => cubit.pasteFromClipboard(),
    expect: () => const [ServerConfigError(VlessError.empty)],
    verify: (_) => expect(probe.measureCallCount, 0),
  );

  blocTest<ServerConfigCubit, ServerConfigState>(
    'valid link emits loaded then loaded with measured latency',
    build: () {
      clipboard.textToReturn = _validLink;
      probe.resultToReturn = const LatencyMeasured(Duration(milliseconds: 56));
      return ServerConfigCubit(clipboard: clipboard, probe: probe);
    },
    act: (cubit) => cubit.pasteFromClipboard(),
    expect: () => const [
      ServerConfigLoaded(_expectedConfig),
      ServerConfigLoaded(
        _expectedConfig,
        latency: LatencyMeasured(Duration(milliseconds: 56)),
      ),
    ],
    verify: (_) {
      expect(probe.measureCallCount, 1);
      expect(probe.lastHost, 'example.com');
      expect(probe.lastPort, 443);
    },
  );

  blocTest<ServerConfigCubit, ServerConfigState>(
    'valid link emits loaded then loaded with unreachable latency',
    build: () {
      clipboard.textToReturn = _validLink;
      probe.resultToReturn = const LatencyUnreachable();
      return ServerConfigCubit(clipboard: clipboard, probe: probe);
    },
    act: (cubit) => cubit.pasteFromClipboard(),
    expect: () => const [
      ServerConfigLoaded(_expectedConfig),
      ServerConfigLoaded(_expectedConfig, latency: LatencyUnreachable()),
    ],
  );

  blocTest<ServerConfigCubit, ServerConfigState>(
    'invalid scheme emits error(scheme) and never measures',
    build: () {
      clipboard.textToReturn = 'https://example.com';
      return ServerConfigCubit(clipboard: clipboard, probe: probe);
    },
    act: (cubit) => cubit.pasteFromClipboard(),
    expect: () => const [ServerConfigError(VlessError.scheme)],
    verify: (_) => expect(probe.measureCallCount, 0),
  );

  blocTest<ServerConfigCubit, ServerConfigState>(
    'сбой чтения буфера деградирует в error(malformed), measure не зовётся',
    build: () {
      clipboard.errorToThrow = Exception('clipboard denied');
      return ServerConfigCubit(clipboard: clipboard, probe: probe);
    },
    act: (cubit) => cubit.pasteFromClipboard(),
    expect: () => const [ServerConfigError(VlessError.malformed)],
    verify: (_) => expect(probe.measureCallCount, 0),
  );

  blocTest<ServerConfigCubit, ServerConfigState>(
    'исключение пробы деградирует в loaded(unreachable), поток не падает',
    build: () {
      clipboard.textToReturn = _validLink;
      probe.errorToThrow = Exception('probe boom');
      return ServerConfigCubit(clipboard: clipboard, probe: probe);
    },
    act: (cubit) => cubit.pasteFromClipboard(),
    expect: () => const [
      ServerConfigLoaded(_expectedConfig),
      ServerConfigLoaded(_expectedConfig, latency: LatencyUnreachable()),
    ],
  );

  test('close во время measure не бросает StateError и не эмитит после close',
      () async {
    final gate = Completer<void>();
    final gatedProbe = _GatedProbe(gate);
    final gatedClipboard = FakeClipboardSource(textToReturn: _validLink);
    final cubit = ServerConfigCubit(
      clipboard: gatedClipboard,
      probe: gatedProbe,
    );
    final states = <ServerConfigState>[];
    final sub = cubit.stream.listen(states.add);

    final future = cubit.pasteFromClipboard();
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    gate.complete();
    await future;
    await sub.cancel();

    final withLatency = states.whereType<ServerConfigLoaded>().where(
          (s) => s.latency != null,
        );
    expect(withLatency, isEmpty);
  });
}
