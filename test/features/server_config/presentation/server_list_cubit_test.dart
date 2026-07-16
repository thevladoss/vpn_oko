import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vpn_osin/features/server_config/domain/entities/add_server_outcome.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_osin/features/server_config/domain/entities/proxy_parse_result.dart';
import 'package:vpn_osin/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/server_repository.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/server_list_cubit.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/server_list_state.dart';

import '../../../helpers/fake_clipboard_source.dart';

class MockServerRepository extends Mock implements ServerRepository {}

const _validLink =
    'vless://b831381d-6324-4d53-ad4f-8cda48b30811@example.com:443'
    '?type=tcp&security=reality&sni=www.microsoft.com#Tokyo';

const _config = VlessConfig(
  uuid: 'b831381d-6324-4d53-ad4f-8cda48b30811',
  host: 'example.com',
  port: 443,
  transport: 'tcp',
  security: 'reality',
  sni: 'www.microsoft.com',
  name: 'Tokyo',
);

final _profileA = ServerProfile(
  id: 1,
  label: 'Tokyo',
  config: _config,
  rawUrl: _validLink,
  createdAt: DateTime(2026, 7, 14),
);

final _profileB = ServerProfile(
  id: 2,
  label: 'Osaka',
  config: _config,
  rawUrl: 'vless://b831381d-6324-4d53-ad4f-8cda48b30811@osaka.example:443#Osaka',
  createdAt: DateTime(2026, 7, 15),
);

void main() {
  setUpAll(() {
    registerFallbackValue(_config);
  });

  late MockServerRepository repository;
  late FakeClipboardSource clipboard;
  late StreamController<List<ServerProfile>> allController;
  late StreamController<ServerProfile?> activeController;

  setUp(() {
    repository = MockServerRepository();
    clipboard = FakeClipboardSource();
    allController = StreamController<List<ServerProfile>>.broadcast();
    activeController = StreamController<ServerProfile?>.broadcast();
    when(repository.watchAll).thenAnswer((_) => allController.stream);
    when(repository.watchActive).thenAnswer((_) => activeController.stream);
  });

  tearDown(() async {
    await allController.close();
    await activeController.close();
  });

  ServerListCubit build() =>
      ServerListCubit(repository: repository, clipboard: clipboard);

  blocTest<ServerListCubit, ServerListState>(
    'подписка отражает список серверов и активный сервер',
    build: build,
    act: (_) async {
      allController.add([_profileA, _profileB]);
      await Future<void>.delayed(Duration.zero);
      activeController.add(_profileA);
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      ServerListState(servers: [_profileA, _profileB]),
      ServerListState(servers: [_profileA, _profileB], activeId: 1),
    ],
  );

  blocTest<ServerListCubit, ServerListState>(
    'addFromClipboard сохраняет валидный сервер и эмитит NoticeSaved',
    build: () {
      clipboard.textToReturn = _validLink;
      when(() => repository.add(any(), any()))
          .thenAnswer((_) async => ServerSaved(_profileA));
      return build();
    },
    act: (cubit) => cubit.addFromClipboard(),
    expect: () => const [ServerListState(notice: NoticeSaved('Tokyo'))],
    verify: (_) {
      final captured =
          verify(() => repository.add(captureAny(), captureAny())).captured;
      expect(captured.first, isA<VlessConfig>());
      expect(captured.last, _validLink);
    },
  );

  blocTest<ServerListCubit, ServerListState>(
    'addFromClipboard дубликат эмитит NoticeDuplicate, список не растёт',
    build: () {
      clipboard.textToReturn = _validLink;
      when(() => repository.add(any(), any()))
          .thenAnswer((_) async => ServerDuplicate(_profileA));
      return build();
    },
    act: (cubit) => cubit.addFromClipboard(),
    expect: () => const [ServerListState(notice: NoticeDuplicate('Tokyo'))],
    verify: (_) =>
        verify(() => repository.add(any(), any())).called(1),
  );

  blocTest<ServerListCubit, ServerListState>(
    'addFromClipboard кривая строка эмитит NoticeInvalid, add не зовётся',
    build: () {
      clipboard.textToReturn = 'not-a-url';
      return build();
    },
    act: (cubit) => cubit.addFromClipboard(),
    expect: () => const [
      ServerListState(notice: NoticeInvalid(ProxyParseError.unsupported)),
    ],
    verify: (_) => verifyNever(() => repository.add(any(), any())),
  );

  blocTest<ServerListCubit, ServerListState>(
    'addFromClipboard пустой буфер эмитит NoticeInvalid(empty), add не зовётся',
    build: () {
      clipboard.textToReturn = '   ';
      return build();
    },
    act: (cubit) => cubit.addFromClipboard(),
    expect: () =>
        const [ServerListState(notice: NoticeInvalid(ProxyParseError.empty))],
    verify: (_) => verifyNever(() => repository.add(any(), any())),
  );

  blocTest<ServerListCubit, ServerListState>(
    'addFromScan идёт тем же путём, что paste, и сохраняет сервер',
    build: () {
      when(() => repository.add(any(), any()))
          .thenAnswer((_) async => ServerSaved(_profileA));
      return build();
    },
    act: (cubit) => cubit.addFromScan(_validLink),
    expect: () => const [ServerListState(notice: NoticeSaved('Tokyo'))],
    verify: (_) {
      final captured =
          verify(() => repository.add(captureAny(), captureAny())).captured;
      expect(captured.first, isA<VlessConfig>());
      expect(captured.last, _validLink);
    },
  );

  blocTest<ServerListCubit, ServerListState>(
    'notice сбрасывается при следующем обновлении списка',
    build: () {
      clipboard.textToReturn = _validLink;
      when(() => repository.add(any(), any()))
          .thenAnswer((_) async => ServerSaved(_profileA));
      return build();
    },
    act: (cubit) async {
      await cubit.addFromClipboard();
      allController.add([_profileA]);
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const ServerListState(notice: NoticeSaved('Tokyo')),
      ServerListState(servers: [_profileA]),
    ],
  );

  test('setActive делегирует репозиторию', () async {
    when(() => repository.setActive(any())).thenAnswer((_) async {});
    final cubit = build();
    await cubit.setActive(7);
    verify(() => repository.setActive(7)).called(1);
    await cubit.close();
  });

  test('rename делегирует репозиторию', () async {
    when(() => repository.rename(any(), any())).thenAnswer((_) async {});
    final cubit = build();
    await cubit.rename(3, 'Berlin');
    verify(() => repository.rename(3, 'Berlin')).called(1);
    await cubit.close();
  });

  test('delete делегирует репозиторию', () async {
    when(() => repository.delete(any())).thenAnswer((_) async {});
    final cubit = build();
    await cubit.delete(5);
    verify(() => repository.delete(5)).called(1);
    await cubit.close();
  });

  test('ошибка setActive не роняет cubit', () async {
    when(() => repository.setActive(any())).thenThrow(Exception('boom'));
    final cubit = build();
    await cubit.setActive(1);
    expect(cubit.state, const ServerListState());
    await cubit.close();
  });
}
