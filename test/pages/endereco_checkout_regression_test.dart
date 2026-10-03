import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/controllers/cart_provider.dart';
import 'package:nhac/controllers/endereco_provider.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/pages/carrinho_page.dart';
import 'package:nhac/pages/checkout_page.dart';
import 'package:nhac/repositories/endereco_repository.dart';
import 'package:nhac/services/auth_service.dart';

class AddressAuth extends Mock implements AuthService {}

class AddressRepo extends Mock implements EnderecoRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final antigo = EnderecoModel(
      id: 'a',
      rua: 'Rua A',
      numero: '10',
      bairro: 'Centro',
      cidade: 'Osasco',
      estado: 'SP',
      cep: '06000000',
      isPadrao: true);
  final novo = EnderecoModel(
      id: 'b',
      rua: 'Rua B',
      numero: '',
      bairro: 'Centro',
      cidade: 'Osasco',
      estado: 'SP',
      cep: '06000000');
  late AddressAuth auth;
  late EnderecoProvider enderecos;
  late CartProvider cart;
  late AddressRepo repo;
  setUpAll(() {
    registerFallbackValue(novo);
    dotenv.testLoad(
        fileInput: 'API_BASE_URL=http://localhost:8080\nE2E_MODE=true');
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = AddressAuth();
    when(() => auth.usuarioId).thenReturn('cliente');
    repo = AddressRepo();
    when(() => repo.buscarEnderecos('cliente'))
        .thenAnswer((_) async => [antigo, novo]);
    when(() => repo.atualizarEndereco('cliente', 'b', any()))
        .thenAnswer((_) async {
      when(() => repo.buscarEnderecos('cliente')).thenAnswer((_) async =>
          [antigo.copyWith(isPadrao: false), novo.copyWith(isPadrao: true)]);
    });
    enderecos = EnderecoProvider(authService: auth, repository: repo);
    await enderecos.buscarEnderecos();
    cart = CartProvider(authService: auth);
    await cart.adicionarItemComQuantidade(
        idProduto: 'p',
        nome: 'Produto',
        preco: 10,
        imagemUrl: '',
        lojaId: '',
        quantidade: 1);
  });
  tearDown(() {
    cart.dispose();
    enderecos.dispose();
  });
  Future<void> montar(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<EnderecoProvider>.value(value: enderecos),
          ChangeNotifierProvider<CartProvider>.value(value: cart),
        ],
        child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, __) => MaterialApp(home: page))));
    await tester.pumpAndSettle();
  }

  testWidgets('carrinho mostra e seleciona endereço sem complemento',
      (tester) async {
    await montar(tester, const CarrinhoPage());
    await tester.tap(find.text('Alterar'));
    await tester.pumpAndSettle();
    expect(find.text('Selecione o endereço de entrega'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Rua B, '));
    await tester.pumpAndSettle();
    expect(enderecos.enderecos.where((e) => e.isPadrao).single.id, 'b');
    expect(find.text('Selecione o endereço de entrega'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout pede número logo após trocar para endereço incompleto',
      (tester) async {
    await montar(tester, const CheckoutPage());
    expect(find.text('Número da casa'), findsNothing);
    await tester.tap(find.text('Alterar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rua B, '));
    await tester.pumpAndSettle();
    expect(find.text('Número da casa'), findsOneWidget);
    expect(find.text('Para completar seu endereço, informe o número da casa.'),
        findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });
}
