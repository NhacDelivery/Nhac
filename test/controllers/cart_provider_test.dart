import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/controllers/cart_provider.dart';
import 'package:nhac/repositories/cart_repository.dart';

class MockCartRepository extends Mock implements CartRepository {}

void main() {
  group('CartProvider — Lógica de Negócio', () {
    late CartProvider cartProvider;
    late MockCartRepository mockRepo;

    setUp(() {
      mockRepo = MockCartRepository();
      when(() => mockRepo.salvarCarrinhoLocal(any())).thenAnswer((_) async {});
      when(() => mockRepo.limparCarrinho()).thenAnswer((_) async {});
      when(() => mockRepo.carregarCarrinhoLocal()).thenAnswer((_) async => []);
      cartProvider = CartProvider(repository: mockRepo);
    });

    test('Esvaziar carrinho reseta todas as variáveis e chama repositório', () async {
      await cartProvider.esvaziarCarrinho();
      expect(cartProvider.itens, isEmpty);
      expect(cartProvider.valorTotal, 0.0);
      expect(cartProvider.totalDeUnidades, 0);
      expect(cartProvider.observacao, '');
      expect(cartProvider.lojaId, '');
      verify(() => mockRepo.limparCarrinho()).called(1);
    });

    test('Adicionar item calcula total corretamente', () async {
      await cartProvider.adicionarItemComQuantidade(
        idProduto: 'p1',
        nome: 'Pizza',
        preco: 30.0,
        imagemUrl: '',
        lojaId: 'loja-A',
        quantidade: 2,
      );

      expect(cartProvider.valorTotal, 60.0);
      expect(cartProvider.totalDeUnidades, 2);
      expect(cartProvider.lojaId, 'loja-A');
    });

    test('Adicionar mesmo produto incrementa quantidade', () async {
      await cartProvider.adicionarItemComQuantidade(
        idProduto: 'p1', nome: 'Pizza', preco: 30.0,
        imagemUrl: '', lojaId: 'loja-A', quantidade: 1,
      );
      await cartProvider.adicionarItemComQuantidade(
        idProduto: 'p1', nome: 'Pizza', preco: 30.0,
        imagemUrl: '', lojaId: 'loja-A', quantidade: 1,
      );

      expect(cartProvider.itens.length, 1);
      expect(cartProvider.itens['p1']!.quantidade, 2);
      expect(cartProvider.totalDeUnidades, 2);
    });

    test('Adicionar produto de loja diferente lança Exception (guarda de loja)', () async {
      await cartProvider.adicionarItemComQuantidade(
        idProduto: 'p1', nome: 'Pizza', preco: 30.0,
        imagemUrl: '', lojaId: 'loja-A', quantidade: 1,
      );

      expect(
        () async => await cartProvider.adicionarItemComQuantidade(
          idProduto: 'p2', nome: 'Hamburguer', preco: 25.0,
          imagemUrl: '', lojaId: 'loja-B',  
          quantidade: 1,
        ),
        throwsA(isA<Exception>()),
      );

      expect(cartProvider.itens.length, 1);     
      expect(cartProvider.lojaId, 'loja-A');    
    });

    test('Adicionar produto da MESMA loja retorna true', () async {
      await cartProvider.adicionarItemComQuantidade(
        idProduto: 'p1', nome: 'Pizza', preco: 30.0,
        imagemUrl: '', lojaId: 'loja-A', quantidade: 1,
      );

      final resultado = await cartProvider.adicionarItemComQuantidade(
        idProduto: 'p2', nome: 'Refrigerante', preco: 8.0,
        imagemUrl: '', lojaId: 'loja-A', quantidade: 1,
      );

      expect(resultado, true);
      expect(cartProvider.itens.length, 2);
    });

    test('Remover único item de um produto decrementa quantidade', () async {
      await cartProvider.adicionarItemComQuantidade(
        idProduto: 'p1', nome: 'Pizza', preco: 30.0,
        imagemUrl: '', lojaId: 'loja-A', quantidade: 3,
      );

      await cartProvider.removerItem('p1');

      expect(cartProvider.itens['p1']!.quantidade, 2);
    });

    test('Remover único item com quantidade 1 remove do mapa e limpa lojaId', () async {
      await cartProvider.adicionarItemComQuantidade(
        idProduto: 'p1', nome: 'Pizza', preco: 30.0,
        imagemUrl: '', lojaId: 'loja-A', quantidade: 1,
      );

      await cartProvider.removerItem('p1');

      expect(cartProvider.itens, isEmpty);
      expect(cartProvider.lojaId, '');
    });

    test('setObservacao atualiza observacao', () {
      cartProvider.setObservacao('Sem cebola');
      expect(cartProvider.observacao, 'Sem cebola');
    });

    test('setObservacao com mesmo valor não chama notifyListeners extra', () {
      cartProvider.setObservacao('Sem cebola');
      int notificacoes = 0;
      cartProvider.addListener(() => notificacoes++);
      cartProvider.setObservacao('Sem cebola'); 
      expect(notificacoes, 0);
    });
  });
}
