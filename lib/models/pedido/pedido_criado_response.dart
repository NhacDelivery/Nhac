import 'package:nhac/models/pedido/pagamento_pendente_model.dart';

class PedidoCriadoResponse {
  final String pedidoId;
  final String? clientSecret;
  final String? pixCopiaECola;
  final String? qrCodeUrl;
  final bool replay;
  final PagamentoPendenteModel? pagamentoPix;

  const PedidoCriadoResponse({
    required this.pedidoId,
    this.clientSecret,
    this.pixCopiaECola,
    this.qrCodeUrl,
    this.replay = false,
    this.pagamentoPix,
  });

  factory PedidoCriadoResponse.fromMap(
    Map<String, dynamic> map, {
    bool replay = false,
  }) {
    final temPix = !replay && (map['pixCopiaECola']?.toString().trim().isNotEmpty ?? false) &&
        map['valorTotal'] is num && DateTime.tryParse(map['expiraEm']?.toString() ?? '') != null;
    return PedidoCriadoResponse(
      pedidoId: map['pedidoId']?.toString() ?? '',
      clientSecret: map['clientSecret']?.toString(),
      pixCopiaECola: map['pixCopiaECola']?.toString(),
      qrCodeUrl: map['qrCodeUrl']?.toString(),
      replay: replay,
      pagamentoPix: temPix ? PagamentoPendenteModel.fromMap({...map, 'formaPagamento': 'PIX', 'status': 'PENDENTE'}) : null,
    );
  }
}
