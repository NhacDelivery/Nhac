import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:nhac/pages/feed_page.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:provider/provider.dart';

class _Auth extends Mock implements AuthService {}

class _MockAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<dynamic>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = {
      'content': [],
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late HttpClientAdapter oldAdapter;

  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080/api/v1');
    auth = _Auth();
    when(() => auth.usuarioId).thenReturn('u1');
    oldAdapter = ApiClient().dio.httpClientAdapter;
    ApiClient().dio.httpClientAdapter = _MockAdapter();
  });

  tearDown(() {
    ApiClient().dio.httpClientAdapter = oldAdapter;
  });

  testWidgets(
    'Categorias do Feed exibem ActionChips estilizados com BouncingScrollPhysics',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthService>.value(
            value: auth,
            child: ScreenUtilInit(
              designSize: const Size(800, 600),
              builder: (_, __) => const MaterialApp(
                home: Scaffold(body: FeedPage()),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Destaques'), findsOneWidget);
        expect(find.text('Em Alta'), findsOneWidget);
        expect(find.text('Promoções'), findsOneWidget);
        expect(find.text('Novidades'), findsOneWidget);

        final chips = find.byType(ActionChip);
        expect(chips, findsNWidgets(4));

        final listViews = tester.widgetList<ListView>(find.byType(ListView));
        final horizontalListView = listViews.firstWhere(
          (lv) => lv.scrollDirection == Axis.horizontal,
        );
        expect(horizontalListView.physics, isA<BouncingScrollPhysics>());

        // O primeiro chip (Destaques) deve iniciar selecionado (coral)
        final firstChip = tester.widget<ActionChip>(chips.first);
        expect(firstChip.backgroundColor, const Color(0xFFFF6961));
        final shape = firstChip.shape as RoundedRectangleBorder;
        expect(shape.borderRadius, isA<BorderRadius>());

        // O segundo chip (Em Alta) deve iniciar não-selecionado (fundo branco)
        final secondChip = tester.widget<ActionChip>(chips.at(1));
        expect(secondChip.backgroundColor, Colors.white);

        // Ao tocar em 'Em Alta'
        await tester.tap(find.text('Em Alta'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final secondChipAfter = tester.widget<ActionChip>(find.byType(ActionChip).at(1));
        expect(secondChipAfter.backgroundColor, const Color(0xFFFF6961));
      });
    },
  );
}
