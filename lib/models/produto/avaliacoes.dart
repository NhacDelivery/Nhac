import 'package:nhac/utils/safe_parse_helpers.dart';

class AvaliacoesModel {
  final String comentario;
  final String? criadoEm;
  final String id;
  final String nomeUsuario;
  final double nota;
  final String userId;

  AvaliacoesModel({
    this.comentario = '',
    this.criadoEm,
    required this.id,
    required this.nomeUsuario,
    required this.nota,
    required this.userId,
  });

  AvaliacoesModel copyWith({
    String? comentario,
    String? criadoEm,
    String? id,
    String? nomeUsuario,
    double? nota,
    String? userId,
  }) =>
      AvaliacoesModel(
        comentario: comentario ?? this.comentario,
        criadoEm: criadoEm ?? this.criadoEm,
        id: id ?? this.id,
        nomeUsuario: nomeUsuario ?? this.nomeUsuario,
        nota: nota ?? this.nota,
        userId: userId ?? this.userId,
      );

  factory AvaliacoesModel.fromMap(Map<String, dynamic> map, String docId) {
    return AvaliacoesModel(
      comentario: map['comentario'] ?? '',
      criadoEm: (map['dataCriacao'] ?? map['criadoEm'])?.toString(),
      id: docId,
      nomeUsuario: map['nomeUsuario'] ?? '',
      nota: safeDouble(map['nota']),
      userId: map['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'comentario': comentario,
      'criadoEm': criadoEm ?? DateTime.now().toIso8601String(),
      'nomeUsuario': nomeUsuario,
      'nota': nota,
      'userId': userId,
    };
  }
}
