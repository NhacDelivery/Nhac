class OperacaoPagamentoModel {
  final String estado;
  final bool podeSolicitarEstorno;
  const OperacaoPagamentoModel(
      {required this.estado, this.podeSolicitarEstorno = false});
  factory OperacaoPagamentoModel.fromMap(Map<String, dynamic> map) =>
      OperacaoPagamentoModel(
          estado: map['estado']?.toString() ?? 'DESCONHECIDO',
          podeSolicitarEstorno: map['podeSolicitarEstorno'] == true);
  bool get concluido => estado == 'ESTORNO_CONCLUIDO';
  bool get regular => estado == 'REGULAR';
  String get titulo => switch (estado) {
        'CONCILIACAO' => 'Pagamento em conferência',
        'ESTORNO_SOLICITADO' => 'Estorno solicitado',
        'ESTORNO_ENVIANDO' || 'ESTORNO_PROCESSANDO' => 'Estorno em andamento',
        'ESTORNO_CONCLUIDO' => 'Estorno concluído',
        'ESTORNO_REVISAO' => 'Estorno em análise',
        'REGULAR' => 'Cancelamento antes do preparo',
        _ => 'Atualize o acompanhamento do pagamento',
      };
  String get mensagem => switch (estado) {
        'CONCILIACAO' =>
          'Estamos conferindo a cobrança. Não pague novamente. Atualize para acompanhar o resultado.',
        'ESTORNO_CONCLUIDO' =>
          'A devolução integral foi confirmada pelo meio de pagamento. No cartão, a exibição depende da operadora.',
        'ESTORNO_REVISAO' =>
          'O pedido foi cancelado e a devolução precisa de análise. Não é necessário solicitar outro estorno.',
        'REGULAR' =>
          'Você pode cancelar enquanto a loja ainda não começou o preparo. O valor será devolvido pelo mesmo meio de pagamento.',
        'ESTORNO_SOLICITADO' || 'ESTORNO_ENVIANDO' || 'ESTORNO_PROCESSANDO' =>
          'O pedido foi cancelado. A devolução ainda não foi confirmada; você pode acompanhar por aqui.',
        _ => 'Não foi possível identificar o estado atual. Atualize para conferir o pagamento.',
      };
}
