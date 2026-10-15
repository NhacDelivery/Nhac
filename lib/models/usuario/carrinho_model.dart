import 'package:uuid/uuid.dart';
import 'package:nhac/utils/safe_parse_helpers.dart';

class CartItemModel {
  final String produtoId;
  final List<String> adicionais;
  final List<String> adicionaisNomes;
  final List<String> unidades;
  String get chave => adicionais.isEmpty
      ? produtoId
      : '$produtoId:${(List.of(adicionais)..sort()).join(',')}';
  final String nome;
  final String imagemUrl;
  final double preco;
  final String lojaId;
  int quantidade;
  bool esgotado;

  CartItemModel({
    required this.produtoId,
    required this.nome,
    required this.imagemUrl,
    required this.preco,
    required this.lojaId,
    List<String> adicionais = const [],
    this.adicionaisNomes = const [],
    List<String>? unidades,
    this.quantidade = 1,
    this.esgotado = false,
  }) : adicionais = List.unmodifiable(adicionais),
       unidades =
           unidades ?? List.generate(quantidade, (_) => const Uuid().v4());

  Map<String, dynamic> toMap() {
    return {
      'produtoId': produtoId,
      'adicionais': adicionais,
      'adicionaisNomes': adicionaisNomes,
      'unidades': unidades,
      'nome': nome,
      'imagemUrl': imagemUrl,
      'precoHistorico': preco,
      'lojaId': lojaId,
      'quantidade': quantidade,
      'esgotado': esgotado,
    };
  }

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      produtoId: map['produtoId'] ?? '',
      adicionais: List<String>.from(map['adicionais'] ?? []),
      adicionaisNomes: List<String>.from(map['adicionaisNomes'] ?? []),
      unidades: map['unidades'] == null
          ? null
          : List<String>.from(map['unidades']),
      nome: map['nome'] ?? '',
      imagemUrl: map['imagemUrl'] ?? '',
      preco:
          num.tryParse(map['precoHistorico']?.toString() ?? '0')?.toDouble() ??
          0.0,
      lojaId: map['lojaId']?.toString() ?? '',
      quantidade: safeInt(map['quantidade'], fallback: 1),
      esgotado: map['esgotado'] ?? false,
    );
  }
}
