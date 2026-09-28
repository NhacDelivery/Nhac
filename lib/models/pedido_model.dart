import 'package:nhac/models/pedido/item_pedido_model.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/models/usuario/endereco_model.dart';

class PedidoModel {
  final String id;
  final String usuarioId;
  final String lojaId;
  final String lojaNome;
  final double valorTotal;
  final double taxaFrete;
  final String formaPagamento;
  final double? trocoPara;
  final String? observacao;
  final EnderecoModel enderecoEntrega;
  final List<ItemPedidoModel> itens;
  final StatusPedido status;
  final DateTime? criadoEm;

  const PedidoModel({
    required this.id,
    required this.usuarioId,
    required this.lojaId,
    required this.lojaNome,
    required this.valorTotal,
    required this.taxaFrete,
    required this.formaPagamento,
    this.trocoPara,
    this.observacao,
    required this.enderecoEntrega,
    required this.itens,
    required this.status,
    this.criadoEm,
  });

  String get statusApi => status.apiValue;

  factory PedidoModel.fromMap(Map<String, dynamic> map) {
    return PedidoModel(
      id: map['id']?.toString() ?? '',
      usuarioId: map['usuarioId']?.toString() ?? '',
      lojaId: map['lojaId']?.toString() ?? '',
      lojaNome: map['lojaNome']?.toString() ?? '',
      valorTotal:
          num.tryParse(map['valorTotal']?.toString() ?? '0')?.toDouble() ?? 0,
      taxaFrete:
          num.tryParse(map['taxaFrete']?.toString() ?? '0')?.toDouble() ?? 0,
      formaPagamento: map['formaPagamento']?.toString() ?? '',
      trocoPara: map['trocoPara'] == null
          ? null
          : num.tryParse(map['trocoPara'].toString())?.toDouble(),
      observacao: map['observacao']?.toString(),
      enderecoEntrega: EnderecoModel.fromMap(
        Map<String, dynamic>.from(map['enderecoEntrega'] ?? const {}),
      ),
      itens: (map['itens'] as List? ?? const [])
          .map((item) => ItemPedidoModel.fromMap(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      status: StatusPedido.fromApi(map['status']?.toString()),
      criadoEm: DateTime.tryParse(map['criadoEm']?.toString() ?? ''),
    );
  }
}
