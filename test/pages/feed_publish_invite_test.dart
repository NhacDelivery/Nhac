import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/components/feed_publish_invite.dart';
import 'package:nhac/components/home/home_banner_carousel.dart';
import 'package:nhac/globals/themes.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/pages/feed_page.dart';
import 'package:nhac/services/api_client.dart';

class _FeedAdapter implements HttpClientAdapter {
  bool fail = false;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    // O topo do feed não deve buscar categorias ou imagens do catálogo.
    expect(options.path, anyOf('/feed/posts', '/feed/posts/salvos'));
    calls++;
    return ResponseBody.fromString(
      jsonEncode(fail ? {'message': 'offline'} : {'content': []}),
      fail ? 503 : 200,
      headers: {
        Headers.contentTypeHeader: ['application/json']
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final font = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await font.load();
    await icons.load();
  });

  testWidgets('convite permite teclado e texto ampliado sem cortar a ação',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: lightTheme,
      home: Scaffold(
        backgroundColor: const Color(0xFFFFE7E5),
        body: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: FeedPublishInvite(onPublish: () => taps++),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final action = find.byWidgetPredicate((widget) => widget is OutlinedButton);
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      await expectLater(find.byType(Scaffold),
          matchesGoldenFile('goldens/feed-convite-texto-ampliado.png'));
    }
  });

  for (final fail in [false, true]) {
    testWidgets('publicar funciona com feed ${fail ? 'em erro' : 'vazio'}',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080/api/v1');
      final api = ApiClient();
      final oldAdapter = api.dio.httpClientAdapter;
      final adapter = _FeedAdapter()..fail = fail;
      api.dio.httpClientAdapter = adapter;
      api.atualizarTokenCache('test-token');
      addTearDown(() {
        api.dio.httpClientAdapter = oldAdapter;
        api.atualizarTokenCache(null);
      });
      final router = GoRouter(routes: [
        GoRoute(
            path: '/', builder: (_, __) => const Scaffold(body: FeedPage())),
        GoRoute(
            path: '/feed-publicar',
            builder: (context, _) => Scaffold(
                  body: Column(children: [
                    TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('Voltar sem publicar')),
                    TextButton(
                        onPressed: () => context.pop(FeedPostModel.fromMap({
                              'id': 'novo',
                              'conteudo': 'Meu prato',
                              'nomeUsuario': 'Cliente',
                              'curtidas': 0,
                              'comentarios': 0,
                            })),
                        child: const Text('Concluir publicação')),
                  ]),
                )),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) =>
            MaterialApp.router(theme: lightTheme, routerConfig: router),
      ));
      Future<void> frames() async {
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(tester.takeException(), isNull);
      }

      await frames();
      expect(find.byType(HomeBannerCarousel), findsNothing);
      expect(find.byType(FeedPublishInvite), findsOneWidget);
      expect(adapter.calls, 1);
      if (const bool.fromEnvironment('CAPTURE_UI')) {
        await expectLater(find.byType(Scaffold),
            matchesGoldenFile('goldens/feed-${fail ? 'erro' : 'vazio'}.png'));
      }
      final action =
          find.byWidgetPredicate((widget) => widget is OutlinedButton);
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voltar sem publicar'));
      await tester.pumpAndSettle();
      expect(adapter.calls, 1);
      await tester.tap(action);
      await tester.pumpAndSettle();
      adapter.fail = false;
      await tester.tap(find.text('Concluir publicação'));
      await frames();
      expect(adapter.calls, 2);
      expect(find.text('Publicação criada.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
