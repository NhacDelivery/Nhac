import 'package:nhac/utils/safe_parse_helpers.dart';

class ProdutosModel {
  final String id;
  final String nome;
  final String descricao;
  final double preco;
  final String categoriaMenu;
  final String imagemUrl;
  final int percentualDesconto;
  final String lojaId;
  final String lojaNome;
  final bool lojaAberta;
  final List<GrupoAdicionalModel> adicionais;

  ProdutosModel({
    required this.id,
    required this.nome,
    this.descricao = '',
    required this.preco,
    required this.categoriaMenu,
    this.imagemUrl = '',
    this.percentualDesconto = 0,
    this.lojaId = '',
    this.lojaNome = '',
    this.lojaAberta = true,
    this.adicionais = const [],
  });

  factory ProdutosModel.fromMap(Map<String, dynamic> map) {
    return ProdutosModel(
      id: map['id']?.toString() ?? '',
      adicionais: (map['adicionais'] as List? ?? [])
          .map(
            (g) => GrupoAdicionalModel.fromMap(
              Map<String, dynamic>.from(g as Map),
            ),
          )
          .toList(),
      nome: map['nome']?.toString() ?? '',
      descricao: map['descricao']?.toString() ?? '',
      preco: num.tryParse(map['preco']?.toString() ?? '0')?.toDouble() ?? 0.0,
      categoriaMenu: map['categoriaMenu']?.toString() ?? '',
      imagemUrl: map['imagemUrl']?.toString() ?? '',
      percentualDesconto: safeInt(map['percentualDesconto']),
      lojaId: map['lojaId']?.toString() ?? '',
      lojaNome: map['lojaNome']?.toString() ?? '',
      lojaAberta: safeBool(map['lojaAberta'], fallback: true),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'preco': preco,
      'categoriaMenu': categoriaMenu,
      'imagemUrl': imagemUrl,
      'percentualDesconto': percentualDesconto,
      'lojaId': lojaId,
      'lojaNome': lojaNome,
      'lojaAberta': lojaAberta,
      'adicionais': adicionais.map((g) => g.toMap()).toList(),
    };
  }
}

class ItemAdicionalModel {
  final String id, nome;
  final double preco;
  const ItemAdicionalModel(this.id, this.nome, this.preco);
  factory ItemAdicionalModel.fromMap(Map<String, dynamic> m) =>
      ItemAdicionalModel(
        m['id'] as String? ?? '',
        m['nome'] as String? ?? '',
        (m['preco'] as num? ?? 0).toDouble(),
      );
  Map<String, dynamic> toMap() => {'id': id, 'nome': nome, 'preco': preco};
}

class GrupoAdicionalModel {
  final String id, nome;
  final bool obrigatorio;
  final int minimo, maximo;
  final List<ItemAdicionalModel> itens;
  const GrupoAdicionalModel(
    this.id,
    this.nome,
    this.obrigatorio,
    this.minimo,
    this.maximo,
    this.itens,
  );
  factory GrupoAdicionalModel.fromMap(Map<String, dynamic> m) {
    final itens = (m['itens'] as List? ?? [])
        .map(
          (i) =>
              ItemAdicionalModel.fromMap(Map<String, dynamic>.from(i as Map)),
        )
        .toList();
    final minimo = (m['minimo'] as num? ?? 0).toInt();
    return GrupoAdicionalModel(
      m['id'] as String? ?? '',
      m['nome'] as String? ?? '',
      m['obrigatorio'] == true,
      m['obrigatorio'] == true && minimo < 1 ? 1 : minimo,
      (m['maximo'] as num? ?? itens.length).toInt(),
      itens,
    );
  }
  Map<String, dynamic> toMap() => {
    'id': id,
    'nome': nome,
    'obrigatorio': obrigatorio,
    'minimo': minimo,
    'maximo': maximo,
    'itens': itens.map((i) => i.toMap()).toList(),
  };
}
