import 'package:nhac/models/pedido/status_pedido.dart';

class PedidoResumoModel {
  final String id;
  final String lojaId;
  final String lojaNome;
  final double valorTotal;
  final StatusPedido status;
  final DateTime? criadoEm;

  const PedidoResumoModel({
    required this.id,
    required this.lojaId,
    required this.lojaNome,
    required this.valorTotal,
    required this.status,
    this.criadoEm,
  });

  factory PedidoResumoModel.fromMap(Map<String, dynamic> map) {
    return PedidoResumoModel(
      id: map['id']?.toString() ?? '',
      lojaId: map['lojaId']?.toString() ?? '',
      lojaNome: map['lojaNome']?.toString() ?? '',
      valorTotal:
          num.tryParse(map['valorTotal']?.toString() ?? '0')?.toDouble() ?? 0,
      status: StatusPedido.fromApi(map['status']?.toString()),
      criadoEm: DateTime.tryParse(map['criadoEm']?.toString() ?? ''),
    );
  }
}
