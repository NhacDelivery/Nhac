import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/components/loading_nhac.dart';
import 'package:nhac/models/loja/lojas.dart';
import 'package:nhac/models/pedido/entregador_pedido_model.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/pages/rastreio_pedido_page.dart';
import 'package:nhac/repositories/entrega_repository.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:nhac/services/pedido_status_socket_service.dart';

class MockPedidoRepository extends Mock implements PedidoRepository {}
class MockLojaRepository extends Mock implements LojaRepository {}
class MockEntregaRepository extends Mock implements EntregaRepository {}
class MockPedidoStatusSocketService extends Mock implements PedidoStatusSocketService {}

void main() {
  late MockPedidoRepository mockPedidoRepository;
  late MockLojaRepository mockLojaRepository;
  late MockEntregaRepository mockEntregaRepository;
  late MockPedidoStatusSocketService mockSocket;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080');
  });

  setUp(() {
    mockPedidoRepository = MockPedidoRepository();
    mockLojaRepository = MockLojaRepository();
    mockEntregaRepository = MockEntregaRepository();
    mockSocket = MockPedidoStatusSocketService();

    when(() => mockSocket.status).thenAnswer((_) => const Stream.empty());
    when(() => mockSocket.conectar(any())).thenAnswer((_) async {});
    when(() => mockSocket.dispose()).thenReturn(null);

    final loja = LojasModel(
      id: 'loja1',
      nome: 'Pizzaria Top',
      categoria: 'Pizzaria',
      imagemUrl: '',
    );
    when(() => mockLojaRepository.buscarLoja(any())).thenAnswer((_) async => loja);
    when(() => mockEntregaRepository.buscarRota(any())).thenThrow(Exception('sem rota'));
    when(() => mockEntregaRepository.buscarLocalizacaoEntregador(any())).thenAnswer((_) async => null);
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
    String? codigoEntrega,
    EntregadorPedidoModel? entregador,
  }) {
    return PedidoModel(
      id: 'ped-100',
      usuarioId: 'user1',
      lojaId: 'loja1',
      lojaNome: 'Pizzaria Top',
      valorTotal: 50.0,
      taxaFrete: 5.0,
      formaPagamento: 'PIX',
      enderecoEntrega: endereco,
      itens: const [],
      status: status,
      codigoEntrega: codigoEntrega,
      entregador: entregador,
    );
  }

  Widget createWidgetUnderTest(String pedidoId) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MaterialApp(
        home: RastreioPedidoPage(
          pedidoId: pedidoId,
          pedidoRepository: mockPedidoRepository,
          lojaRepository: mockLojaRepository,
          entregaRepository: mockEntregaRepository,
          statusSocket: mockSocket,
        ),
      ),
    );
  }

  void setupScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('F2 - Código de entrega no acompanhamento', () {
    testWidgets('Estado 1: com código em saiuEntrega exibe 4 dígitos grandes e texto de instrução', (tester) async {
      setupScreen(tester);
      final pedido = criarPedido(
        status: StatusPedido.saiuEntrega,
        codigoEntrega: '1234',
      );
      when(() => mockPedidoRepository.buscarPedidoPorId('ped-100')).thenAnswer((_) async => pedido);

      await tester.pumpWidget(createWidgetUnderTest('ped-100'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('cartao-codigo-entrega')), findsOneWidget);
      expect(find.text('1234'), findsOneWidget);
      expect(find.text('Informe este código ao entregador só quando receber o pedido.'), findsOneWidget);
      expect(find.byType(LoadingNhac), findsNothing);
    });

    testWidgets('Acessibilidade: Semantics lê o código dígito a dígito', (tester) async {
      setupScreen(tester);
      final semantics = tester.ensureSemantics();

      final pedido = criarPedido(
        status: StatusPedido.saiuEntrega,
        codigoEntrega: '5678',
      );
      when(() => mockPedidoRepository.buscarPedidoPorId('ped-100')).thenAnswer((_) async => pedido);

      await tester.pumpWidget(createWidgetUnderTest('ped-100'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.bySemanticsLabel('Código de entrega: 5 6 7 8'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('Estado 2: carregando código em saiuEntrega quando ainda não recebido da rede', (tester) async {
      setupScreen(tester);
      final pedido = criarPedido(
        status: StatusPedido.saiuEntrega,
        codigoEntrega: null,
      );
      when(() => mockPedidoRepository.buscarPedidoPorId('ped-100')).thenAnswer((_) async => pedido);

      await tester.pumpWidget(createWidgetUnderTest('ped-100'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('cartao-codigo-entrega')), findsOneWidget);
      expect(find.text('Carregando código…'), findsOneWidget);
      expect(find.byType(LoadingNhac), findsOneWidget);
      expect(find.text('Informe este código ao entregador só quando receber o pedido.'), findsOneWidget);
    });

    testWidgets('Estado 3: sem código em outros status (preparando, entregue, cancelado)', (tester) async {
      setupScreen(tester);
      for (final status in [StatusPedido.preparando, StatusPedido.entregue, StatusPedido.cancelado]) {
        final pedido = criarPedido(
          status: status,
          codigoEntrega: '1234',
        );
        when(() => mockPedidoRepository.buscarPedidoPorId('ped-100')).thenAnswer((_) async => pedido);

        await tester.pumpWidget(createWidgetUnderTest('ped-100'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(const Key('cartao-codigo-entrega')), findsNothing);
        expect(find.text('Informe este código ao entregador só quando receber o pedido.'), findsNothing);
      }
    });
  });
}

