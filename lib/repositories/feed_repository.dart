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
  }) async {
    try {
      final response = await _dio.post('/feed/posts', data: {
        'conteudo': conteudo.trim(), 'imagens': imagens,
        'hashTags': hashTags, 'lojaId': lojaId, 'isPatrocinado': false,
      });
      return FeedPostModel.fromMap(Map<String, dynamic>.from(response.data));
    } catch (e) { throw mapException(e); }
  }

  Future<List<FeedPostModel>> buscarPosts({String categoria = 'Destaques', int page = 0}) async {
    try {
      final response = await _dio.get('/feed/posts', queryParameters: {
        'categoria': categoria, 'page': page, 'size': 20,
      });
      return (response.data['content'] as List)
          .map((item) => FeedPostModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) { throw mapException(e); }
  }

  Future<FeedPostModel> buscarPost(String id) async {
    try {
      final response = await _dio.get('/feed/posts/${Uri.encodeComponent(id)}');
      return FeedPostModel.fromMap(Map<String, dynamic>.from(response.data));
    } catch (e) { throw mapException(e); }
  }

  Future<List<FeedCommentModel>> buscarComentarios(String id, {int page = 0}) async {
    try {
      final response = await _dio.get('/feed/posts/${Uri.encodeComponent(id)}/comentarios',
          queryParameters: {'page': page, 'size': 20});
      return (response.data['content'] as List)
          .map((item) => FeedCommentModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) { throw mapException(e); }
  }

  Future<FeedCommentModel> comentar(String id, String conteudo) async {
    try {
      final response = await _dio.post('/feed/posts/${Uri.encodeComponent(id)}/comentarios',
          data: {'conteudo': conteudo.trim()});
      return FeedCommentModel.fromMap(Map<String, dynamic>.from(response.data));
    } catch (e) { throw mapException(e); }
  }

  Future<FeedPostModel> interagir(String id, {required bool ativo, bool salvar = false}) async {
    try {
      final path = '/feed/posts/${Uri.encodeComponent(id)}/${salvar ? 'salvo' : 'curtida'}';
      final response = ativo ? await _dio.put(path) : await _dio.delete(path);
      return FeedPostModel.fromMap(Map<String, dynamic>.from(response.data));
    } catch (e) { throw mapException(e); }
  }
}
