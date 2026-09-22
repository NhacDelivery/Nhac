class PontoCoordenadaModel {
  final double latitude;
  final double longitude;

  const PontoCoordenadaModel({
    required this.latitude,
    required this.longitude,
  });

  factory PontoCoordenadaModel.fromMap(Map<String, dynamic> map) {
    return PontoCoordenadaModel(
      latitude:
          num.tryParse(map['latitude']?.toString() ?? '0')?.toDouble() ?? 0,
      longitude:
          num.tryParse(map['longitude']?.toString() ?? '0')?.toDouble() ?? 0,
    );
  }
}

class RotaEntregaModel {
  final String pedidoId;
  final String lojaNome;
  final PontoCoordenadaModel origem;
  final PontoCoordenadaModel destino;
  final double distanciaKm;
  final int duracaoEstimadaMinutos;
  final List<PontoCoordenadaModel> waypoints;

  const RotaEntregaModel({
    required this.pedidoId,
    required this.lojaNome,
    required this.origem,
    required this.destino,
    required this.distanciaKm,
    required this.duracaoEstimadaMinutos,
    required this.waypoints,
  });

  factory RotaEntregaModel.fromMap(Map<String, dynamic> map) {
    return RotaEntregaModel(
      pedidoId: map['pedidoId']?.toString() ?? '',
      lojaNome: map['lojaNome']?.toString() ?? '',
      origem: PontoCoordenadaModel.fromMap(
        Map<String, dynamic>.from(map['origem'] ?? const {}),
      ),
      destino: PontoCoordenadaModel.fromMap(
        Map<String, dynamic>.from(map['destino'] ?? const {}),
      ),
      distanciaKm:
          num.tryParse(map['distanciaKm']?.toString() ?? '0')?.toDouble() ?? 0,
      duracaoEstimadaMinutos:
          int.tryParse(map['duracaoEstimadaMinutos']?.toString() ?? '0') ?? 0,
      waypoints: (map['waypoints'] as List? ?? const [])
          .map((p) => PontoCoordenadaModel.fromMap(
                Map<String, dynamic>.from(p as Map),
              ))
          .toList(),
    );
  }
}
