import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:nhac/pages/feed_page.dart';
import 'package:nhac/services/api_client.dart';

class FeedAdapter implements HttpClientAdapter {
  bool fail = true;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.path, '/feed/posts');
    calls++;
    return ResponseBody.fromString(
      fail ? '{"message":"offline"}' : '{"content":[],"last":true}',
      fail ? 503 : 200,
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

  testWidgets(
    'feed integrado preserva publicação e notificações e recupera falha',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080/api/v1');
      final adapter = FeedAdapter();
      final api = ApiClient();
      final oldAdapter = api.dio.httpClientAdapter;
      api.dio.httpClientAdapter = adapter;
      api.atualizarTokenCache('test-token');
      addTearDown(() {
        api.dio.httpClientAdapter = oldAdapter;
        api.atualizarTokenCache(null);
      });
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: FeedPage()),
          ),
          GoRoute(
            path: '/feed-publicar',
            builder: (_, __) =>
                const Scaffold(body: Text('Formulário de publicação')),
          ),
        ],
      );
      addTearDown(router.dispose);

      Future<void> advance() async {
        // The banner carousel and shimmer intentionally animate continuously.
        for (var frame = 0; frame < 10; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, __) => MaterialApp.router(routerConfig: router),
          ),
        );
        await advance();
        expect(adapter.calls, 1);
        expect(find.byTooltip('Criar publicação'), findsOneWidget);
        expect(find.byTooltip('Notificações'), findsOneWidget);
        expect(find.textContaining('Prévia do Feed'), findsNothing);
        expect(find.text('Não foi possível carregar o feed.'), findsOneWidget);
        expect(find.text('Nenhum post por aqui ainda.'), findsNothing);

        adapter.fail = false;
        await tester.ensureVisible(find.text('Tentar novamente'));
        await tester.tap(find.text('Tentar novamente'));
        await advance();
        expect(adapter.calls, 2);
        expect(find.text('Nenhum post por aqui ainda.'), findsOneWidget);
        expect(find.text('Não foi possível carregar o feed.'), findsNothing);

        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await advance();
        await tester.tap(find.byTooltip('Criar publicação'));
        await advance();
        expect(find.text('Formulário de publicação'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await advance();
      });
    },
  );
}
