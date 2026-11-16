import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/models/feed/feed_post_model.dart';

/// Serviço de cache permanente de publicações do feed.
///
/// Utiliza estratégia de cache em 2 níveis (L1 Memória + L2 SharedPreferences/Disco):
/// - Acesso síncrono instantâneo (0ms) na memória para trocas de abas e navegação.
/// - Persistência permanente em disco para carregamento 100% funcional offline.
/// - Ordenação garantida pelos posts mais recentes primeiro (criadoEm descendente).
class FeedCacheService {
  static final Map<String, List<FeedPostModel>> _cacheMemoria = {};
  static const int _limiteMaximoPosts = 50;
  static const String _prefixoChave = 'cache_feed_posts_v1_';

  static String _chaveCategoria(String categoria) =>
      '$_prefixoChave${categoria.trim().toLowerCase()}';

  /// Ordena os posts de forma decrescente pela data de criação (mais recentes primeiro).
  static List<FeedPostModel> ordenarPorMaisRecentes(List<FeedPostModel> posts) {
    final copia = List<FeedPostModel>.from(posts);
    copia.sort((a, b) {
      final dataA = a.criadoEm ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dataB = b.criadoEm ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dataB.compareTo(dataA);
    });
    return copia;
  }

  /// Retorna os posts da categoria em memória de forma síncrona imediata (se existirem).
  static List<FeedPostModel>? obterMemoria(String categoria) {
    final chave = categoria.trim().toLowerCase();
    final posts = _cacheMemoria[chave];
    if (posts != null && posts.isNotEmpty) {
      return List.unmodifiable(posts);
    }
    return null;
  }

  /// Retorna os posts da categoria em cache (busca na memória primeiro; se não houver, busca no disco).
  static Future<List<FeedPostModel>?> carregarCache(String categoria) async {
    final emMemoria = obterMemoria(categoria);
    if (emMemoria != null) return emMemoria;

    final chaveFormatada = categoria.trim().toLowerCase();
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_chaveCategoria(categoria));
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final list = jsonDecode(jsonStr) as List<dynamic>;
      final posts = list
          .map((item) => FeedPostModel.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();

      final ordenados = ordenarPorMaisRecentes(posts);
      _cacheMemoria[chaveFormatada] = List.from(ordenados);
      return List.unmodifiable(ordenados);
    } catch (_) {
      return null;
    }
  }

  /// Salva as publicações no cache em memória e em disco para a categoria informada.
  static Future<void> salvar(
    String categoria,
    List<FeedPostModel> posts,
  ) async {
    if (categoria.isEmpty || posts.isEmpty) return;

    final chaveFormatada = categoria.trim().toLowerCase();

    // Garante deduplicação por id mantendo a versão mais atual
    final mapaDeduplicado = <String, FeedPostModel>{};
    for (final p in posts) {
      mapaDeduplicado[p.id] = p;
    }

    // Ordena do mais recente ao mais antigo
    final ordenados = ordenarPorMaisRecentes(mapaDeduplicado.values.toList());

    // Limita à quantidade máxima estipulada
    final paraSalvar = ordenados.length > _limiteMaximoPosts
        ? ordenados.sublist(0, _limiteMaximoPosts)
        : ordenados;

    // Salva na memória
    _cacheMemoria[chaveFormatada] = List.from(paraSalvar);

    // Salva em disco
    try {
      final jsonList = paraSalvar.map((p) => p.toMap()).toList();
      final jsonStr = jsonEncode(jsonList);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveCategoria(categoria), jsonStr);
    } catch (_) {
      // Falha silenciosa para não quebrar a navegação
    }
  }

  /// Atualiza uma publicação existente (ex: curtida ou salva) em todas as categorias em cache.
  static Future<void> atualizarPost(FeedPostModel postAtualizado) async {
    for (final entry in _cacheMemoria.entries) {
      final index = entry.value.indexWhere((p) => p.id == postAtualizado.id);
      if (index >= 0) {
        entry.value[index] = postAtualizado;
        _salvarDiscoSilencioso(entry.key, entry.value);
      }
    }
  }

  /// Remove uma publicação de todas as categorias em cache (ex: exclusão).
  static Future<void> removerPost(String postId) async {
    for (final entry in _cacheMemoria.entries) {
      final index = entry.value.indexWhere((p) => p.id == postId);
      if (index >= 0) {
        entry.value.removeAt(index);
        _salvarDiscoSilencioso(entry.key, entry.value);
      }
    }
  }

  static void _salvarDiscoSilencioso(String categoria, List<FeedPostModel> posts) {
    SharedPreferences.getInstance().then((prefs) {
      final jsonList = posts.map((p) => p.toMap()).toList();
      prefs.setString(_chaveCategoria(categoria), jsonEncode(jsonList));
    }).catchError((_) {});
  }

  /// Limpa todos os dados em cache em memória e disco (útil para testes ou logout).
  static Future<void> limparCache() async {
    _cacheMemoria.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final chaves = prefs.getKeys().where((k) => k.startsWith(_prefixoChave));
      for (final k in chaves) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
