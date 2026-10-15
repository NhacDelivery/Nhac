import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/chat/conversa_pessoa_resumo.dart';
import 'package:nhac/models/chat/mensagem_chat.dart';
import 'package:nhac/pages/chat_conversa_page.dart';
import 'package:nhac/pages/mensagens_page.dart';
import 'package:nhac/repositories/chat_repository.dart';
import 'package:nhac/services/chat_socket_service.dart';

class RepositoryMock extends Mock implements ChatRepository {}

class SocketMock extends Mock implements ChatSocketService {}

MensagemChat mensagem(String id, String texto,
        {String autor = 'eu', String conversa = 'conversa'}) =>
    MensagemChat(
      id: id,
      conversaId: conversa,
      remetenteTipo: 'CLIENTE',
      remetenteUsuarioId: autor,
      conteudo: texto,
      enviadaEm: DateTime(2026, 10, 15, 12),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RepositoryMock repository;
  late SocketMock socket;
  late StreamController<MensagemChat> mensagens;
  late StreamController<bool> conexoes;
  setUpAll(() async {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080/api/v1');
    await initializeDateFormatting('pt_BR');
    final roboto = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await roboto.load();
    await icons.load();
  });
  setUp(() {
    repository = RepositoryMock();
    socket = SocketMock();
    mensagens = StreamController.broadcast();
    conexoes = StreamController.broadcast();
    when(() => repository.historico('conversa')).thenAnswer((_) async => []);
    when(() => repository.marcarComoLida(any())).thenAnswer((_) async {});
    when(() => socket.mensagens).thenAnswer((_) => mensagens.stream);
    when(() => socket.conectado).thenAnswer((_) => conexoes.stream);
    when(() => socket.erros).thenAnswer((_) => const Stream.empty());
    when(() => socket.conectar(any())).thenAnswer((_) async {});
    when(() => socket.reconectar(any())).thenAnswer((_) async {});
    when(() => socket.enviar(any(), any())).thenReturn(false);
  });
  tearDown(() async {
    await mensagens.close();
    await conexoes.close();
  });

  Widget app(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) =>
          MaterialApp(theme: ThemeData(fontFamily: 'Roboto'), home: child));
  Widget conversa() => app(ChatConversaPage(
      conversaId: 'conversa',
      conversaPessoa: true,
      usuarioId: 'eu',
      interlocutorNome: 'Ana',
      repository: repository,
      socket: socket));
  Future<void> sair(WidgetTester tester) async =>
      tester.pumpWidget(const SizedBox());

  testWidgets('pessoa usa remetenteUsuarioId para separar os dois lados',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    when(() => repository.historico('conversa')).thenAnswer((_) async => [
          mensagem('1', 'Minha mensagem'),
          mensagem('2', 'Resposta da Ana', autor: 'ana')
        ]);
    await tester.pumpWidget(conversa());
    await tester.pump();
    final minha = tester.widget<Align>(find
        .ancestor(of: find.text('Minha mensagem'), matching: find.byType(Align))
        .first);
    final outra = tester.widget<Align>(find
        .ancestor(
            of: find.text('Resposta da Ana'), matching: find.byType(Align))
        .first);
    expect(minha.alignment, Alignment.centerRight);
    expect(outra.alignment, Alignment.centerLeft);
    verifyNever(() => repository.abrirConversaComLoja(any()));
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
          find.byType(Scaffold), matchesGoldenFile('goldens/chat-pessoa.png'));
    }
    await sair(tester);
  });

  testWidgets('sem socket envia por REST e limpa somente após confirmação',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final resposta = Completer<MensagemChat>();
    when(() => repository.enviarMensagem('conversa',
            conteudo: any(named: 'conteudo'),
            clientMessageId: any(named: 'clientMessageId')))
        .thenAnswer((_) => resposta.future);
    await tester.pumpWidget(conversa());
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Olá Ana');
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Olá Ana');
    final enviado = verify(() => repository.enviarMensagem('conversa',
            conteudo: 'Olá Ana',
            clientMessageId: captureAny(named: 'clientMessageId')))
        .captured
        .single as String;
    resposta.complete(mensagem('msg_$enviado', 'Olá Ana'));
    await tester.pump();
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    mensagens.add(mensagem('msg_$enviado', 'Olá Ana'));
    await tester.pump();
    expect(find.text('Olá Ana'), findsOneWidget);
    await sair(tester);
  });

  testWidgets('falha REST preserva texto e reenvia o mesmo identificador',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    when(() => repository.enviarMensagem('conversa',
            conteudo: any(named: 'conteudo'),
            clientMessageId: any(named: 'clientMessageId')))
        .thenThrow(NetworkException('Sem conexão.'));
    await tester.pumpWidget(conversa());
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Ainda está aí?');
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pump();
    final primeiro = verify(() => repository.enviarMensagem('conversa',
        conteudo: 'Ainda está aí?',
        clientMessageId: captureAny(named: 'clientMessageId'))).captured.single;
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Ainda está aí?');
    await tester.tap(find.byTooltip('Reenviar mensagem'));
    await tester.pump();
    final segundo = verify(() => repository.enviarMensagem('conversa',
        conteudo: 'Ainda está aí?',
        clientMessageId: captureAny(named: 'clientMessageId'))).captured.single;
    expect(segundo, primeiro);
    await sair(tester);
  });

  testWidgets('retry reconecta socket e preserva histórico durante falha',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    when(() => repository.historico('conversa'))
        .thenAnswer((_) async => [mensagem('1', 'Já carregada')]);
    await tester.pumpWidget(conversa());
    await tester.pump();
    when(() => repository.historico('conversa'))
        .thenThrow(NetworkException('Sem conexão.'));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    verify(() => socket.reconectar('conversa')).called(1);
    expect(find.text('Já carregada'), findsOneWidget);
    expect(find.text('Sem conexão.'), findsOneWidget);
    mensagens.add(
        mensagem('outra', 'Mensagem de outra conversa', conversa: 'outra'));
    await tester.pump();
    expect(find.text('Mensagem de outra conversa'), findsNothing);
    await sair(tester);
  });

  testWidgets(
      'caixa diferencia erro de vazio e permite abrir pessoa após retry',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var falhar = true;
    when(() => repository.listarConversasPessoas(
        pagina: any(named: 'pagina'),
        tamanho: any(named: 'tamanho'))).thenAnswer((_) async {
      if (falhar) throw NetworkException('Sem conexão.');
      return [
        ConversaPessoaResumo(
            id: 'conversa',
            pessoaId: 'ana',
            pessoaNome: 'Ana',
            ultimaMensagem: 'Oi',
            ultimaMensagemData: DateTime(2026, 10, 15),
            mensagensNaoLidas: 1)
      ];
    });
    final router = GoRouter(routes: [
      GoRoute(
          path: '/', builder: (_, __) => MensagensPage(repository: repository)),
      GoRoute(
          path: '/chat-pessoa',
          builder: (_, state) => Scaffold(
              appBar: AppBar(),
              body: Text('Pessoa ${(state.extra as Map)['conversaId']}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp.router(
            theme: ThemeData(fontFamily: 'Roboto'), routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.text('Ainda não há conversas com pessoas.'), findsNothing);
    expect(find.text('Sem conexão.'), findsOneWidget);
    falhar = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'não existe');
    await tester.pump();
    expect(find.text('Ana'), findsNothing);
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pump();
    expect(find.text('Ana'), findsOneWidget);
    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();
    expect(find.text('Pessoa conversa'), findsOneWidget);
    await sair(tester);
  });

  testWidgets('refresh falho conserva conversas visíveis', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    when(() => repository.listarConversasPessoas(
            pagina: any(named: 'pagina'), tamanho: any(named: 'tamanho')))
        .thenAnswer((_) async => [
              ConversaPessoaResumo(
                  id: 'conversa',
                  pessoaId: 'ana',
                  pessoaNome: 'Ana',
                  ultimaMensagem: 'Oi',
                  ultimaMensagemData: DateTime(2026),
                  mensagensNaoLidas: 0)
            ]);
    await tester.pumpWidget(app(MensagensPage(repository: repository)));
    await tester.pump();
    when(() => repository.listarConversasPessoas(
            pagina: any(named: 'pagina'), tamanho: any(named: 'tamanho')))
        .thenThrow(NetworkException('Sem conexão.'));
    await tester.tap(find.byTooltip('Atualizar conversas'));
    await tester.pump();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Sem conexão.'), findsOneWidget);
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(find.byType(Scaffold),
          matchesGoldenFile('goldens/conversas-erro-parcial.png'));
    }
    await sair(tester);
  });
}
