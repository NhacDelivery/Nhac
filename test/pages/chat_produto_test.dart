import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/models/chat/mensagem_chat.dart';
import 'package:nhac/models/chat/produto_chat_referencia.dart';
import 'package:nhac/models/produto/produtos.dart';
import 'package:nhac/pages/chat_loja_page.dart';
import 'package:nhac/repositories/chat_repository.dart';
import 'package:nhac/services/chat_socket_service.dart';

class ChatRepositoryMock extends Mock implements ChatRepository {}

class ChatSocketMock extends Mock implements ChatSocketService {}

void main() {
  late ChatRepositoryMock repository;
  late ChatSocketMock socket;
  late StreamController<MensagemChat> messages;
  late StreamController<bool> connections;
  setUpAll(
      () => dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080'));
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
  final produto = ProdutosModel.fromMap({
    'id': 'p1',
    'lojaId': 'loja',
    'nome': 'Pizza',
    'preco': 19.9,
    'imagemUrl': ''
  });
  Widget page({bool fromProduct = false}) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
          home: ChatLojaPage(
              lojaId: 'loja',
              lojaNome: 'Nhac',
              produtoReferencia: fromProduct ? produto : null,
              repository: repository,
              socket: socket)));

  testWidgets('entrada por pedido envia só texto, sem referência automática',
      (tester) async {
    await tester.pumpWidget(page());
    await tester.pump();
    expect(find.text('Enviar produto à loja'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Meu pedido saiu?');
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pump();
    final sent =
        verify(() => socket.enviar(captureAny(), captureAny())).captured;
    expect(sent[0], 'Meu pedido saiu?');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'produto anexa cartão e reconexão confirma ID sem duplicar histórico',
      (tester) async {
    await tester.pumpWidget(page(fromProduct: true));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Tem cebola?');
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pump();
    final sent =
        verify(() => socket.enviar(captureAny(), captureAny())).captured;
    final reference = ProdutoChatReferencia.ler(sent[0] as String)!;
    expect(reference.nome, 'Pizza');
    expect(reference.mensagem, 'Tem cebola?');
    final persisted = MensagemChat(
        id: 'msg_${sent[1]}',
        conversaId: 'conversa',
        remetenteTipo: 'CLIENTE',
        conteudo: sent[0] as String,
        enviadaEm: DateTime(2026));
    messages.add(persisted);
    messages.add(persisted);
    await tester.pump();
    await tester.pump();
    expect(find.text('Tem cebola?'), findsOneWidget);
    expect(find.textContaining('ID: p1'), findsNothing);
    when(() => repository.historico('conversa'))
        .thenAnswer((_) async => [persisted]);
    connections.add(true);
    await tester.pump();
    await tester.pump();
    expect(find.text('Tem cebola?'), findsOneWidget);
    verifyNever(() => socket.enviar(any(), any()));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(page());
    await tester.pump();
    expect(find.text('Pizza'), findsOneWidget);
    expect(find.text('Tem cebola?'), findsOneWidget);
    expect(find.textContaining('ID: p1'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reenvio conserva identificador e anexo', (tester) async {
    await tester.pumpWidget(page(fromProduct: true));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Tem cebola?');
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pump();
    final first =
        verify(() => socket.enviar(captureAny(), captureAny())).captured;
    await tester.pump(const Duration(seconds: 16));
    await tester.tap(find.byTooltip('Reenviar mensagem'));
    await tester.pump();
    final retry =
        verify(() => socket.enviar(captureAny(), captureAny())).captured;
    expect(retry, first);
    await tester.pumpWidget(const SizedBox());
  });

  test('histórico antigo sem foto e CRLF continua compatível', () {
    final value = ProdutoChatReferencia.ler(
        'Produto: Pizza\r\nID: p1\r\nPreço: R\$ 19,90\r\n\r\nOlá');
    expect(value?.nome, 'Pizza');
    expect(value?.mensagem, 'Olá');
    expect(ProdutoChatReferencia.ler('Olá'), isNull);
  });
}
