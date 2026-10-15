import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/components/home/home_content.dart';
import 'package:nhac/controllers/endereco_provider.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:nhac/repositories/produto_repository.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/connectivity_service.dart';
import 'package:nhac/services/local_cache_service.dart';
import 'package:nhac/utils/app_exceptions.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockLojaRepository extends Mock implements LojaRepository {}
class MockProdutoRepository extends Mock implements ProdutoRepository {}
class MockAuthService extends Mock implements AuthService {}
class MockEnderecoProvider extends Mock implements EnderecoProvider {}
class MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  testWidgets('Falha de servidor ao iniciar a home é tratada e não salva catálogo vazio', (tester) async {
    SharedPreferences.setMockInitialValues({});
    LocalCacheService.limparCacheHome();
    dotenv.testLoad(fileInput: 'E2E_MODE=true\nAPI_BASE_URL=http://localhost:8080');
    final lojas = MockLojaRepository();
    final produtos = MockProdutoRepository();
    final auth = MockAuthService();
    final enderecos = MockEnderecoProvider();
    final connectivity = MockConnectivityService();
    when(() => lojas.buscarLojas(page: 0, size: 10)).thenAnswer((_) async => throw ServerException('Servidor indisponível'));
    when(() => produtos.buscarNecessidades()).thenAnswer((_) async => throw ServerException());
    when(() => produtos.buscarPromocoes()).thenAnswer((_) async => throw ServerException());
    when(() => auth.usuarioId).thenReturn(null);
    when(() => enderecos.enderecos).thenReturn([]);
    when(() => enderecos.erro).thenReturn(null);
    when(() => enderecos.isLoading).thenReturn(false);
    when(() => connectivity.isOnline).thenReturn(true);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AuthService>.value(value: auth),
      ChangeNotifierProvider<EnderecoProvider>.value(value: enderecos),
      ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
    ], child: ScreenUtilInit(designSize: const Size(390, 844), builder: (_, __) => MaterialApp(home: Scaffold(body: HomeContent(lojaRepository: lojas, produtoRepository: produtos))))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(LocalCacheService.ultimaAtualizacaoHome, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('catalogo_home_v1'), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
