import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/models/pedido/criar_pedido_request.dart';
import 'package:nhac/models/pedido/entregador_pedido_model.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/models/usuario/carrinho_model.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/services/local_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    expect(pedido.codigoEntrega, isNull);
    expect(pedido.entregador, isNull);
    expect(pedido.entregadorAvaliado, false);
  });

  test('parsing de PedidoModel tolera ausência de codigoEntrega, entregador e entregadorAvaliado', () {
    final pedido = PedidoModel.fromMap({
      'id': 'ped_sem_novos',
      'usuarioId': 'user1',
      'lojaId': 'loja1',
      'lojaNome': 'Loja Teste',
      'valorTotal': 40.0,
      'taxaFrete': 5.0,
      'formaPagamento': 'PIX',
      'enderecoEntrega': endereco.toMap(),
      'itens': [],
      'status': 'PREPARANDO',
    });

    expect(pedido.codigoEntrega, isNull);
    expect(pedido.entregador, isNull);
    expect(pedido.entregadorAvaliado, isFalse);
  });

  test('parsing de PedidoModel mapeia codigoEntrega, entregador e entregadorAvaliado quando presentes', () {
    final pedido = PedidoModel.fromMap({
      'id': 'ped_completo',
      'usuarioId': 'user1',
      'lojaId': 'loja1',
      'lojaNome': 'Loja Teste',
      'valorTotal': 45.0,
      'taxaFrete': 6.0,
      'formaPagamento': 'PIX',
      'enderecoEntrega': endereco.toMap(),
      'itens': [],
      'status': 'SAIU_ENTREGA',
      'codigoEntrega': '1234',
      'entregador': {
        'nome': 'Carlos S.',
        'fotoUrl': 'https://example.com/foto.jpg',
        'tipoVeiculo': 'MOTO',
        'modeloVeiculo': 'CG 160',
        'corVeiculo': 'Preta',
        'placaVeiculo': 'ABC1D23',
        'avaliacaoMedia': 4.8,
        'totalAvaliacoes': 12,
      },
      'entregadorAvaliado': true,
    });

    expect(pedido.codigoEntrega, '1234');
    expect(pedido.entregador, isNotNull);
    expect(pedido.entregador!.nome, 'Carlos S.');
    expect(pedido.entregador!.fotoUrl, 'https://example.com/foto.jpg');
    expect(pedido.entregador!.tipoVeiculo, 'MOTO');
    expect(pedido.entregador!.modeloVeiculo, 'CG 160');
    expect(pedido.entregador!.corVeiculo, 'Preta');
    expect(pedido.entregador!.placaVeiculo, 'ABC1D23');
    expect(pedido.entregador!.avaliacaoMedia, 4.8);
    expect(pedido.entregador!.totalAvaliacoes, 12);
    expect(pedido.entregadorAvaliado, isTrue);
  });

  test('toMap e salvarSnapshotPedido nunca gravam codigoEntrega no disco', () async {
    SharedPreferences.setMockInitialValues({});
    final pedido = PedidoModel(
      id: 'ped_seguro',
      usuarioId: 'user_seguro',
      lojaId: 'loja1',
      lojaNome: 'Loja Segura',
      valorTotal: 50.0,
      taxaFrete: 5.0,
      formaPagamento: 'PIX',
      enderecoEntrega: endereco,
      itens: const [],
      status: StatusPedido.saiuEntrega,
      codigoEntrega: '9988',
      entregador: const EntregadorPedidoModel(nome: 'Marcos R.'),
      entregadorAvaliado: false,
    );

    // 1. toMap() não deve conter a chave 'codigoEntrega'
    final map = pedido.toMap();
    expect(map.containsKey('codigoEntrega'), isFalse);

    // 2. Snapshot salvo em disco no LocalCacheService não deve conter 'codigoEntrega' nem o valor '9988'
    await LocalCacheService.salvarSnapshotPedido('user_seguro', pedido);
    final prefs = await SharedPreferences.getInstance();
    final rawSnapshot = prefs.getString('pedido_snapshot_user_seguro');
    expect(rawSnapshot, isNotNull);
    expect(rawSnapshot, isNot(contains('9988')));
    expect(rawSnapshot, isNot(contains('codigoEntrega')));

    // 3. Ao restaurar o snapshot, codigoEntrega é nulo
    final restaurado = await LocalCacheService.carregarSnapshotPedido('user_seguro');
    expect(restaurado, isNotNull);
    expect(restaurado!.codigoEntrega, isNull);
    expect(restaurado.entregador?.nome, 'Marcos R.');
  });
}
