import 'package:nhac/utils/safe_parse_helpers.dart';

class CupomModel {
  final String id;
  final String titulo;
  final String descricao;
  final String codigo;
  final double desconto;
  final String tipo; 
  final double usoMinimo;
  final String? dataValidade;
  final double descontoAplicado;
  final String status; 

  CupomModel({
    this.descontoAplicado = 0,
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.codigo,
    required this.desconto,
    required this.tipo,
    required this.usoMinimo,
    this.dataValidade,
    required this.status,
  });

  factory CupomModel.fromMap(Map<String, dynamic> map) {
    return CupomModel(
      descontoAplicado: safeDouble(map['descontoAplicado']),
      id: map['id']?.toString() ?? '',
      titulo: map['titulo'] ?? '',
      descricao: map['descricao'] ?? '',
      codigo: map['codigo'] ?? '',
      desconto: safeDouble(map['desconto']),
      tipo: map['tipo'] ?? 'FIXO',
      usoMinimo: safeDouble(map['usoMinimo']),
      dataValidade: map['dataValidade']?.toString(),
      status: map['status'] ?? 'DISPONIVEL',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'descontoAplicado': descontoAplicado,
      'titulo': titulo,
      'descricao': descricao,
      'codigo': codigo,
      'desconto': desconto,
      'tipo': tipo,
      'usoMinimo': usoMinimo,
      'dataValidade': dataValidade,
      'status': status,
    };
  }

  CupomModel copyWith({
    String? id,
    String? titulo,
    String? descricao,
    String? codigo,
    double? desconto,
    String? tipo,
    double? usoMinimo,
    String? dataValidade,
    String? status,
  }) {
    return CupomModel(
      descontoAplicado: descontoAplicado,
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      codigo: codigo ?? this.codigo,
      desconto: desconto ?? this.desconto,
      tipo: tipo ?? this.tipo,
      usoMinimo: usoMinimo ?? this.usoMinimo,
      dataValidade: dataValidade ?? this.dataValidade,
      status: status ?? this.status,
    );
  }
}
