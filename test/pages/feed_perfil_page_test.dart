import 'dart:ui' as ui;
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/components/profile/banner_perfil.dart';
import 'package:nhac/components/profile/publicacoes_perfil.dart';
import 'package:nhac/globals/themes.dart';
import 'package:nhac/models/feed/feed_perfil_model.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/pages/feed_perfil_page.dart';
import 'package:nhac/pages/feed_images_page.dart';
import 'package:nhac/repositories/chat_repository.dart';
import 'package:nhac/repositories/feed_repository.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:provider/provider.dart';

class _FeedMock extends Mock implements FeedRepository {}

class _ChatMock extends Mock implements ChatRepository {}

class _AuthMock extends Mock implements AuthService {}

const _bannerUrl = 'https://example.com/banner-perfil.png';
const _fotoUrl = 'https://example.com/foto-perfil.png';
const _primeiraFoto = 'https://example.com/publicacao-1.png';
const _segundaFoto = 'https://example.com/publicacao-2.png';
const _outraFoto = 'https://example.com/publicacao-3.png';

FeedPostModel _post(
  String id,
  String texto, [
  List<String> imagens = const [],
]) {
  return FeedPostModel(
    id: id,
    usuarioId: 'autora',
    nomeUsuario: 'Ana',
    conteudo: texto,
    imagens: imagens,
    curtidas: 0,
    comentarios: 0,
  );
}

FeedPerfilModel _perfil(
  List<FeedPostModel> publicacoes, {
  bool temMais = false,
  bool podeEnviarMensagem = true,
  LojaParaMensagem? loja,
  String? bannerUrl = _bannerUrl,
  int? total,
}) {
  return FeedPerfilModel(
    id: 'autora',
    nome: 'Ana',
    avatarUrl: _fotoUrl,
    bannerUrl: bannerUrl,
    anoCadastro: 2025,
    totalPublicacoes: total,
    lojaParaMensagem: loja,
    podeEnviarMensagem: podeEnviarMensagem,
    publicacoes: publicacoes,
    temMais: temMais,
  );
}

Future<void> _imagem(WidgetTester tester, String url, Color cor) async {
  final image = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(cor, BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(4, 4);
    picture.dispose();
    return image;
  });
  PaintingBinding.instance.imageCache.putIfAbsent(
    CachedNetworkImageProvider(url),
    () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image!))),
  );
}

Finder _imagemComUrl(String url) => find.byWidgetPredicate(
  (widget) => widget is CachedNetworkImage && widget.imageUrl == url,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/fonts/Roboto.ttf'))).load();
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  Future<void> montar(
    WidgetTester tester,
    FeedRepository feed, {
    String meuId = 'leitor',
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _imagem(tester, _bannerUrl, const Color(0xFF1D5482));
    await _imagem(tester, _fotoUrl, const Color(0xFFF4B362));
    await _imagem(tester, _primeiraFoto, const Color(0xFFEBA16D));
    await _imagem(tester, _outraFoto, const Color(0xFF70A89A));
    final auth = _AuthMock();
    when(() => auth.usuarioId).thenReturn(meuId);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => FeedPerfilPage(
            usuarioId: 'autora',
            feedRepository: feed,
            chatRepository: _ChatMock(),
          ),
        ),
        GoRoute(
          path: '/chat-loja',
          builder: (_, state) {
            final dados = state.extra! as Map<String, dynamic>;
            return Scaffold(body: Text('Chat de ${dados['lojaId']}'));
          },
        ),
        GoRoute(
          path: '/feed-post',
          builder: (_, state) {
            final post = state.extra! as FeedPostModel;
            return Scaffold(
              body: Text('Publicação ${post.id}: ${post.imagens.length} fotos'),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: MaterialApp.router(theme: lightTheme, routerConfig: router),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('o banner mantém a cor original da imagem', (tester) async {
    const cor = Color(0xFF1D5482);
    const key = ValueKey('banner-sem-filtro');
    await _imagem(tester, _bannerUrl, cor);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 300,
              height: 200,
              child: BannerPerfil(
                url: _bannerUrl,
                sobreposicao: 40,
                child: SizedBox(width: 300, height: 200),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final pixel = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final offset = (20 * image.width + 20) * 4;
      image.dispose();
      return Color.fromARGB(
        data!.getUint8(offset + 3),
        data.getUint8(offset),
        data.getUint8(offset + 1),
        data.getUint8(offset + 2),
      );
    });
    expect(pixel, cor);
  });

  testWidgets(
    'grade mostra as fotos, os textos e abre a publicação com todas as imagens',
    (tester) async {
      final feed = _FeedMock();
      when(() => feed.buscarPerfil('autora', page: 0)).thenAnswer(
        (_) async => _perfil([
          _post('fotos', 'Meu almoço', [_primeiraFoto, _segundaFoto]),
          _post('texto', 'Uma publicação só com texto'),
          _post('outra', 'Pedido de hoje', [_outraFoto]),
        ]),
      );
      await montar(tester, feed);

      final primeira = tester.getRect(_imagemComUrl(_primeiraFoto));
      final outra = tester.getRect(_imagemComUrl(_outraFoto));
      expect(primeira.width, closeTo(primeira.height, 0.01));
      expect(outra.top, primeira.top);
      expect(outra.right, closeTo(390, 0.01));
      expect(find.text('Uma publicação só com texto'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_UI')) {
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/feed-perfil-grade.png'),
        );
      }
      await tester.tap(_imagemComUrl(_primeiraFoto));
      await tester.pumpAndSettle();
      expect(find.text('Publicação fotos: 2 fotos'), findsOneWidget);
    },
  );

  testWidgets('a grade mantém as publicações ao carregar a próxima página', (
    tester,
  ) async {
    final feed = _FeedMock();
    final primeiro = _post('foto', 'Meu almoço', [_primeiraFoto]);
    when(
      () => feed.buscarPerfil('autora', page: 0),
    ).thenAnswer((_) async => _perfil([primeiro], temMais: true));
    when(() => feed.buscarPerfil('autora', page: 1)).thenAnswer(
      (_) async => _perfil([primeiro, _post('texto', 'Mais uma publicação')]),
    );
    await montar(tester, feed);
    await tester.tap(find.text('Carregar mais'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(_imagemComUrl(_primeiraFoto), findsOneWidget);
    expect(find.text('Mais uma publicação'), findsOneWidget);
    expect(find.text('Carregar mais'), findsNothing);
    verify(() => feed.buscarPerfil('autora', page: 1)).called(1);
  });

  testWidgets(
    'perfil mostra o ano, o total de todas as páginas e amplia a capa e a foto',
    (tester) async {
      final feed = _FeedMock();
      when(() => feed.buscarPerfil('autora', page: 0)).thenAnswer(
        (_) async => _perfil([_post('um', 'Almoço')], total: 21, temMais: true),
      );
      await montar(tester, feed);
      expect(find.text('No Nhac desde 2025'), findsOneWidget);
      expect(find.text('21'), findsOneWidget);
      await tester.tap(find.byTooltip('Ampliar banner'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FeedImagesPage>(find.byType(FeedImagesPage)).imagens,
        [_bannerUrl],
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(_imagemComUrl(_fotoUrl));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FeedImagesPage>(find.byType(FeedImagesPage)).imagens,
        [_fotoUrl],
      );
    },
  );

  testWidgets('lojista abre o chat da loja indicada pelo servidor', (
    tester,
  ) async {
    final feed = _FeedMock();
    final perfil = FeedPerfilModel.fromMap({
      'id': 'autora',
      'nome': 'Ana',
      'podeEnviarMensagem': false,
      'publicacoes': [],
      'temMais': false,
      'lojaParaMensagem': {'id': 'padaria-17', 'nome': 'Padaria da Ana'},
    });
    when(
      () => feed.buscarPerfil('autora', page: 0),
    ).thenAnswer((_) async => perfil);
    await montar(tester, feed);
    await tester.tap(find.text('Mensagem para Padaria da Ana'));
    await tester.pumpAndSettle();
    expect(find.text('Chat de padaria-17'), findsOneWidget);
  });

  for (final proprio in [false, true]) {
    testWidgets(
      'contato indisponível continua visível com motivo (próprio: $proprio)',
      (tester) async {
        final feed = _FeedMock();
        when(() => feed.buscarPerfil('autora', page: 0)).thenAnswer(
          (_) async => _perfil([], podeEnviarMensagem: false, bannerUrl: null),
        );
        await montar(tester, feed, meuId: proprio ? 'autora' : 'leitor');
        final botao = find.ancestor(
          of: find.text('Enviar mensagem'),
          matching: find.byType(FilledButton),
        );
        expect(tester.widget<FilledButton>(botao).onPressed, isNull);
        expect(
          find.text(
            proprio
                ? 'Você está vendo seu próprio perfil.'
                : 'Mensagens indisponíveis entre estas contas.',
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(BannerPerfil),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).gradient != null,
            ),
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('resposta atrasada da conta anterior não entra na nova grade', (
    tester,
  ) async {
    final feed = _FeedMock();
    final anterior = Completer<FeedPerfilModel>();
    final autor = ValueNotifier('anterior');
    addTearDown(autor.dispose);
    when(
      () => feed.buscarPerfil('anterior', page: 0),
    ).thenAnswer((_) => anterior.future);
    when(
      () => feed.buscarPerfil('atual', page: 0),
    ).thenAnswer((_) async => _perfil([_post('novo', 'Da nova conta')]));
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: autor,
              builder: (_, id, __) => CustomScrollView(
                slivers: [
                  PublicacoesPerfil(
                    usuarioId: id,
                    titulo: 'Suas publicações',
                    repository: feed,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    autor.value = 'atual';
    await tester.pump();
    await tester.pump();
    anterior.complete(_perfil([_post('velho', 'Da conta anterior')]));
    await tester.pump();
    expect(find.text('Da nova conta'), findsOneWidget);
    expect(find.text('Da conta anterior'), findsNothing);
  });
}
