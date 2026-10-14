import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nhac/main.dart' as app;
import 'package:nhac/pages/pedido_entregue_page.dart';
import 'package:nhac/services/api_client.dart';

import 'support/e2e_actions.dart';
import 'support/e2e_backend.dart';
import 'support/e2e_checkout.dart';
import 'support/e2e_config.dart';
import 'support/e2e_finders.dart';
import 'support/e2e_recovery.dart';
import 'support/e2e_wait.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Entrega: loja, oferta, coleta, código, baixa e avaliação',
    (tester) async {
      await E2EConfig.validate();
      await app.main();
      await loginAsFixtureUser(tester);
      final merchant = await fixtureActor('e2e.lojista@nhac.local');
      final courier = await fixtureActor('e2e.pedido@nhac.local');
      addTearDown(() {
        merchant.close(force: true);
        courier.close(force: true);
      });
      // Cadastra pelo contrato real; a fixture não injeta uma corrida pronta.
      await courier.post(
        '/entregador/cadastro',
        data: {
          'cpf': '11144477735',
          'tipoVeiculo': 'MOTO',
          'cnh': '12345678901',
          'placaVeiculo': 'EEA1A23',
          'modeloVeiculo': 'Moto E2E',
          'corVeiculo': 'Preta',
        },
      );
      await courier.patch(
        '/entregador/localizacao',
        data: {'latitude': -23.550520, 'longitude': -46.633308},
      );
      await courier.patch(
        '/entregador/status',
        data: {'statusOperacional': 'ONLINE'},
      );

      await openFixtureCheckout(tester);
      await tapE2E(
        tester,
        E2EFinders.checkoutCash,
        step: 'selecionar dinheiro',
      );
      await tapE2E(
        tester,
        E2EFinders.checkoutConfirm,
        step: 'confirmar pedido',
      );
      await waitFor(
        tester,
        E2EFinders.checkoutSuccess,
        step: 'exibir nota fiscal',
      );
      final id = semanticsValue(tester, E2EFinders.checkoutSuccessOrderId)!;
      await tapE2E(
        tester,
        E2EFinders.checkoutSuccessContinue,
        step: 'abrir rastreio',
      );
      await waitFor(
        tester,
        trackingStatus('PENDENTE'),
        timeout: const Duration(seconds: 45),
        step: 'pedido aguardando loja',
      );
      expect(find.byKey(const Key('cartao-codigo-entrega')), findsNothing);

      await merchant.patch('/pedidos/$id/status', data: {'status': 'PAGO'});
      await waitFor(
        tester,
        trackingStatus('PAGO'),
        timeout: const Duration(seconds: 45),
        step: 'loja confirmou pedido',
      );
      // Renova GPS antes do despacho: a interface pode levar tempo até o checkout.
      await courier.patch(
        '/entregador/localizacao',
        data: {'latitude': -23.550520, 'longitude': -46.633308},
      );
      await merchant.patch(
        '/pedidos/$id/status',
        data: {'status': 'PREPARANDO'},
      );
      await waitFor(
        tester,
        trackingStatus('PREPARANDO'),
        timeout: const Duration(seconds: 45),
        step: 'loja iniciou preparo',
      );
      final offers = (await courier.get<List<dynamic>>(
        '/entregas/ofertas/pendentes',
      )).data!;
      final offer =
          offers.where((o) => (o as Map)['pedidoId'] == id).single as Map;
      final accepted = await courier.post<Map<String, dynamic>>(
        '/entregas/ofertas/${offer['id']}/aceitar',
      );
      expect(accepted.data!['pedidoId'], id);
      expect((await clientOrder(id))['status'], 'PREPARANDO');
      await courier.post('/entregas/$id/coletar');
      await courier.post(
        '/entregas/$id/coletar',
      ); // Retry não cria nova coleta.
      await waitFor(
        tester,
        trackingStatus('SAIU_ENTREGA'),
        timeout: const Duration(seconds: 45),
        step: 'entregador coletou',
      );
      final codeCard = find.byKey(const Key('cartao-codigo-entrega'));
      await waitFor(
        tester,
        codeCard,
        step: 'exibir código somente após coleta',
      );
      final code = tester
          .widgetList<Text>(
            find.descendant(of: codeCard, matching: find.byType(Text)),
          )
          .map((w) => w.data ?? '')
          .singleWhere((s) => RegExp(r'^\d{4}$').hasMatch(s));
      expect((await clientOrder(id))['codigoEntrega'], code);
      final wrong = code == '0000' ? '0001' : '0000';
      final denied = await courier.post(
        '/entregas/$id/concluir',
        data: {'codigo': wrong},
        options: Options(
          validateStatus: (s) => s != null && s >= 400 && s < 500,
        ),
      );
      expect((denied.data as Map)['error'], 'CODIGO_ENTREGA_INVALIDO');
      expect((await clientOrder(id))['status'], 'SAIU_ENTREGA');
      await courier.post('/entregas/$id/concluir', data: {'codigo': code});
      await courier.post('/entregas/$id/concluir', data: {'codigo': code});
      await waitFor(
        tester,
        find.byType(PedidoEntreguePage),
        step: 'abrir pedido entregue',
      );
      await waitFor(
        tester,
        find.text('Pedido entregue!'),
        step: 'confirmar baixa na UI',
      );
      expect(find.byKey(const Key('cartao-codigo-entrega')), findsNothing);
      final order = await clientOrder(id);
      expect(order['status'], 'ENTREGUE');
      expect(order['codigoEntrega'], isNull);
      expect(
        (await ApiClient().dio.get<List<dynamic>>('/pedidos/ativos')).data,
        isEmpty,
      );
      final state = (await courier.get<Map<String, dynamic>>(
        '/entregador/estado',
      )).data!;
      expect((state['perfil'] as Map)['statusOperacional'], 'ONLINE');
      expect(state['entrega'], isNull);
      final history =
          (await courier.get<Map<String, dynamic>>(
                '/entregador/entregas',
              )).data!['content']
              as List;
      expect(history, hasLength(1));
      expect((history.single as Map)['pedidoId'], id);
      expect((history.single as Map)['coletadoEm'], isNotNull);
      expect((history.single as Map)['entregueEm'], isNotNull);
      final earnings = (await courier.get<Map<String, dynamic>>(
        '/entregador/ganhos',
      )).data!;
      expect(earnings['totalEntregas'], 1);
      expect(earnings['totalGanhos'], 5);
      await expectSingleOrderAndStock(id, merchant);

      await tapE2E(
        tester,
        find.byKey(const Key('botao-avaliar-entregador')),
        step: 'avaliar entregador após entrega',
      );
      await tapE2E(
        tester,
        find.byKey(const Key('estrela-5')),
        step: 'dar cinco estrelas',
      );
      await tester.enterText(
        find.byKey(const Key('campo-comentario-avaliacao')),
        'Entrega E2E concluída',
      );
      await dismissE2EKeyboard(tester);
      await tapE2E(
        tester,
        find.byKey(const Key('botao-enviar-avaliacao')),
        step: 'enviar avaliação',
      );
      await waitFor(
        tester,
        find.text('Obrigado pela sua avaliação!'),
        step: 'confirmar avaliação',
      );
      final rating = (await ApiClient().dio.get<Map<String, dynamic>>(
        '/pedidos/$id/avaliacao-entregador',
      )).data!;
      expect(rating['nota'], 5);
      expect((await clientOrder(id))['entregadorAvaliado'], isTrue);
    },
    skip: !E2EConfig.runE2E,
  );
}
