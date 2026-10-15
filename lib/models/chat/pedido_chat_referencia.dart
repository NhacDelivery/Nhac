import 'package:intl/intl.dart';
import 'package:nhac/models/pedido_model.dart';

/// Referência de um pedido enviada no chat. Como em [ProdutoChatReferencia],
/// o contexto viaja no próprio `conteudo` da mensagem, para ser persistido pelo
/// backend e lido igual pelo app do cliente e pelo painel da loja:
///
///   Pedido: #ABCD1234
///   ID: (id completo)
///   Resumo: 2x Pizza, 1x Refrigerante
///   Total: R$ 52,90
///   Status: Em preparo        (opcional)
///   (linha vazia)
///   (mensagem do cliente)     (opcional)
class PedidoChatReferencia {
  const PedidoChatReferencia({
    required this.codigo,
    required this.id,
    required this.resumo,
    required this.total,
    this.status,
    this.mensagem = '',
  });

  final String codigo, id, resumo, total, mensagem;
  final String? status;

  static const int _limiteResumo = 140;

  factory PedidoChatReferencia.fromPedido(PedidoModel pedido) {
    final itens =
        pedido.itens.map((i) => '${i.quantidade}x ${i.nome}').join(', ');
    final resumo = itens.length > _limiteResumo
        ? '${itens.substring(0, _limiteResumo - 1).trimRight()}…'
        : itens;
    final idCurto =
        pedido.id.length > 8 ? pedido.id.substring(0, 8) : pedido.id;
    return PedidoChatReferencia(
      codigo: '#${idCurto.toUpperCase()}',
      id: pedido.id,
      resumo: resumo.isEmpty ? 'Sem itens informados' : resumo,
      total: NumberFormat.currency(
        locale: 'pt_BR',
        symbol: 'R\$',
      ).format(pedido.valorTotal),
      status: pedido.status.label,
    );
  }

  PedidoChatReferencia comMensagem(String texto) => PedidoChatReferencia(
        codigo: codigo,
        id: id,
        resumo: resumo,
        total: total,
        status: status,
        mensagem: texto,
      );

  static String _linha(String valor) =>
      valor.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

  String serializar() =>
      [
        'Pedido: ${_linha(codigo)}',
        'ID: ${_linha(id)}',
        'Resumo: ${_linha(resumo)}',
        'Total: ${_linha(total)}',
        if (status?.isNotEmpty == true) 'Status: ${_linha(status!)}',
      ].join('\n') +
      (mensagem.isEmpty ? '' : '\n\n$mensagem');

  static PedidoChatReferencia? ler(String conteudo) {
    final match = RegExp(
      r'^Pedido: ([^\n]+)\nID: ([^\n]+)\nResumo: ([^\n]+)\nTotal: ([^\n]+)(?:\nStatus: ([^\n]+))?(?:\n\n([\s\S]*))?$',
    ).firstMatch(conteudo.replaceAll('\r\n', '\n'));
    if (match == null) return null;
    return PedidoChatReferencia(
      codigo: match[1]!,
      id: match[2]!,
      resumo: match[3]!,
      total: match[4]!,
      status: match[5],
      mensagem: match[6] ?? '',
    );
  }
}
