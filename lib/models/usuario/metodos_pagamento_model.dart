import 'package:nhac/utils/safe_parse_helpers.dart';

class MetodosPagamentoModel {
  final String id;
  final String bandeira;
  final String? criadoEm;
  final String nomeCartao;
  final bool isPadrao;
  final String tipo;
  final String ultimosDigitos;

  MetodosPagamentoModel({
    required this.id,
    required this.bandeira,
    this.criadoEm,
    required this.nomeCartao,
    this.isPadrao = false,
    required this.tipo,
    required this.ultimosDigitos,
  });

  factory MetodosPagamentoModel.fromMap(Map<String, dynamic> map) {
    return MetodosPagamentoModel(
      id: map['id']?.toString() ?? '',
      bandeira: map['bandeira'] ?? '',
      criadoEm: map['criadoEm']?.toString(), 
      nomeCartao: map['nomeCartao'] ?? '',
      isPadrao: safeBool(map['isPadrao']),
      tipo: map['tipo'] ?? '',
      ultimosDigitos: map['ultimosDigitos'] ?? '',
    );
  }

  MetodosPagamentoModel copyWith({
    String? id,
    String? bandeira,
    String? criadoEm,
    String? nomeCartao,
    bool? isPadrao,
    String? tipo,
    String? ultimosDigitos,
  }) =>
      MetodosPagamentoModel(
        id: id ?? this.id,
        bandeira: bandeira ?? this.bandeira,
        criadoEm: criadoEm ?? this.criadoEm,
        nomeCartao: nomeCartao ?? this.nomeCartao,
        isPadrao: isPadrao ?? this.isPadrao,
        tipo: tipo ?? this.tipo,
        ultimosDigitos: ultimosDigitos ?? this.ultimosDigitos,
      );

  Map<String, dynamic> toMap() {
    return {
      'bandeira': bandeira,
      if (criadoEm != null) 'criadoEm': criadoEm,
      'nomeCartao': nomeCartao,
      'isPadrao': isPadrao,
      'tipo': tipo,
      'ultimosDigitos': ultimosDigitos,
    };
  }
}
