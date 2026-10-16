import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/models/home/home_product_selection.dart';
import 'package:nhac/models/produto/produtos.dart';

ProdutosModel produto(String id, {bool aberta = true, double preco = 30}) =>
    ProdutosModel(id: id, nome: 'Produto $id', preco: preco,
      categoriaMenu: 'Combos', lojaId: 'loja-$id', lojaAberta: aberta);

void main() {
  test('um único produto caro preenche ambas as seções sem falsa promoção', () {
    final selecao = HomeProductSelection.from([produto('1')], []);
    expect(selecao.principais.single.id, '1');
    expect(selecao.secundarios.single.preco, 30);
    expect(selecao.tituloSecundario, 'Explore o cardápio');
  });
  test('lojas fechadas não apagam catálogo e abertas têm prioridade', () {
    final selecao = HomeProductSelection.from([produto('fechada', aberta: false), produto('aberta')], []);
    expect(selecao.principais.map((p) => p.id), ['aberta', 'fechada']);
    final fechadas = HomeProductSelection.from([produto('f', aberta: false)], []);
    expect(fechadas.principais.single.lojaAberta, isFalse);
    expect(fechadas.secundarios, isNotEmpty);
  });
  test('abaixo de 20 independe de desconto e nunca inclui preço igual ou maior', () {
    final selecao = HomeProductSelection.from([produto('caro'), produto('limite', preco: 20), produto('barato', preco: 19.99)], []);
    expect(selecao.secundarios.single.id, 'barato');
    expect(selecao.tituloSecundario, 'Tudo abaixo de R\$ 20');
  });
  test('fonte de promoções preenche seção geral e não duplica IDs', () {
    final selecao = HomeProductSelection.from([], [produto('1'), produto('1')]);
    expect(selecao.principais.length, 1); expect(selecao.secundarios.length, 1);
  });
  test('limite da primeira seção não perde barato fora dos dez primeiros', () {
    final catalogo = [for (var i = 0; i < 20; i++) produto('$i'), produto('economico', preco: 5)];
    final selecao = HomeProductSelection.from(catalogo, []);
    expect(selecao.principais.length, 10);
    expect(selecao.secundarios.single.id, 'economico'); expect(catalogo.length, 21);
  });
  test('catálogo realmente vazio conserva vazio', () {
    final selecao = HomeProductSelection.from([], []);
    expect(selecao.principais, isEmpty); expect(selecao.secundarios, isEmpty);
  });
}
