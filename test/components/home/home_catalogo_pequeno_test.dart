import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/components/home/home_content.dart';
import 'package:nhac/components/home/home_category_chips.dart';
import 'package:nhac/components/home/home_product_banner_carousel.dart';
import 'package:nhac/components/home/home_product_section.dart';
import 'package:nhac/components/product_card.dart';
import 'package:nhac/controllers/cart_provider.dart';
import 'package:nhac/controllers/endereco_provider.dart';
import 'package:nhac/globals/themes.dart';
import 'package:nhac/models/produto/produtos.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:nhac/repositories/produto_repository.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/connectivity_service.dart';
import 'package:nhac/services/local_cache_service.dart';

class LojasMock extends Mock implements LojaRepository {}

class ProdutosMock extends Mock implements ProdutoRepository {}

class AuthMock extends Mock implements AuthService {}

class EnderecosMock extends Mock implements EnderecoProvider {}

class ConexaoMock extends Mock implements ConnectivityService {}

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter.baseflow.com/geolocator'),
          (call) async => call.method == 'isLocationServiceEnabled' ? false : null);

    final font = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await font.load();
    await icons.load();
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter.baseflow.com/geolocator'), null);
  });
  for (final aberta in [true, false]) {
    testWidgets(
        'home com um produto e loja ${aberta ? 'aberta' : 'fechada'} mantém destaques sem repetir categorias',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      LocalCacheService.limparCacheHome();
      dotenv.testLoad(
          fileInput:
              'E2E_MODE=true\nAPI_BASE_URL=http://localhost:8080/api/v1');
      final lojas = LojasMock();
      final produtos = ProdutosMock();
      final auth = AuthMock();
      final enderecos = EnderecosMock();
      final conexao = ConexaoMock();
      final produto = ProdutosModel(
          id: 'p1',
          nome: 'Combo da casa',
          preco: 35,
          categoriaMenu: 'Combos',
          lojaId: 'l1',
          lojaNome: 'Loja da esquina',
          lojaAberta: aberta);
      when(() => lojas.buscarLojas(page: 0, size: 10))
          .thenAnswer((_) async => []);
      when(() => produtos.buscarNecessidades())
          .thenAnswer((_) async => [produto]);
      when(() => produtos.buscarPromocoes()).thenAnswer((_) async => []);
      when(() => produtos.buscarCategorias())
          .thenAnswer((_) async => ['Acompanhamentos', 'Bebidas', 'Combos']);
      when(() => auth.usuarioId).thenReturn(null);
      when(() => enderecos.enderecos).thenReturn([]);
      when(() => enderecos.erro).thenReturn(null);
      when(() => enderecos.isLoading).thenReturn(false);
      when(() => conexao.isOnline).thenReturn(true);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider<EnderecoProvider>.value(value: enderecos),
            ChangeNotifierProvider<ConnectivityService>.value(value: conexao),
            ChangeNotifierProvider(create: (_) => CartProvider()),
          ],
          child: ScreenUtilInit(
              designSize: const Size(390, 844),
              builder: (_, __) => MaterialApp(
                  theme: lightTheme,
                  home: Scaffold(
                      body: HomeContent(
                          lojaRepository: lojas,
                          produtoRepository: produtos))))));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      final banner = find.byType(HomeProductBannerCarousel);
      expect(banner, findsOneWidget);
      expect(
          tester.widget<HomeProductBannerCarousel>(banner).products.single.id,
          'p1');
      expect(find.descendant(of: banner, matching: find.text('Combos')),
          findsNothing);
      if (const bool.fromEnvironment('CAPTURE_UI')) {
        await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile(
                'goldens/home-${aberta ? 'aberta' : 'fechada'}.png'));
      }
      final categorias = find.byType(HomeCategoryChips);
      await tester.ensureVisible(categorias);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(HomeCategoryChips), findsOneWidget);
      verify(() => produtos.buscarCategorias()).called(1);
      await tester.drag(
          find.byType(CustomScrollView).first, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.scrollUntilVisible(find.text('Explore o cardápio'), 150,
          scrollable: find.byType(Scrollable).first);
      await tester.pump(const Duration(milliseconds: 500));
      final secoes = tester
          .widgetList<HomeProductSection>(find.byType(HomeProductSection))
          .toList();
      expect(secoes.length, 2);
      expect(secoes.every((s) => s.products.single.id == 'p1'), isTrue);
      expect(secoes.last.title, 'Explore o cardápio');
      if (!aberta) {
        expect(
            tester
                .widgetList<ProductCard>(find.byType(ProductCard))
                .every((card) => card.lojaFechada),
            isTrue);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
