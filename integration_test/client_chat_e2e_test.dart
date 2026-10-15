import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nhac/globals/router.dart';
import 'package:nhac/main.dart' as app;
import 'package:nhac/pages/chat_loja_page.dart';
import 'package:nhac/services/chat_socket_service.dart';
import 'support/e2e_actions.dart';
import 'support/e2e_config.dart';
import 'support/e2e_wait.dart';

/// Só a conexão de tempo real é indisponível. HTTP, JWT e banco são reais.
class SocketIndisponivel extends ChatSocketService {
  @override
  Future<void> conectar(String conversaId) async {}
  @override
  bool enviar(String conteudo, String clientMessageId) => false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('E2E-CHAT mensagem é persistida por HTTP e recuperada ao reabrir',
      (tester) async {
    await E2EConfig.validate();
    await app.main();
    await loginAsFixtureUser(tester);
    const texto = 'Mensagem de integração com conexão HTTP';
    appRouter.routerDelegate.navigatorKey.currentState!
        .push(MaterialPageRoute<void>(
            builder: (_) => ChatLojaPage(
                  lojaId: E2EConfig.storeId,
                  lojaNome: 'Loja E2E',
                  socket: SocketIndisponivel(),
                )));
    await waitFor(tester, find.byType(TextField), step: 'abrir chat real');
    await tester.enterText(find.byType(TextField), texto);
    await tapE2E(tester, find.byTooltip('Enviar mensagem'), step: 'enviar chat');
    await waitFor(
        tester, find.byWidgetPredicate((w) => w is Text && w.data == texto),
        step: 'confirmar persistência REST');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(find.text(texto), findsOneWidget);
    appRouter.routerDelegate.navigatorKey.currentState!.pop();
    await tester.pump(const Duration(milliseconds: 400));
    appRouter.routerDelegate.navigatorKey.currentState!
        .push(MaterialPageRoute<void>(
            builder: (_) => ChatLojaPage(
                  lojaId: E2EConfig.storeId,
                  lojaNome: 'Loja E2E',
                  socket: SocketIndisponivel(),
                )));
    await waitFor(
        tester, find.byWidgetPredicate((w) => w is Text && w.data == texto),
        step: 'recuperar histórico persistido');
    expect(find.text(texto), findsOneWidget);
    appRouter.routerDelegate.navigatorKey.currentState!.pop();
    await tester.pump(const Duration(milliseconds: 400));
  }, skip: !E2EConfig.runE2E);
}
