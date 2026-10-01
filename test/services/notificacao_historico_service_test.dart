import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/services/notificacao_historico_service.dart';

void main() {
  test('avisos locais não aparecem em outra conta e não duplicam por ID', () async {
    SharedPreferences.setMockInitialValues({});
    final aviso = NotificacaoRegistrada('m1', 'Pedido em preparo', 'A loja começou', DateTime.utc(2026, 9, 28));
    await NotificacaoHistoricoService.registrar('cliente-a', aviso);
    await NotificacaoHistoricoService.registrar('cliente-a', aviso);
    expect((await NotificacaoHistoricoService.listar('cliente-a')).length, 1);
    expect(await NotificacaoHistoricoService.listar('cliente-b'), isEmpty);
  });

  test('Status salvo por push e rastreio aparece só uma vez', () async {
    SharedPreferences.setMockInitialValues({});
    await NotificacaoHistoricoService.registrarStatus('u1', 'p1', StatusPedido.entregue);
    await NotificacaoHistoricoService.registrarStatus('u1', 'p1', StatusPedido.entregue);
    final avisos = await NotificacaoHistoricoService.listar('u1');
    expect(avisos, hasLength(1));
    expect(avisos.single.status, StatusPedido.entregue);
    expect(avisos.single.pedidoId, 'p1');
  });

  test('Gravações simultâneas de pedidos diferentes não perdem avisos', () async {
    SharedPreferences.setMockInitialValues({});
    await Future.wait(List.generate(10, (i) => NotificacaoHistoricoService.registrarStatus('u1', 'p$i', StatusPedido.preparando)));
    expect(await NotificacaoHistoricoService.listar('u1'), hasLength(10));
  });

  test('Mantém os 50 avisos recentes em ordem de recebimento', () async {
    SharedPreferences.setMockInitialValues({});
    for (var i = 0; i < 55; i++) {
      await NotificacaoHistoricoService.registrar('u1', NotificacaoRegistrada('m$i', 'Aviso', 'Corpo', DateTime.utc(2026, 9, 28).add(Duration(minutes: i))));
    }
    final avisos = await NotificacaoHistoricoService.listar('u1');
    expect(avisos, hasLength(50));
    expect(avisos.first.id, 'm54');
    expect(avisos.last.id, 'm5');
  });

  test('Registros antigos e corrompidos não impedem abrir o histórico', () async {
    final antigo = NotificacaoRegistrada('m1', 'Pedido', 'Em preparo', DateTime.utc(2026, 9, 28));
    SharedPreferences.setMockInitialValues({'avisos_u1': ['inválido', jsonEncode(antigo.toJson())]});
    await NotificacaoHistoricoService.registrarStatus('u1', 'p2', StatusPedido.preparando);
    expect(await NotificacaoHistoricoService.listar('u1'), hasLength(2));
  });
}
