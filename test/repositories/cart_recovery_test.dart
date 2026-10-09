import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/models/usuario/carrinho_model.dart';
import 'package:nhac/repositories/cart_repository.dart';

CartItemModel item(
  String id,
  int qtd, {
  String loja = 'loja',
  List<String> adicionais = const [],
}) => CartItemModel(
  produtoId: id,
  nome: id,
  imagemUrl: '',
  preco: 10,
  lojaId: loja,
  quantidade: qtd,
  adicionais: adicionais,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'recuperação consome só as unidades originais e mantém novas adições',
    () async {
      final repo = CartRepository(usuarioId: 'u1');
      final original = item('a', 2);
      final origem = List<String>.of(original.unidades);
      original.unidades.addAll(item('a', 3).unidades);
      original.quantidade = 5;
      await repo.salvarCarrinhoLocal([original, item('b', 2)]);
      final payload = {'lojaId': 'loja', '_origemCarrinho': origem};
      await repo.consumirPedido('pedido', payload);
      var items = await repo.carregarCarrinhoLocal();
      expect(items.first.quantidade, 3);
      expect(items.last.quantidade, 2);
      items.first.unidades.addAll(item('a', 1).unidades);
      items.first.quantidade++;
      await repo.salvarCarrinhoLocal(items);
      await repo.consumirPedido('pedido', payload);
      items = await repo.carregarCarrinhoLocal();
      expect(items.first.quantidade, 4);
      expect(
        await CartRepository(usuarioId: 'u2').carregarCarrinhoLocal(),
        isEmpty,
      );
    },
  );
  test('retirar e adicionar novamente o mesmo produto preserva todas as unidades novas', () async {
    final repo = CartRepository(usuarioId: 'u1');
    final antigo = item('a', 2);
    await repo.salvarCarrinhoLocal([antigo]);
    await repo.limparCarrinho();
    final novo = item('a', 2);
    await repo.salvarCarrinhoLocal([novo]);
    await repo.consumirPedido('pedido', {
      'lojaId': 'loja',
      '_origemCarrinho': antigo.unidades,
    });
    expect((await repo.carregarCarrinhoLocal()).single.unidades, novo.unidades);
  });
  test(
    'limpar carrinho mantém recibos e replay não consome itens novos',
    () async {
      final repo = CartRepository(usuarioId: 'u1');
      final antigo = item('a', 2);
      final payload = {'lojaId': 'loja', '_origemCarrinho': antigo.unidades};
      await repo.salvarCarrinhoLocal([antigo]);
      await repo.consumirPedido('pedido', payload);
      await repo.limparCarrinho();
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(
          prefs.getString('@nhac_cart_items:u1')!,
        )['pedidosConsumidos'],
        ['pedido'],
      );
      await repo.salvarCarrinhoLocal([item('a', 3)]);
      await repo.consumirPedido('pedido', payload);
      expect((await repo.carregarCarrinhoLocal()).single.quantidade, 3);
    },
  );
  test(
    'variantes e outra loja não são consumidas por coincidência de produto',
    () async {
      final repo = CartRepository(usuarioId: 'u1');
      final comprado = item('a', 1, adicionais: ['molho']);
      final outro = item('a', 2, adicionais: ['queijo']);
      await repo.salvarCarrinhoLocal([comprado, outro]);
      await repo.consumirPedido('pedido', {
        'lojaId': 'loja',
        '_origemCarrinho': comprado.unidades,
      });
      expect((await repo.carregarCarrinhoLocal()).single.adicionais, [
        'queijo',
      ]);
      await repo.consumirPedido('pedido-outra', {
        'lojaId': 'outra',
        '_origemCarrinho': outro.unidades,
      });
      expect((await repo.carregarCarrinhoLocal()).single.quantidade, 2);
    },
  );
  test('tentativa antiga sem proveniência não remove novas compras', () async {
    final repo = CartRepository(usuarioId: 'u1');
    await repo.salvarCarrinhoLocal([item('a', 2)]);
    await repo.consumirPedido('legado', {
      'lojaId': 'loja',
      'itens': [
        {'produtoId': 'a', 'quantidade': 2},
      ],
    });
    expect((await repo.carregarCarrinhoLocal()).single.quantidade, 2);
  });
}
