import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/models/chat/mensagem_chat.dart';
import 'package:nhac/models/chat/pedido_chat_referencia.dart';
import 'package:nhac/models/pedido/item_pedido_model.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/pages/chat_loja_page.dart';
import 'package:nhac/repositories/chat_repository.dart';
import 'package:nhac/services/chat_socket_service.dart';

class ChatRepositoryMock extends Mock implements ChatRepository {}

class ChatSocketMock extends Mock implements ChatSocketService {}

PedidoModel pedido({List<ItemPedidoModel>? itens}) => PedidoModel(
      id: 'abcd1234-ffff-0000',
      usuarioId: 'u1',
      lojaId: 'loja',
      lojaNome: 'Nhac',
      valorTotal: 52.9,
      taxaFrete: 5,
      formaPagamento: 'PIX',
      enderecoEntrega: EnderecoModel(
        id: 'e1',
        rua: 'Rua A',
        numero: '1',
        bairro: 'Centro',
        cidade: 'São Paulo',
        estado: 'SP',
        cep: '01000-000',
        isPadrao: true,
      ),
      itens: itens ??
          const [
            ItemPedidoModel(
              id: 'i1',
              produtoId: 'p1',
              nome: 'Pizza',
              imagemUrl: '',
              preco: 40,
              quantidade: 2,
            ),
            ItemPedidoModel(
              id: 'i2',
              produtoId: 'p2',
              nome: 'Refrigerante',
              imagemUrl: '',
              preco: 7.9,
              quantidade: 1,
            ),
          ],
      status: StatusPedido.preparando,
    );

void main() {
  group('PedidoChatReferencia', () {
    test('serializa e lê de volta com a mensagem do cliente', () {
      final ref = PedidoChatReferencia.fromPedido(pedido())
          .comMensagem('Meu pedido saiu?');
      final lida = PedidoChatReferencia.ler(ref.serializar());
      expect(lida, isNotNull);
      expect(lida!.codigo, '#ABCD1234');
      expect(lida.id, 'abcd1234-ffff-0000');
      expect(lida.resumo, '2x Pizza, 1x Refrigerante');
      expect(lida.status, StatusPedido.preparando.label);
      expect(lida.mensagem, 'Meu pedido saiu?');
    });

    test('sem mensagem não deixa linha sobrando', () {
      final texto = PedidoChatReferencia.fromPedido(pedido()).serializar();
      expect(texto.endsWith('\n'), isFalse);
      expect(PedidoChatReferencia.ler(texto)!.mensagem, '');
    });

    test('resumo longo é cortado e texto comum não vira referência', () {
      final muitos = List.generate(
        40,
        (i) => ItemPedidoModel(
          id: '$i',
          produtoId: '$i',
          nome: 'Produto numero $i',
          imagemUrl: '',
          preco: 1,
          quantidade: 1,
        ),
      );
      final ref = PedidoChatReferencia.fromPedido(pedido(itens: muitos));
      expect(ref.resumo.length, lessThanOrEqualTo(140));
      expect(ref.resumo.endsWith('…'), isTrue);
      expect(PedidoChatReferencia.ler('Oi, tudo bem?'), isNull);
    });
  });

  group('ChatLojaPage com pedido', () {
    late ChatRepositoryMock repository;
    late ChatSocketMock socket;
    late StreamController<MensagemChat> messages;
    late StreamController<bool> connections;
    setUpAll(() =>
        dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080'));
    setUp(() {
      repository = ChatRepositoryMock();
      socket = ChatSocketMock();
      messages = StreamController.broadcast();
      connections = StreamController.broadcast();
      when(() => repository.abrirConversaComLoja('loja'))
          .thenAnswer((_) async => 'conversa');
      when(() => repository.historico('conversa')).thenAnswer((_) async => []);
      when(() => repository.marcarComoLida(any())).thenAnswer((_) async {});
      when(() => socket.mensagens).thenAnswer((_) => messages.stream);
      when(() => socket.conectado).thenAnswer((_) => connections.stream);
      when(() => socket.erros).thenAnswer((_) => const Stream.empty());
      when(() => socket.conectar(any())).thenAnswer((_) async {});
      when(() => socket.enviar(any(), any())).thenReturn(true);
    });
    tearDown(() async {
      await messages.close();
      await connections.close();
    });

    Widget page() => ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            home: ChatLojaPage(
              lojaId: 'loja',
              lojaNome: 'Nhac',
              pedidoReferencia: PedidoChatReferencia.fromPedido(pedido()),
              repository: repository,
              socket: socket,
            ),
          ),
        );

    testWidgets('mostra a prévia e anexa o pedido na mensagem enviada',
        (tester) async {
      await tester.pumpWidget(page());
      await tester.pump();
      expect(find.text('Pedido #ABCD1234'), findsOneWidget);
      expect(find.text('Enviar pedido à loja'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Meu pedido saiu?');
      await tester.tap(find.byTooltip('Enviar mensagem'));
      await tester.pump();
      final enviado =
          verify(() => socket.enviar(captureAny(), captureAny())).captured;
      final ref = PedidoChatReferencia.ler(enviado[0] as String);
      expect(ref, isNotNull);
      expect(ref!.id, 'abcd1234-ffff-0000');
      expect(ref.mensagem, 'Meu pedido saiu?');
      await tester.pumpWidget(const SizedBox());
    });
  });
}
