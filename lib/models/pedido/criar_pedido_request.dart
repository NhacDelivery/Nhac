import 'package:nhac/models/usuario/carrinho_model.dart';
import 'package:nhac/models/usuario/endereco_model.dart';

class CriarPedidoItemRequest {
  final String produtoId;
  final String nome;
  final String? imagemUrl;
  final int quantidade;
  final List<String> adicionais;
  final List<String> unidades;

  const CriarPedidoItemRequest({
    required this.produtoId,
    required this.nome,
    this.imagemUrl,
    required this.quantidade,
    this.adicionais = const [],
    this.unidades = const [],
  });

  factory CriarPedidoItemRequest.fromCartItem(CartItemModel item) {
    return CriarPedidoItemRequest(
      produtoId: item.produtoId,
      adicionais: item.adicionais,
      unidades: List.of(item.unidades),
      nome: item.nome,
      imagemUrl: item.imagemUrl.isEmpty ? null : item.imagemUrl,
      quantidade: item.quantidade,
    );
  }
  Map<String, dynamic> toMap() => {
    'produtoId': produtoId,
    // O backend atual ainda valida nome como obrigatório, embora use o
    // cadastro real do produto para persistir o snapshot.
    'nome': nome,
    if (imagemUrl != null && imagemUrl!.isNotEmpty) 'imagemUrl': imagemUrl,
    'quantidade': quantidade,
    if (adicionais.isNotEmpty) 'adicionais': adicionais,
  };
}

class CriarPedidoRequest {
  final String lojaId;
  final String formaPagamento;
  final double? trocoPara;
  final String? observacao;
  final String? cupomId;
  final String? cpfPagador;
  final EnderecoModel enderecoEntrega;
  final double? entregaLatitude, entregaLongitude;
  final List<CriarPedidoItemRequest> itens;

  const CriarPedidoRequest({
    required this.lojaId,
    required this.formaPagamento,
    this.trocoPara,
    this.observacao,
    this.cupomId,
    this.cpfPagador,
    required this.enderecoEntrega,
    this.entregaLatitude,
    this.entregaLongitude,
    required this.itens,
  });

  List<String> get origemCarrinho => itens.expand((i) => i.unidades).toList();

  Map<String, dynamic> toMap() => {
    'lojaId': lojaId,
    'formaPagamento': formaPagamento,
    if (trocoPara != null) 'trocoPara': trocoPara,
    if (observacao != null && observacao!.trim().isNotEmpty)
      'observacao': observacao!.trim(),
    if (cupomId != null && cupomId!.trim().isNotEmpty) 'cupomId': cupomId,
    if (cpfPagador != null && cpfPagador!.trim().isNotEmpty)
      'cpfPagador': cpfPagador,
    'enderecoEntrega': {
      'rua': enderecoEntrega.rua,
      'numero': enderecoEntrega.numero,
      'bairro': enderecoEntrega.bairro,
      'cidade': enderecoEntrega.cidade,
      'estado': enderecoEntrega.estado,
      'cep': enderecoEntrega.cep,
      if (enderecoEntrega.complemento?.isNotEmpty == true)
        'complemento': enderecoEntrega.complemento,
      if (entregaLatitude != null) 'latitude': entregaLatitude,
      if (entregaLongitude != null) 'longitude': entregaLongitude,
    },
    'itens': itens.map((item) => item.toMap()).toList(),
  };
}
