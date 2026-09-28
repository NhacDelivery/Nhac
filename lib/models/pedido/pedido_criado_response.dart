class PedidoCriadoResponse {
  final String pedidoId;
  final String? clientSecret;
  final String? pixCopiaECola;
  final String? qrCodeUrl;
  final bool replay;

  const PedidoCriadoResponse({
    required this.pedidoId,
    this.clientSecret,
    this.pixCopiaECola,
    this.qrCodeUrl,
    this.replay = false,
  });

  factory PedidoCriadoResponse.fromMap(
    Map<String, dynamic> map, {
    bool replay = false,
  }) {
    return PedidoCriadoResponse(
      pedidoId: map['pedidoId']?.toString() ?? '',
      clientSecret: map['clientSecret']?.toString(),
      pixCopiaECola: map['pixCopiaECola']?.toString(),
      qrCodeUrl: map['qrCodeUrl']?.toString(),
      replay: replay,
    );
  }
}
