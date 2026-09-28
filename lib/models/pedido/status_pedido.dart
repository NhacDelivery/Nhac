enum StatusPedido {
  pendente,
  pago,
  preparando,
  saiuEntrega,
  entregue,
  cancelado,
  desconhecido;

  static StatusPedido fromApi(String? valor) {
    switch ((valor ?? '').trim().toUpperCase()) {
      case 'PENDENTE':
      case 'AGUARDANDO_PAGAMENTO':
        return StatusPedido.pendente;
      case 'PAGO':
      case 'CONFIRMADO':
      case 'APROVADO':
        return StatusPedido.pago;
      case 'PREPARANDO':
      case 'EM_PREPARO':
        return StatusPedido.preparando;
      case 'SAIU_ENTREGA':
      case 'SAIU_PARA_ENTREGA':
        return StatusPedido.saiuEntrega;
      case 'ENTREGUE':
        return StatusPedido.entregue;
      case 'CANCELADO':
      case 'RECUSADO':
      case 'EXPIRADO':
      case 'FALHOU':
        return StatusPedido.cancelado;
      default:
        return StatusPedido.desconhecido;
    }
  }

  String get apiValue {
    switch (this) {
      case StatusPedido.pendente:
        return 'PENDENTE';
      case StatusPedido.pago:
        return 'PAGO';
      case StatusPedido.preparando:
        return 'PREPARANDO';
      case StatusPedido.saiuEntrega:
        return 'SAIU_ENTREGA';
      case StatusPedido.entregue:
        return 'ENTREGUE';
      case StatusPedido.cancelado:
        return 'CANCELADO';
      case StatusPedido.desconhecido:
        return 'DESCONHECIDO';
    }
  }

  String get label {
    switch (this) {
      case StatusPedido.pendente:
        return 'Aguardando pagamento';
      case StatusPedido.pago:
        return 'Pagamento confirmado';
      case StatusPedido.preparando:
        return 'Em preparo';
      case StatusPedido.saiuEntrega:
        return 'Saiu para entrega';
      case StatusPedido.entregue:
        return 'Entregue';
      case StatusPedido.cancelado:
        return 'Pedido cancelado';
      case StatusPedido.desconhecido:
        return 'Pedido em andamento';
    }
  }

  int get stage {
    switch (this) {
      case StatusPedido.pendente:
        return 0;
      case StatusPedido.pago:
        return 1;
      case StatusPedido.preparando:
        return 2;
      case StatusPedido.saiuEntrega:
        return 3;
      case StatusPedido.entregue:
        return 4;
      case StatusPedido.cancelado:
      case StatusPedido.desconhecido:
        return 0;
    }
  }

  bool get pagamentoConfirmado =>
      this == StatusPedido.pago ||
      this == StatusPedido.preparando ||
      this == StatusPedido.saiuEntrega ||
      this == StatusPedido.entregue;

  bool get terminal =>
      this == StatusPedido.entregue || this == StatusPedido.cancelado;
}
