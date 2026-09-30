import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/pedido/entregador_pedido_model.dart';
import 'package:nhac/models/pedido/item_pedido_model.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/pages/pedido_entregue_page.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/local_cache_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPedidoRepository extends Mock implements PedidoRepository {}
class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockPedidoRepository mockPedidoRepository;
  late MockAuthService mockAuthService;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockPedidoRepository = MockPedidoRepository();
    mockAuthService = MockAuthService();

    when(() => mockAuthService.usuarioId).thenReturn('user123');
    when(() => mockPedidoRepository.buscarAvaliacaoEntregador(any()))
        .thenAnswer((_) async => null);
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
    EntregadorPedidoModel? entregador,
    bool entregadorAvaliado = false,
  }) {
    return PedidoModel(
      id: 'ped-entregue-1',
      usuarioId: 'user123',
      lojaId: 'loja1',
      lojaNome: 'Pizzaria do Bairro',
      valorTotal: 75.50,
      taxaFrete: 5.0,
      formaPagamento: 'PIX',
      enderecoEntrega: endereco,
      itens: const [
        ItemPedidoModel(
          id: 'item1',
          produtoId: 'prod1',
          nome: 'Pizza Calabresa',
          imagemUrl: '',
          preco: 70.50,
          quantidade: 1,
        ),
      ],
      status: StatusPedido.entregue,
      entregador: entregador,
      entregadorAvaliado: entregadorAvaliado,
    );
  }

  Widget createWidgetUnderTest({
    required String pedidoId,
    PedidoModel? initialPedido,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) => MaterialApp(
          home: PedidoEntreguePage(
            pedidoId: pedidoId,
            pedidoRepository: mockPedidoRepository,
            initialPedido: initialPedido,
          ),
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

  const entregadorExemplo = EntregadorPedidoModel(
    nome: 'Carlos S.',
    fotoUrl: null,
    tipoVeiculo: 'MOTO',
    modeloVeiculo: 'CG 160',
    corVeiculo: 'Preta',
    placaVeiculo: 'ABC1D23',
    avaliacaoMedia: 4.8,
    totalAvaliacoes: 12,
  );

  group('F4 - PedidoEntreguePage e Avaliação', () {
    testWidgets('Sem entregador: exibe sucesso e resumo, mas NÃO exibe botão de avaliar', (tester) async {
      setupScreen(tester);
      final pedido = criarPedido(entregador: null);
      when(() => mockPedidoRepository.buscarPedidoPorId('ped-entregue-1'))
          .thenAnswer((_) async => pedido);

      await tester.pumpWidget(createWidgetUnderTest(pedidoId: 'ped-entregue-1'));
      await tester.pumpAndSettle();

      expect(find.text('Pedido entregue!'), findsOneWidget);
      expect(find.text('Pizzaria do Bairro'), findsOneWidget);
      expect(find.textContaining('75,50'), findsOneWidget);
      expect(find.text('Pizza Calabresa'), findsOneWidget);
      expect(find.byKey(const Key('cartao-entregador-entregue')), findsNothing);
      expect(find.byKey(const Key('botao-avaliar-entregador')), findsNothing);
      expect(find.byKey(const Key('botao-voltar-inicio')), findsOneWidget);
    });

    testWidgets('Com entregador já avaliado: exibe dados do entregador e tag avaliado, sem botão de avaliar', (tester) async {
      setupScreen(tester);
      final pedido = criarPedido(
        entregador: entregadorExemplo,
        entregadorAvaliado: true,
      );
      when(() => mockPedidoRepository.buscarPedidoPorId('ped-entregue-1'))
          .thenAnswer((_) async => pedido);

      await tester.pumpWidget(createWidgetUnderTest(pedidoId: 'ped-entregue-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cartao-entregador-entregue')), findsOneWidget);
      expect(find.text('Carlos S.'), findsOneWidget);
      expect(find.text('Entregador já avaliado'), findsOneWidget);
      expect(find.byKey(const Key('botao-avaliar-entregador')), findsNothing);
    });

    testWidgets('Com entregador não avaliado: exibe botão Avaliar entregador', (tester) async {
      setupScreen(tester);
      final pedido = criarPedido(
        entregador: entregadorExemplo,
        entregadorAvaliado: false,
      );
      when(() => mockPedidoRepository.buscarPedidoPorId('ped-entregue-1'))
          .thenAnswer((_) async => pedido);

      await tester.pumpWidget(createWidgetUnderTest(pedidoId: 'ped-entregue-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cartao-entregador-entregue')), findsOneWidget);
      expect(find.byKey(const Key('botao-avaliar-entregador')), findsOneWidget);
    });

    testWidgets('Ao abrir a tela: salva flag pedido_entregue_visto e remove pedido ativo do cache', (tester) async {
      setupScreen(tester);
      final pedido = criarPedido(entregador: entregadorExemplo);
      when(() => mockPedidoRepository.buscarPedidoPorId('ped-entregue-1'))
          .thenAnswer((_) async => pedido);

      // Preenche o cache antes de abrir a tela
      await LocalCacheService.salvarPedidoAtivo('user123', 'ped-entregue-1');
      await LocalCacheService.salvarSnapshotPedido('user123', pedido);

      // Verifica estado antes
      expect(await LocalCacheService.carregarPedidoAtivo('user123'), 'ped-entregue-1');
      expect(await LocalCacheService.isPedidoEntregueVisto('ped-entregue-1'), isFalse);

      await tester.pumpWidget(createWidgetUnderTest(pedidoId: 'ped-entregue-1'));
      await tester.pumpAndSettle();

      // Flag visto deve ser true
      expect(await LocalCacheService.isPedidoEntregueVisto('ped-entregue-1'), isTrue);
      // Cache do pedido ativo deve ter sido limpo
      expect(await LocalCacheService.carregarPedidoAtivo('user123'), isNull);
      expect(await LocalCacheService.carregarSnapshotPedido('user123'), isNull);
    });

    testWidgets('Fluxo de avaliação com sucesso: seleciona nota, envia e atualiza tela', (tester) async {
      setupScreen(tester);
      final pedido = criarPedido(
        entregador: entregadorExemplo,
        entregadorAvaliado: false,
      );
      when(() => mockPedidoRepository.buscarPedidoPorId('ped-entregue-1'))
          .thenAnswer((_) async => pedido);
      when(() => mockPedidoRepository.avaliarEntregador(any(), any(), any()))
          .thenAnswer((_) async {});

      await tester.pumpWidget(createWidgetUnderTest(pedidoId: 'ped-entregue-1'));
      await tester.pumpAndSettle();

      // Abre a sheet
      await tester.tap(find.byKey(const Key('botao-avaliar-entregador')));
      await tester.pumpAndSettle();

      // Inicialmente sem nota selecionada: botão de envio desabilitado
      final botaoEnviar = tester.widget<ElevatedButton>(find.byKey(const Key('botao-enviar-avaliacao')));
      expect(botaoEnviar.onPressed, isNull);

      // Seleciona 5 estrelas
      await tester.tap(find.byKey(const Key('estrela-5')));
      await tester.pumpAndSettle();

      expect(find.text('Excelente'), findsOneWidget);

      // Digita comentário
      await tester.enterText(find.byKey(const Key('campo-comentario-avaliacao')), 'Entrega rápida e atenciosa!');
      await tester.pumpAndSettle();

      // Clica em enviar
      await tester.tap(find.byKey(const Key('botao-enviar-avaliacao')));
      await tester.pumpAndSettle();

      // Verifica chamada ao repositório
      verify(() => mockPedidoRepository.avaliarEntregador('ped-entregue-1', 5, 'Entrega rápida e atenciosa!')).called(1);

      // A sheet fechou e botão de avaliar sumiu
      expect(find.byKey(const Key('botao-avaliar-entregador')), findsNothing);
      expect(find.text('Entregador já avaliado'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('Fluxo com erro já avaliado: trata como sucesso e marca avaliado sem erro', (tester) async {
      setupScreen(tester);
      final pedido = criarPedido(
        entregador: entregadorExemplo,
        entregadorAvaliado: false,
      );
      when(() => mockPedidoRepository.buscarPedidoPorId('ped-entregue-1'))
          .thenAnswer((_) async => pedido);
      when(() => mockPedidoRepository.avaliarEntregador(any(), any(), any()))
          .thenThrow(AppException('Este pedido já foi avaliado.', code: 'JA_AVALIADO'));

      await tester.pumpWidget(createWidgetUnderTest(pedidoId: 'ped-entregue-1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('botao-avaliar-entregador')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('estrela-4')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('botao-enviar-avaliacao')));
      await tester.pumpAndSettle();

      // Sheet deve fechar e marcar como avaliado
      expect(find.byKey(const Key('botao-avaliar-entregador')), findsNothing);
      expect(find.text('Entregador já avaliado'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('Fluxo com erro de rede: exibe erro, preserva nota digitada e permite reenviar', (tester) async {
      setupScreen(tester);
      final pedido = criarPedido(
        entregador: entregadorExemplo,
        entregadorAvaliado: false,
      );
      when(() => mockPedidoRepository.buscarPedidoPorId('ped-entregue-1'))
          .thenAnswer((_) async => pedido);

      var tentou = false;
      when(() => mockPedidoRepository.avaliarEntregador(any(), any(), any()))
          .thenAnswer((_) async {
        if (!tentou) {
          tentou = true;
          throw NetworkException('Sem conexão com a internet.');
        }
      });

      await tester.pumpWidget(createWidgetUnderTest(pedidoId: 'ped-entregue-1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('botao-avaliar-entregador')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('estrela-5')));
      await tester.enterText(find.byKey(const Key('campo-comentario-avaliacao')), 'Muito bom!');
      await tester.pumpAndSettle();

      // Primeira tentativa falha com erro de rede
      await tester.tap(find.byKey(const Key('botao-enviar-avaliacao')));
      await tester.pumpAndSettle();

      // A sheet ainda está aberta e os dados foram preservados
      expect(find.byKey(const Key('campo-comentario-avaliacao')), findsOneWidget);
      expect(find.text('Muito bom!'), findsOneWidget);
      expect(find.text('Excelente'), findsOneWidget);

      // Segunda tentativa tem sucesso
      await tester.tap(find.byKey(const Key('botao-enviar-avaliacao')));
      await tester.pumpAndSettle();

      // A sheet fechou e marcou avaliado
      expect(find.byKey(const Key('botao-avaliar-entregador')), findsNothing);
      expect(find.text('Entregador já avaliado'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('Cold start: flag pedido_entregue_visto persiste no SharedPreferences', (tester) async {
      setupScreen(tester);
      await LocalCacheService.marcarPedidoEntregueVisto('ped-999');

      expect(await LocalCacheService.isPedidoEntregueVisto('ped-999'), isTrue);
      expect(await LocalCacheService.isPedidoEntregueVisto('ped-outro'), isFalse);
    });

    testWidgets('Botão Voltar ao início renderiza e está habilitado', (tester) async {
      setupScreen(tester);
      final pedido = criarPedido(entregador: null);
      when(() => mockPedidoRepository.buscarPedidoPorId('ped-entregue-1'))
          .thenAnswer((_) async => pedido);

      await tester.pumpWidget(createWidgetUnderTest(pedidoId: 'ped-entregue-1'));
      await tester.pumpAndSettle();

      final botaoVoltar = tester.widget<OutlinedButton>(find.byKey(const Key('botao-voltar-inicio')));
      expect(botaoVoltar.onPressed, isNotNull);
    });
  });
}

