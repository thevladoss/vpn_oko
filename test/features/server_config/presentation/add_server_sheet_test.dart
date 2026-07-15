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
import 'package:vpn_oko/features/server_config/presentation/widgets/add_server_sheet.dart';
import 'package:vpn_oko/features/server_config/presentation/widgets/protocol_badge.dart';

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

final _tokyo = ServerProfile(
  id: 1,
  label: 'Tokyo',
  config: _tokyoConfig,
  rawUrl: _tokyoLink,
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

  ServerListCubit makeCubit() {
    when(repository.watchAll).thenAnswer((_) => Stream.value(const []));
    when(repository.watchActive).thenAnswer((_) => Stream.value(null));
    return ServerListCubit(repository: repository, clipboard: clipboard);
  }

  Future<void> pumpSheet(
    WidgetTester tester, {
    required ThemeData theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: AddServerSheet()),
        ),
      ),
    );
    await tester.pump();
  }

  group('AddServerSheet', () {
    testWidgets('открывается в режиме вставки с полем и кнопкой буфера', (
      tester,
    ) async {
      cubit = makeCubit();
      await pumpSheet(tester, theme: OkoTheme.dark);

      expect(find.text('Добавить сервер'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Вставить из буфера'), findsOneWidget);
    });

    testWidgets('кнопка «Добавить» неактивна без валидной ссылки', (
      tester,
    ) async {
      cubit = makeCubit();
      await pumpSheet(tester, theme: OkoTheme.dark);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Добавить'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('валидная ссылка даёт превью с бейджем и маскировкой', (
      tester,
    ) async {
      cubit = makeCubit();
      await pumpSheet(tester, theme: OkoTheme.dark);

      await tester.enterText(find.byType(TextField), _tokyoLink);
      await tester.pumpAndSettle();

      expect(find.byType(ProtocolBadge), findsOneWidget);
      expect(find.text('VLESS'), findsOneWidget);
      expect(find.text('tokyo.example:443'), findsOneWidget);
      expect(find.text('••••6666'), findsOneWidget);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Добавить'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets(
      'кривая ссылка показывает доменную ошибку, не сырое исключение',
      (tester) async {
        cubit = makeCubit();
        await pumpSheet(tester, theme: OkoTheme.dark);

        await tester.enterText(find.byType(TextField), 'not-a-url');
        await tester.pumpAndSettle();

        expect(find.text('Неподдерживаемая ссылка'), findsOneWidget);
        expect(find.byType(ProtocolBadge), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('вставка из буфера заполняет поле и показывает превью', (
      tester,
    ) async {
      clipboard.textToReturn = _tokyoLink;
      cubit = makeCubit();
      await pumpSheet(tester, theme: OkoTheme.dark);

      await tester.tap(find.text('Вставить из буфера'));
      await tester.pumpAndSettle();

      expect(find.byType(ProtocolBadge), findsOneWidget);
    });

    testWidgets('«Добавить» сохраняет через cubit при валидной ссылке', (
      tester,
    ) async {
      when(
        () => repository.add(any(), any()),
      ).thenAnswer((_) async => ServerSaved(_tokyo));
      cubit = makeCubit();
      await pumpSheet(tester, theme: OkoTheme.dark);

      await tester.enterText(find.byType(TextField), _tokyoLink);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      verify(() => repository.add(any(), any())).called(1);
    });

    testWidgets('рендерится в светлой теме', (tester) async {
      cubit = makeCubit();
      await pumpSheet(tester, theme: OkoTheme.light);

      expect(find.text('Добавить сервер'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
