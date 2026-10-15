import 'package:nhac/models/pedido/status_pedido.dart';

class PagamentoPendenteModel {
  final String pedidoId;
  final String formaPagamento;
  final StatusPedido status;
  final DateTime? expiraEm;
  final double valorTotal;
  final String? pixCopiaECola;
  final String? qrCodeUrl;
  final String? clientSecret;
  final bool simulacaoDisponivel;

  const PagamentoPendenteModel({
    required this.pedidoId,
    required this.formaPagamento,
    required this.status,
    required this.expiraEm,
    required this.valorTotal,
    this.pixCopiaECola,
    this.qrCodeUrl,
    this.clientSecret,
    required this.simulacaoDisponivel,
  });

  factory PagamentoPendenteModel.fromMap(Map<String, dynamic> map) =>
      PagamentoPendenteModel(
        pedidoId: map['pedidoId']?.toString() ?? '',
        formaPagamento: map['formaPagamento']?.toString() ?? '',
        status: StatusPedido.fromApi(map['status']?.toString()),
        expiraEm: DateTime.tryParse(map['expiraEm']?.toString() ?? ''),
        valorTotal: num.tryParse(map['valorTotal']?.toString() ?? '0')?.toDouble() ?? 0,
        pixCopiaECola: map['pixCopiaECola']?.toString(),
        qrCodeUrl: map['qrCodeUrl']?.toString(),
        clientSecret: map['clientSecret']?.toString(),
        simulacaoDisponivel: map['simulacaoDisponivel'] == true,
      );
}
