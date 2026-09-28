import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/components/product_card.dart';
import 'package:nhac/controllers/cart_provider.dart';
import 'package:nhac/models/produto/produtos.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class MockCartProvider extends Mock implements CartProvider {}
class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockCartProvider mockCart;
  late MockAuthService mockAuth;

  setUp(() {
    mockCart = MockCartProvider();
    mockAuth = MockAuthService();
    when(() => mockAuth.usuarioId).thenReturn(null); 
  });

  Widget createWidgetUnderTest() {
    final produto = ProdutosModel(
        id: 'p1', 
        nome: 'Nhac Burger', 
        preco: 35.90, 
        imagemUrl: 'http://example.com/image.png',
        categoriaMenu: 'Lanches'
    );
    return ScreenUtilInit(
      designSize: const Size(1000, 1000), 
      minTextAdapt: true,
      builder: (context, child) => MultiProvider(
        providers: [
          ChangeNotifierProvider<CartProvider>.value(value: mockCart),
          ChangeNotifierProvider<AuthService>.value(value: mockAuth),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 500,
                child: ProductCard(
                  produto: produto,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Deve exibir corretamente os dados do ProductCard', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('Nhac Burger'), findsOneWidget);
      expect(find.text('R\$ 35.90'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
    });
  });

  testWidgets('Deve chamar adicionarItemComQuantidade ao clicar no botão de adicionar', (tester) async {
    when(() => mockCart.adicionarItemComQuantidade(
          idProduto: any(named: 'idProduto'),
          nome: any(named: 'nome'),
          preco: any(named: 'preco'),
          imagemUrl: any(named: 'imagemUrl'),
          lojaId: any(named: 'lojaId'),
          quantidade: any(named: 'quantidade'),
        )).thenAnswer((_) async => true);

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      final addIcon = find.byIcon(Icons.add);
      await tester.tap(addIcon, warnIfMissed: false);
      await tester.pump();

      verify(() => mockCart.adicionarItemComQuantidade(
            idProduto: 'p1',
            nome: 'Nhac Burger',
            preco: 35.90,
            imagemUrl: 'http://example.com/image.png',
            lojaId: '',
            quantidade: 1,
          )).called(1);
      // A notificação agora usa o overlay AppNotification em vez de SnackBar.
      // Usamos pump com duração explícita pois a animação elasticOut não
      // "estabiliza" do ponto de vista do pumpAndSettle.
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Nhac Burger adicionado!'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
    });
  });
}
