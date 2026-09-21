import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/models/pedido/status_pedido.dart';

void main() {
  test('mapeia todos os status canônicos do backend', () {
    expect(StatusPedido.fromApi('PENDENTE'), StatusPedido.pendente);
    expect(StatusPedido.fromApi('PAGO'), StatusPedido.pago);
    expect(StatusPedido.fromApi('PREPARANDO'), StatusPedido.preparando);
    expect(StatusPedido.fromApi('SAIU_ENTREGA'), StatusPedido.saiuEntrega);
    expect(StatusPedido.fromApi('ENTREGUE'), StatusPedido.entregue);
    expect(StatusPedido.fromApi('CANCELADO'), StatusPedido.cancelado);
  });

  test('mantém aliases antigos apenas na borda de compatibilidade', () {
    expect(StatusPedido.fromApi('SAIU_PARA_ENTREGA'), StatusPedido.saiuEntrega);
    expect(StatusPedido.fromApi('EM_PREPARO'), StatusPedido.preparando);
    expect(StatusPedido.fromApi('CONFIRMADO'), StatusPedido.pago);
  });

  test('expõe estágio e confirmação de pagamento', () {
    expect(StatusPedido.pendente.pagamentoConfirmado, isFalse);
    expect(StatusPedido.pago.pagamentoConfirmado, isTrue);
    expect(StatusPedido.saiuEntrega.stage, 3);
    expect(StatusPedido.entregue.terminal, isTrue);
  });
}
