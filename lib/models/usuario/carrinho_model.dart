import 'package:nhac/utils/safe_parse_helpers.dart';

class CartItemModel {
  final String produtoId;
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
    this.quantidade = 1,
    this.esgotado = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'produtoId': produtoId,
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
      nome: map['nome'] ?? '',
      imagemUrl: map['imagemUrl'] ?? '',
      preco: num.tryParse(map['precoHistorico']?.toString() ?? '0')?.toDouble() ?? 0.0,
      lojaId: map['lojaId']?.toString() ?? '',  
      quantidade: safeInt(map['quantidade'], fallback: 1),
      esgotado: map['esgotado'] ?? false,
    );
  }
}
