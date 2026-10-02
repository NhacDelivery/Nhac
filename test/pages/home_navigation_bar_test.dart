import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/controllers/cart_provider.dart';
import 'package:nhac/controllers/endereco_provider.dart';
import 'package:nhac/controllers/user_provider.dart';
import 'package:nhac/models/usuario/carrinho_model.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/pages/home_page.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/connectivity_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockUserProvider extends ChangeNotifier implements UserProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> carregarDadosUsuario() async {}
}

class MockCartProvider extends ChangeNotifier implements CartProvider {
  @override
  int get totalDeUnidades => 0;

  @override
  Map<String, CartItemModel> get itens => {};

  @override
  Future<void> carregarCarrinhoLocal() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockEnderecoProvider extends ChangeNotifier implements EnderecoProvider {
  @override
  List<EnderecoModel> get enderecos => [];

  @override
  Future<void> buscarEnderecos() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthService extends ChangeNotifier implements AuthService {
  @override
  String? get usuarioId => 'user-1';

  @override
  bool get isAuthenticated => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockConnectivityService extends ChangeNotifier
    implements ConnectivityService {
  @override
  bool get isOnline => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080');
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Barra de navegação da Home possui 4 itens e Feed é navegável',
      (tester) async {
    final userProvider = MockUserProvider();
    final cartProvider = MockCartProvider();
    final enderecoProvider = MockEnderecoProvider();
    final authService = MockAuthService();
    final connectivityService = MockConnectivityService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
          ChangeNotifierProvider<EnderecoProvider>.value(
              value: enderecoProvider),
          ChangeNotifierProvider<AuthService>.value(value: authService),
          ChangeNotifierProvider<ConnectivityService>.value(
              value: connectivityService),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => const MaterialApp(
            home: HomePage(),
          ),
        ),
      ),
    );

    await tester.pump();

    // Localiza a Row da barra de navegação
    final navBarRow = find.byType(Row);

    // Garante que os 4 itens da barra de navegação existem (Home, Carrinho, Feed, Perfil)
    expect(
        find.descendant(
            of: navBarRow, matching: find.byIcon(Icons.house_outlined)),
        findsOneWidget);
    expect(
        find.descendant(
            of: navBarRow, matching: find.byIcon(Icons.shopping_cart_outlined)),
        findsOneWidget);
    expect(
        find.descendant(
            of: navBarRow, matching: find.byIcon(Icons.newspaper_outlined)),
        findsOneWidget);
    expect(
        find.descendant(
            of: navBarRow, matching: find.byIcon(Icons.person_outline)),
        findsOneWidget);

    // No estado inicial, 'Home' está selecionado e seu texto é exibido
    expect(find.descendant(of: navBarRow, matching: find.text('Home')),
        findsOneWidget);
    expect(find.descendant(of: navBarRow, matching: find.text('Feed')),
        findsNothing);

    // A barra continua acessível no final da home, fora da rolagem.
    await tester.drag(
        find.byType(CustomScrollView).first, const Offset(0, -10000));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(Icons.shopping_cart_outlined).hitTestable(),
        findsOneWidget);
    expect(find.byIcon(Icons.newspaper_outlined).hitTestable(), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.bottomNavigationBar, isNotNull);

    // Tocar no Feed (índice 2)
    await tester.tap(find.descendant(
        of: navBarRow, matching: find.byIcon(Icons.newspaper_outlined)));
    await tester.pump(const Duration(milliseconds: 500));

    // Agora Feed está selecionado e exibe o label 'Feed', enquanto 'Home' recolheu
    expect(find.descendant(of: navBarRow, matching: find.text('Feed')),
        findsOneWidget);
    expect(find.descendant(of: navBarRow, matching: find.text('Home')),
        findsNothing);
  });
}
