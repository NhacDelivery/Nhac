import 'package:dio/dio.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/models/feed/feed_comment_model.dart';
import 'package:nhac/services/api_client.dart';

class FeedRepository {
  final Dio _dio;
  FeedRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<FeedPostModel> criarPost({
    required String conteudo,
    List<String> imagens = const [],
    List<String> hashTags = const [],
    String? lojaId,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _dio.post(
        '/feed/posts',
        options: idempotencyKey == null
            ? null
            : Options(headers: {'Idempotency-Key': idempotencyKey}),
        data: {
          'conteudo': conteudo.trim(),
          'imagens': imagens,
          'hashTags': hashTags,
          'lojaId': lojaId,
          'isPatrocinado': false,
        },
      );
      return FeedPostModel.fromMap(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<List<FeedPostModel>> buscarPosts({
    String categoria = 'Destaques',
    int page = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/feed/posts',
        queryParameters: {'categoria': categoria, 'page': page, 'size': 20},
      );
      return (response.data['content'] as List)
          .map((item) => FeedPostModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<FeedPostModel> buscarPost(String id) async {
    try {
      final response = await _dio.get('/feed/posts/${Uri.encodeComponent(id)}');
      return FeedPostModel.fromMap(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<List<FeedCommentModel>> buscarComentarios(
    String id, {
    int page = 0,
    String ordem = 'Padrao',
    bool autor = false,
  }) async {
    try {
      final response = await _dio.get(
        '/feed/posts/${Uri.encodeComponent(id)}/comentarios',
        queryParameters: {
          'page': page,
          'size': 20,
          'ordem': ordem,
          'autor': autor,
        },
      );
      return (response.data['content'] as List)
          .map(
            (item) => FeedCommentModel.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<FeedCommentModel> comentar(
    String id,
    String conteudo, {
    String? respostaAId,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _dio.post(
        '/feed/posts/${Uri.encodeComponent(id)}/comentarios',
        data: {
          'conteudo': conteudo.trim(),
          if (respostaAId != null) 'respostaAId': respostaAId,
        },
        options: idempotencyKey == null
            ? null
            : Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return FeedCommentModel.fromMap(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<FeedCommentModel> curtirComentario(
    String postId,
    String comentarioId, {
    required bool ativo,
  }) async {
    try {
      final path =
          '/feed/posts/${Uri.encodeComponent(postId)}/comentarios/${Uri.encodeComponent(comentarioId)}/curtida';
      final response = ativo ? await _dio.put(path) : await _dio.delete(path);
      return FeedCommentModel.fromMap(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<FeedPostModel> interagir(
    String id, {
    required bool ativo,
    bool salvar = false,
  }) async {
    try {
      final path =
          '/feed/posts/${Uri.encodeComponent(id)}/${salvar ? 'salvo' : 'curtida'}';
      final response = ativo ? await _dio.put(path) : await _dio.delete(path);
      return FeedPostModel.fromMap(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<List<FeedPostModel>> buscarSalvos({int page = 0}) async {
    try {
      final response = await _dio.get(
        '/feed/posts/salvos',
        queryParameters: {'page': page, 'size': 20},
      );
      return (response.data['content'] as List)
          .map((item) => FeedPostModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<FeedPostModel> editar(
    FeedPostModel post,
    String conteudo,
    List<String> tags, {
    List<String>? imagens,
    String? lojaId,
    bool alterarLoja = false,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _dio.put(
        '/feed/posts/${Uri.encodeComponent(post.id)}',
        options: Options(
          headers: {
            if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
          },
        ),
        data: {
          'conteudo': conteudo.trim(),
          'hashTags': tags,
          'imagens': imagens ?? post.imagens,
          'lojaId': alterarLoja ? lojaId : post.mentionedStore?.id,
          'isPatrocinado': post.isPatrocinado,
          'sponsorLabel': post.sponsorLabel,
        },
      );
      return FeedPostModel.fromMap(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> denunciar(
    String postId,
    String motivo, {
    String? comentarioId,
  }) async {
    try {
      await _dio.post(
        '/feed/posts/${Uri.encodeComponent(postId)}/denuncias',
        data: {
          'motivo': motivo,
          if (comentarioId != null) 'comentarioId': comentarioId,
        },
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> excluir(String id) async {
    try {
      await _dio.delete('/feed/posts/${Uri.encodeComponent(id)}');
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> excluirComentario(String postId, String id) async {
    try {
      await _dio.delete(
        '/feed/posts/${Uri.encodeComponent(postId)}/comentarios/${Uri.encodeComponent(id)}',
      );
    } catch (e) {
      throw mapException(e);
    }
  }
}
