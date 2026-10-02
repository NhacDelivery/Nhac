import 'package:nhac/models/feed/feed_post_model.dart';

class FeedRepository {
  // Nenhum endpoint de publicações está disponível. Não exibe ofertas fictícias.
  Future<List<FeedPostModel>> buscarPosts({
    String categoria = 'Destaques',
  }) async => [];
}
