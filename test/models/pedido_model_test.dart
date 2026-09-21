import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/models/pedido/criar_pedido_request.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/models/usuario/carrinho_model.dart';
import 'package:nhac/models/usuario/endereco_model.dart';

void main() {
  final endereco = EnderecoModel(
    id: 'end1',
    rua: 'Rua das Flores',
    numero: '123',
    bairro: 'Centro',
    cidade: 'São Paulo',
    estado: 'SP',
    cep: '01000-000',
    isPadrao: true,
  );

  test('request preserva campos exigidos pelo DTO sem enviar preço', () {
    final request = CriarPedidoRequest(
      lojaId: 'loja1',
      formaPagamento: 'PIX',
      cupomId: 'cupom1',
      enderecoEntrega: endereco,
      itens: [
        CriarPedidoItemRequest.fromCartItem(
          CartItemModel(
            produtoId: 'prod1',
            nome: 'Nome local',
            imagemUrl: 'imagem-local',
            preco: 1,
            lojaId: 'loja1',
            quantidade: 2,
          ),
        ),
      ],
    );

    final map = request.toMap();
    expect(map['lojaId'], 'loja1');
    expect(map['cupomId'], 'cupom1');
    expect(map['itens'][0], {
      'produtoId': 'prod1',
      'nome': 'Nome local',
      'imagemUrl': 'imagem-local',
      'quantidade': 2,
    });
  });

  test('response usa preco do DTO do backend e status canônico', () {
    final pedido = PedidoModel.fromMap({
      'id': 'ped1',
      'usuarioId': 'user1',
      'lojaId': 'loja1',
      'lojaNome': 'Nhac',
      'valorTotal': 55,
      'taxaFrete': 5,
      'formaPagamento': 'PIX',
      'enderecoEntrega': endereco.toMap(),
      'itens': [
        {
          'id': 'item1',
          'produtoId': 'prod1',
          'nome': 'Hambúrguer',
          'imagemUrl': 'img',
          'preco': 25,
          'quantidade': 2,
        }
      ],
      'status': 'SAIU_ENTREGA',
      'criadoEm': '2026-08-18T10:00:00Z',
    });

    expect(pedido.status, StatusPedido.saiuEntrega);
    expect(pedido.itens.single.preco, 25);
    expect(pedido.itens.single.quantidade, 2);
  });
}
