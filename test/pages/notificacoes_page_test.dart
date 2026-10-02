import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/pages/notificacoes_page.dart';
import 'package:nhac/services/notificacao_historico_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'registrar leitura e retornar ao aplicativo atualiza avisos sem Future dentro de setState',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final aviso = NotificacaoRegistrada(
        'n1',
        'Aviso de teste',
        'Atualização do pedido',
        DateTime.utc(2026),
      );
      await NotificacaoHistoricoService.registrar('u1', aviso);
      await tester.pumpWidget(
        const MaterialApp(home: NotificacoesPage(usuarioId: 'u1')),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
      await tester.tap(find.text('Aviso de teste'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      final state =
          tester.state(find.byType(NotificacoesPage)) as WidgetsBindingObserver;
      state.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        (await NotificacaoHistoricoService.listar('u1')).single.lida,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
