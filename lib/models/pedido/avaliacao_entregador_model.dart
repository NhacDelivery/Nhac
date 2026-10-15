class AvaliacaoEntregadorModel {
  final String id;
  final int nota;
  final String? comentario;
  final DateTime? criadoEm;

  const AvaliacaoEntregadorModel({
    required this.id,
    required this.nota,
    this.comentario,
    this.criadoEm,
  });

  factory AvaliacaoEntregadorModel.fromMap(Map<String, dynamic> map) {
    return AvaliacaoEntregadorModel(
      id: map['id']?.toString() ?? '',
      nota: (map['nota'] as num?)?.toInt() ?? 0,
      comentario: map['comentario']?.toString(),
      criadoEm: DateTime.tryParse(map['criadoEm']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'nota': nota,
    'comentario': comentario,
    'criadoEm': criadoEm?.toIso8601String(),
  };
}
