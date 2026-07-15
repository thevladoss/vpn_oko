import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vpn_oko/core/theme/oko_theme.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/core/widgets/top_alert.dart';
import 'package:vpn_oko/features/server_config/domain/entities/add_server_outcome.dart';
import 'package:vpn_oko/features/server_config/domain/entities/proxy_config.dart';
import 'package:vpn_oko/features/server_config/domain/entities/server_profile.dart';
import 'package:vpn_oko/features/server_config/domain/repositories/server_repository.dart';
import 'package:vpn_oko/features/server_config/presentation/cubit/server_list_cubit.dart';
import 'package:vpn_oko/features/server_config/presentation/screens/server_management_sheet.dart';
import 'package:vpn_oko/features/server_config/presentation/widgets/empty_server_paste_field.dart';
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

      expect(find.byType(EmptyServerPasteField), findsOneWidget);
      expect(find.text('Добавьте свой первый сервер'), findsOneWidget);
      expect(find.byType(ServerListTile), findsNothing);
    });

    testWidgets('тап по пунктирному полю вставляет из буфера', (tester) async {
      clipboard.textToReturn = _tokyoLink;
      when(
        () => repository.add(any(), any()),
      ).thenAnswer((_) async => ServerSaved(_tokyo));
      cubit = makeCubit();
      await pumpSheet(tester);

      await tester.tap(find.byType(EmptyServerPasteField));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      verify(() => repository.add(any(), any())).called(1);
      expect(find.byType(TextField), findsNothing);
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
      when(
        () => repository.add(any(), any()),
      ).thenAnswer((_) async => ServerSaved(_tokyo));
      cubit = makeCubit();
      await pumpSheet(tester);

      await tester.tap(find.text('Вставить из буфера'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      verify(() => repository.add(any(), any())).called(1);
      expect(find.textContaining('сохранён'), findsOneWidget);
      final alert = tester.widget<TopAlert>(find.byType(TopAlert));
      expect(alert.kind, TopAlertKind.success);
      expect(alert.visible, isTrue);
      final icon = tester.widget<Icon>(
        find.descendant(of: find.byType(TopAlert), matching: find.byType(Icon)),
      );
      expect(icon.color, OkoTones.dark.accentConnected);
    });

    testWidgets('дубликат показывает красный алерт сверху без SnackBar', (
      tester,
    ) async {
      clipboard.textToReturn = _tokyoLink;
      when(
        () => repository.add(any(), any()),
      ).thenAnswer((_) async => ServerDuplicate(_tokyo));
      cubit = makeCubit();
      await pumpSheet(tester);

      await tester.tap(find.text('Вставить из буфера'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Такой сервер уже есть'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      final alert = tester.widget<TopAlert>(find.byType(TopAlert));
      expect(alert.kind, TopAlertKind.error);
      final icon = tester.widget<Icon>(
        find.descendant(of: find.byType(TopAlert), matching: find.byType(Icon)),
      );
      expect(icon.color, OkoTones.dark.accentError);

      final sheetTop = tester
          .getTopLeft(find.byKey(const ValueKey('sheet-bounds')))
          .dy;
      final sheetCenter = tester
          .getCenter(find.byKey(const ValueKey('sheet-bounds')))
          .dy;
      final alertCenter = tester.getCenter(find.byType(TopAlert)).dy;
      expect(alertCenter, greaterThanOrEqualTo(sheetTop));
      expect(alertCenter, lessThan(sheetCenter));
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

    testWidgets('свайп по тайлу и «Удалить» запрашивают подтверждение', (
      tester,
    ) async {
      when(() => repository.delete(any())).thenAnswer((_) async {});
      cubit = makeCubit(servers: [_tokyo]);
      await pumpSheet(tester);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ServerListTile), const Offset(-260, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
      await tester.pump();

      verify(() => repository.delete(1)).called(1);
    });

    testWidgets('высота шита ограничена, длинный список скроллится', (
      tester,
    ) async {
      final many = List<ServerProfile>.generate(
        20,
        (index) => ServerProfile(
          id: index + 1,
          label: 'Server ${index + 1}',
          config: _osakaConfig,
          rawUrl: 'vless://$_fakeUuid@osaka.example:8443#Server${index + 1}',
          createdAt: DateTime(2026, 7, 15),
        ),
      );
      cubit = makeCubit(servers: many);
      await pumpSheet(tester);
      await tester.pumpAndSettle();

      final appHeight = tester.getSize(find.byType(MaterialApp)).height;
      final sheetHeight = tester
          .getSize(find.byKey(const ValueKey('sheet-bounds')))
          .height;
      expect(sheetHeight, lessThanOrEqualTo(appHeight * 0.85 + 0.5));
      expect(sheetHeight, greaterThan(appHeight * 0.5));

      expect(find.text('Server 20'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Server 20'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Server 20'), findsOneWidget);
    });

    testWidgets('диалог переименования растягивает поле под длинное имя', (
      tester,
    ) async {
      const longName = 'Токийский сервер с очень длинным именем для проверки';
      final longProfile = ServerProfile(
        id: 7,
        label: longName,
        config: _tokyoConfig,
        rawUrl: _tokyoLink,
        createdAt: DateTime(2026, 7, 15),
      );
      when(() => repository.rename(any(), any())).thenAnswer((_) async {});
      cubit = makeCubit(servers: [longProfile]);
      await pumpSheet(tester);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ServerListTile), const Offset(-260, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Переименовать'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(longName),
        ),
        findsOneWidget,
      );
      final fieldWidth = tester.getSize(find.byType(TextField)).width;
      expect(fieldWidth, greaterThan(200));
    });

    testWidgets('диалог переименования открывается с полным именем и курсором '
        'в конце', (tester) async {
      const longName =
          'Токийский сервер с очень длинным именем для проверки курсора';
      final longProfile = ServerProfile(
        id: 8,
        label: longName,
        config: _tokyoConfig,
        rawUrl: _tokyoLink,
        createdAt: DateTime(2026, 7, 15),
      );
      when(() => repository.rename(any(), any())).thenAnswer((_) async {});
      cubit = makeCubit(servers: [longProfile]);
      await pumpSheet(tester);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ServerListTile), const Offset(-260, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Переименовать'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      final controller = field.controller!;
      expect(controller.text, longName);
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, longName.length);
    });
  });
}
