import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/services/feed_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await FeedCacheService.limparCache();
  });

  group('FeedPostModel Serialization', () {
    test('toMap e fromMap convertem perfeitamente com todas as propriedades', () {
      final post = FeedPostModel(
        id: 'p-123',
        criadoEm: DateTime.parse('2026-11-16T08:00:00.000Z'),
        nomeUsuario: 'Maria Silva',
        usuarioId: 'u-1',
        badge: 'VIP',
        dispositivo: 'iOS',
        avatarUrl: 'https://exemplo.com/avatar.jpg',
        conteudo: 'Adorando o hambúrguer!',
        imagens: const ['https://exemplo.com/foto1.jpg'],
        hashTags: const ['#nhac', '#burguer'],
        curtidas: 10,
        comentarios: 2,
        salvos: 3,
        curtido: true,
        salvo: true,
        podeEditar: false,
        isPatrocinado: true,
        sponsorLabel: 'Patrocinado',
        topComment: const TopCommentModel(
          nomeUsuario: 'João',
          conteudo: 'Top!',
          curtidas: 5,
        ),
        mentionedStore: const MentionedStoreModel(
          id: 'loja-1',
          nome: 'Burguer King',
          imageUrl: 'https://exemplo.com/loja.jpg',
          rating: 4.8,
          avaliacoes: '120 avaliações',
        ),
      );

      final map = post.toMap();
      final restaurado = FeedPostModel.fromMap(map);

      expect(restaurado.id, 'p-123');
      expect(restaurado.criadoEm, DateTime.parse('2026-11-16T08:00:00.000Z'));
      expect(restaurado.nomeUsuario, 'Maria Silva');
      expect(restaurado.usuarioId, 'u-1');
      expect(restaurado.badge, 'VIP');
      expect(restaurado.dispositivo, 'iOS');
      expect(restaurado.conteudo, 'Adorando o hambúrguer!');
      expect(restaurado.imagens, ['https://exemplo.com/foto1.jpg']);
      expect(restaurado.hashTags, ['#nhac', '#burguer']);
      expect(restaurado.curtidas, 10);
      expect(restaurado.comentarios, 2);
      expect(restaurado.salvos, 3);
      expect(restaurado.curtido, isTrue);
      expect(restaurado.salvo, isTrue);
      expect(restaurado.isPatrocinado, isTrue);
      expect(restaurado.sponsorLabel, 'Patrocinado');
      expect(restaurado.topComment?.nomeUsuario, 'João');
      expect(restaurado.topComment?.conteudo, 'Top!');
      expect(restaurado.topComment?.curtidas, 5);
      expect(restaurado.mentionedStore?.nome, 'Burguer King');
      expect(restaurado.mentionedStore?.rating, 4.8);
    });
  });

  group('FeedCacheService', () {
    test('ordena posts decrescentemente pela data mais recente', () {
      final postAntigo = FeedPostModel(
        id: '1',
        nomeUsuario: 'User 1',
        conteudo: 'Antigo',
        curtidas: 0,
        comentarios: 0,
        criadoEm: DateTime.parse('2026-11-10T10:00:00Z'),
      );
      final postMedio = FeedPostModel(
        id: '2',
        nomeUsuario: 'User 2',
        conteudo: 'Médio',
        curtidas: 0,
        comentarios: 0,
        criadoEm: DateTime.parse('2026-11-14T10:00:00Z'),
      );
      final postRecente = FeedPostModel(
        id: '3',
        nomeUsuario: 'User 3',
        conteudo: 'Mais recente',
        curtidas: 0,
        comentarios: 0,
        criadoEm: DateTime.parse('2026-11-16T08:00:00Z'),
      );
      final postSemData = FeedPostModel(
        id: '4',
        nomeUsuario: 'User 4',
        conteudo: 'Sem data',
        curtidas: 0,
        comentarios: 0,
        criadoEm: null,
      );

      final ordenados = FeedCacheService.ordenarPorMaisRecentes([
        postAntigo,
        postSemData,
        postRecente,
        postMedio,
      ]);

      expect(ordenados.map((p) => p.id).toList(), ['3', '2', '1', '4']);
    });

    test('salva em memória e recupera em disco quando a memória é limpa', () async {
      final posts = [
        FeedPostModel(
          id: 'p1',
          nomeUsuario: 'User 1',
          conteudo: 'Conteúdo 1',
          curtidas: 5,
          comentarios: 1,
          criadoEm: DateTime.parse('2026-11-16T08:00:00Z'),
        ),
      ];

      await FeedCacheService.salvar('Destaques', posts);

      // Em memória (L1) deve estar disponível de forma síncrona imediata
      final emMemoria = FeedCacheService.obterMemoria('Destaques');
      expect(emMemoria, isNotNull);
      expect(emMemoria!.length, 1);
      expect(emMemoria.first.id, 'p1');

      // Limpa apenas a memória para testar recuperação de disco (L2)
      await FeedCacheService.salvar('Destaques', posts);
      final emDisco = await FeedCacheService.carregarCache('Destaques');
      expect(emDisco, isNotNull);
      expect(emDisco!.first.conteudo, 'Conteúdo 1');
    });

    test('atualizarPost atualiza as informações no cache', () async {
      final post = FeedPostModel(
        id: 'p1',
        nomeUsuario: 'User 1',
        conteudo: 'Original',
        curtidas: 0,
        comentarios: 0,
        criadoEm: DateTime.parse('2026-11-16T08:00:00Z'),
      );

      await FeedCacheService.salvar('Destaques', [post]);

      final postCurtido = post.copyWith(curtidas: 1, curtido: true);
      await FeedCacheService.atualizarPost(postCurtido);

      final emMemoria = FeedCacheService.obterMemoria('Destaques');
      expect(emMemoria!.first.curtido, isTrue);
      expect(emMemoria.first.curtidas, 1);
    });

    test('removerPost remove o item do cache', () async {
      final post1 = FeedPostModel(
        id: 'p1',
        nomeUsuario: 'User 1',
        conteudo: 'Post 1',
        curtidas: 0,
        comentarios: 0,
      );
      final post2 = FeedPostModel(
        id: 'p2',
        nomeUsuario: 'User 2',
        conteudo: 'Post 2',
        curtidas: 0,
        comentarios: 0,
      );

      await FeedCacheService.salvar('Destaques', [post1, post2]);
      await FeedCacheService.removerPost('p1');

      final emMemoria = FeedCacheService.obterMemoria('Destaques');
      expect(emMemoria!.length, 1);
      expect(emMemoria.first.id, 'p2');
    });
  });
}
