class ItemPedidoModel {
  final String id;
  final String produtoId;
  final String nome;
  final String imagemUrl;
  final double preco;
  final int quantidade;

  const ItemPedidoModel({
    required this.id,
    required this.produtoId,
    required this.nome,
    required this.imagemUrl,
    required this.preco,
    required this.quantidade,
  });

  factory ItemPedidoModel.fromMap(Map<String, dynamic> map) {
    return ItemPedidoModel(
      id: map['id']?.toString() ?? '',
      produtoId: map['produtoId']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      imagemUrl: map['imagemUrl']?.toString() ?? '',
      preco: num.tryParse(map['preco']?.toString() ?? '0')?.toDouble() ?? 0,
      quantidade: int.tryParse(map['quantidade']?.toString() ?? '1') ?? 1,
    );
  }
}
