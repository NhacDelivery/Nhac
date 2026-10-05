import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/models/usuario/carrinho_model.dart';
import 'package:nhac/repositories/cart_repository.dart';

void main() {
  test(
    'recuperação remove só quantidades compradas e não repete consumo',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = CartRepository(usuarioId: 'u1');
      CartItemModel item(String id, int qtd) => CartItemModel(
        produtoId: id,
        nome: id,
        imagemUrl: '',
        preco: 10,
        lojaId: 'loja',
        quantidade: qtd,
      );
      await repo.salvarCarrinhoLocal([item('a', 5), item('b', 2)]);
      final payload = {
        'lojaId': 'loja',
        'itens': [
          {'produtoId': 'a', 'quantidade': 2},
        ],
      };
      await repo.consumirPedido('pedido', payload);
      var items = await repo.carregarCarrinhoLocal();
      expect(items.first.quantidade, 3);
      expect(items.last.quantidade, 2);
      items.first.quantidade++;
      await repo.salvarCarrinhoLocal(items);
      await repo.consumirPedido('pedido', payload);
      items = await repo.carregarCarrinhoLocal();
      expect(items.first.quantidade, 4);
      expect(items.last.quantidade, 2);
      expect(
        await CartRepository(usuarioId: 'u2').carregarCarrinhoLocal(),
        isEmpty,
      );
    },
  );
  test('itens de outra loja não são consumidos', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = CartRepository(usuarioId: 'u1');
    await repo.salvarCarrinhoLocal([
      CartItemModel(
        produtoId: 'a',
        nome: 'a',
        imagemUrl: '',
        preco: 10,
        lojaId: 'outra',
        quantidade: 2,
      ),
    ]);
    await repo.consumirPedido('pedido', {
      'lojaId': 'loja',
      'itens': [
        {'produtoId': 'a', 'quantidade': 2},
      ],
    });
    expect((await repo.carregarCarrinhoLocal()).single.quantidade, 2);
  });
}
