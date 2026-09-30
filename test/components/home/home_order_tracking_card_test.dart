import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/components/home/home_order_tracking_card.dart';
import 'package:nhac/models/pedido/entregador_pedido_model.dart';
import 'package:nhac/models/pedido/item_pedido_model.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/connectivity_service.dart';
import 'package:nhac/services/pedido_status_socket_service.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

class MockAuthService extends Mock implements AuthService {}
class MockConnectivityService extends Mock implements ConnectivityService {}
class MockPedidoRepository extends Mock implements PedidoRepository {}
class MockPedidoStatusSocketService extends Mock implements PedidoStatusSocketService {}

void main() {
  late MockAuthService mockAuthService;
  late MockConnectivityService mockConnectivityService;
  late MockPedidoRepository mockPedidoRepository;
  late MockPedidoStatusSocketService mockSocketService;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAuthService = MockAuthService();
    mockConnectivityService = MockConnectivityService();
    mockPedidoRepository = MockPedidoRepository();
    mockSocketService = MockPedidoStatusSocketService();

    when(() => mockAuthService.usuarioId).thenReturn('user123');
    when(() => mockConnectivityService.isOnline).thenReturn(true);
    when(() => mockConnectivityService.addListener(any())).thenReturn(null);
    when(() => mockConnectivityService.removeListener(any())).thenReturn(null);

    when(() => mockSocketService.status).thenAnswer((_) => const Stream.empty());
    when(() => mockSocketService.conectado).thenAnswer((_) => const Stream.empty());
    when(() => mockSocketService.conectar(any())).thenAnswer((_) async {});
    when(() => mockSocketService.desconectar()).thenAnswer((_) async {});
    when(() => mockSocketService.dispose()).thenReturn(null);
  });

  final endereco = EnderecoModel(
    id: 'end1',
    rua: 'Rua das Flores',
    numero: '123',
    bairro: 'Centro',
    cidade: 'São Paulo',
    estado: 'SP',
    cep: '01000-000',
    isPadrao: true,
  );

  PedidoModel criarPedido({
    required StatusPedido status,
    EntregadorPedidoModel? entregador,
  }) {
    return PedidoModel(
      id: 'ped-home-1',
      usuarioId: 'user123',
      lojaId: 'loja1',
      lojaNome: 'Pizzaria Top',
      valorTotal: 65.0,
      taxaFrete: 5.0,
      formaPagamento: 'PIX',
      enderecoEntrega: endereco,
      itens: const [
        ItemPedidoModel(
          id: 'item1',
          produtoId: 'prod1',
          nome: 'Pizza Margherita',
          imagemUrl: '',
          preco: 60.0,
          quantidade: 1,
        ),
      ],
      status: status,
      entregador: entregador,
    );
  }

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<ConnectivityService>.value(value: mockConnectivityService),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) => MaterialApp(
          home: Scaffold(
            body: HomeOrderTrackingCard(
              pedidoRepository: mockPedidoRepository,
              socketService: mockSocketService,
            ),
          ),
        ),
      ),
    );
  }

  const entregador = EntregadorPedidoModel(
    nome: 'Carlos S.',
    fotoUrl: null,
    tipoVeiculo: 'MOTO',
    modeloVeiculo: 'CG 160',
    corVeiculo: 'Preta',
    placaVeiculo: 'ABC1D23',
    avaliacaoMedia: 4.8,
    totalAvaliacoes: 12,
  );

  group('F3 - HomeOrderTrackingCard entregador', () {
    testWidgets('Preparando com entregador: exibe Carlos S. aceitou sua entrega e dados do entregador', (tester) async {
      final pedido = criarPedido(
        status: StatusPedido.preparando,
        entregador: entregador,
      );
      when(() => mockPedidoRepository.buscarPedidoAtivo()).thenAnswer((_) async => pedido);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Carlos S. aceitou sua entrega'), findsOneWidget);
      expect(find.byKey(const Key('cartao-entregador-home')), findsOneWidget);
      expect(find.text('Carlos S.'), findsOneWidget);
      expect(find.textContaining('CG 160'), findsOneWidget);
      expect(find.textContaining('ABC1D23'), findsOneWidget);
      expect(find.text('4.8 (12)'), findsOneWidget);
    });

    testWidgets('Saiu para entrega com entregador: exibe Carlos S. está a caminho', (tester) async {
      final pedido = criarPedido(
        status: StatusPedido.saiuEntrega,
        entregador: entregador,
      );
      when(() => mockPedidoRepository.buscarPedidoAtivo()).thenAnswer((_) async => pedido);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Carlos S. está a caminho'), findsOneWidget);
      expect(find.byKey(const Key('cartao-entregador-home')), findsOneWidget);
    });

    testWidgets('Sem entregador: mantém status padrão e não exibe cartão de entregador', (tester) async {
      final pedido = criarPedido(
        status: StatusPedido.preparando,
        entregador: null,
      );
      when(() => mockPedidoRepository.buscarPedidoAtivo()).thenAnswer((_) async => pedido);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Carlos S. aceitou sua entrega'), findsNothing);
      expect(find.text('Em preparo'), findsOneWidget);
      expect(find.byKey(const Key('cartao-entregador-home')), findsNothing);
    });
  });
}
