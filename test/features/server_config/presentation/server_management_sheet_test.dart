import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vpn_oko/core/theme/oko_theme.dart';
import 'package:vpn_oko/features/server_config/domain/entities/add_server_outcome.dart';
import 'package:vpn_oko/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_oko/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_oko/features/server_config/domain/repositories/server_repository.dart';
import 'package:vpn_oko/features/server_config/presentation/cubit/server_list_cubit.dart';
import 'package:vpn_oko/features/server_config/presentation/screens/server_management_sheet.dart';
import 'package:vpn_oko/features/server_config/presentation/widgets/server_list_tile.dart';

import '../../../helpers/fake_clipboard_source.dart';

class MockServerRepository extends Mock implements ServerRepository {}

const _fakeUuid = 'deadbeef-1111-2222-3333-444455556666';

const _tokyoLink =
    'vless://$_fakeUuid@tokyo.example:443'
    '?type=tcp&security=reality&sni=www.microsoft.com#Tokyo';

const _tokyoConfig = VlessConfig(
  uuid: _fakeUuid,
  host: 'tokyo.example',
  port: 443,
  transport: 'tcp',
  security: 'reality',
  sni: 'www.microsoft.com',
  name: 'Tokyo',
);

const _osakaConfig = VlessConfig(
  uuid: _fakeUuid,
  host: 'osaka.example',
  port: 8443,
  transport: 'tcp',
  security: 'reality',
  name: 'Osaka',
);

final _tokyo = ServerProfile(
  id: 1,
  label: 'Tokyo',
  config: _tokyoConfig,
  rawUrl: _tokyoLink,
  createdAt: DateTime(2026, 7, 14),
);

final _osaka = ServerProfile(
  id: 2,
  label: 'Osaka',
  config: _osakaConfig,
  rawUrl: 'vless://$_fakeUuid@osaka.example:8443#Osaka',
  createdAt: DateTime(2026, 7, 15),
);

void main() {
  setUpAll(() {
    registerFallbackValue(_tokyoConfig);
  });

  late MockServerRepository repository;
  late FakeClipboardSource clipboard;
  late ServerListCubit cubit;

  setUp(() {
    repository = MockServerRepository();
    clipboard = FakeClipboardSource();
  });

  tearDown(() async {
    await cubit.close();
  });

  ServerListCubit makeCubit({
    List<ServerProfile> servers = const [],
    ServerProfile? active,
  }) {
    when(repository.watchAll).thenAnswer((_) => Stream.value(servers));
    when(repository.watchActive).thenAnswer((_) => Stream.value(active));
    return ServerListCubit(repository: repository, clipboard: clipboard);
  }

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OkoTheme.dark,
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: ServerManagementSheet()),
        ),
      ),
    );
    await tester.pump();
  }

  group('ServerManagementSheet', () {
    testWidgets('рендерит список профилей с label и host:port', (tester) async {
      cubit = makeCubit(servers: [_tokyo, _osaka]);
      await pumpSheet(tester);

      expect(find.text('Tokyo'), findsOneWidget);
      expect(find.text('Osaka'), findsOneWidget);
      expect(find.textContaining('tokyo.example:443'), findsOneWidget);
      expect(find.textContaining('osaka.example:8443'), findsOneWidget);
    });

    testWidgets('помечает активный профиль индикатором', (tester) async {
      cubit = makeCubit(servers: [_tokyo, _osaka], active: _tokyo);
      await pumpSheet(tester);

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('показывает пустое состояние без серверов', (tester) async {
      cubit = makeCubit();
      await pumpSheet(tester);

      expect(find.text('Добавьте первый сервер'), findsOneWidget);
      expect(find.byType(ServerListTile), findsNothing);
    });

    testWidgets('маскирует секреты: uuid не попадает в дерево', (tester) async {
      cubit = makeCubit(servers: [_tokyo, _osaka], active: _tokyo);
      await pumpSheet(tester);

      expect(find.textContaining(_fakeUuid), findsNothing);
      expect(find.textContaining('deadbeef'), findsNothing);
    });

    testWidgets('вставка из буфера сохраняет сервер и показывает notice', (
      tester,
    ) async {
      clipboard.textToReturn = _tokyoLink;
      when(() => repository.add(any(), any()))
          .thenAnswer((_) async => ServerSaved(_tokyo));
      cubit = makeCubit();
      await pumpSheet(tester);

      await tester.tap(find.text('Вставить из буфера'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      verify(() => repository.add(any(), any())).called(1);
      expect(find.textContaining('сохранён'), findsOneWidget);
    });

    testWidgets('кривая ссылка из буфера показывает ошибку', (tester) async {
      clipboard.textToReturn = 'not-a-url';
      cubit = makeCubit();
      await pumpSheet(tester);

      await tester.tap(find.text('Вставить из буфера'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      verifyNever(() => repository.add(any(), any()));
      expect(find.text('Неподдерживаемая ссылка'), findsOneWidget);
    });

    testWidgets('удаление профиля запрашивает подтверждение и зовёт delete', (
      tester,
    ) async {
      when(() => repository.delete(any())).thenAnswer((_) async {});
      cubit = makeCubit(servers: [_tokyo]);
      await pumpSheet(tester);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
      await tester.pump();

      verify(() => repository.delete(1)).called(1);
    });
  });
}
