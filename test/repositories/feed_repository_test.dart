import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/repositories/feed_repository.dart';

class MockFeedDio extends Mock implements Dio {}

Map<String, dynamic> postData() => {
  'id': 'post-real', 'nomeUsuario': 'Autor real', 'conteudo': 'Meu pedido',
  'imagens': <String>[], 'hashTags': ['#Nhac'], 'curtidas': 2, 'comentarios': 1,
  'salvos': 1, 'curtido': true, 'salvo': false, 'isPatrocinado': false,
  'mentionedStore': {'id': 'loja-real', 'nome': 'Loja real', 'imageUrl': null,
    'rating': 4.5, 'avaliacoes': '3 avaliações'},
};

void main() {
  test('lista paginada usa API e preserva o contrato real', () async {
    final dio = MockFeedDio();
    when(() => dio.get('/feed/posts', queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/feed/posts'),
          data: {'content': [postData()]}));
    final posts = await FeedRepository(dio: dio).buscarPosts(categoria: 'Em Alta', page: 2);
    expect(posts.single.id, 'post-real');
    expect(posts.single.curtido, isTrue);
    expect(posts.single.mentionedStore!.id, 'loja-real');
    expect(posts.single.mentionedStore!.rating, 4.5);
    expect(posts.single.topComment, isNull);
    verify(() => dio.get('/feed/posts', queryParameters: {
      'categoria': 'Em Alta', 'page': 2, 'size': 20,
    })).called(1);
  });

  test('feed vazio não insere exemplos', () async {
    final dio = MockFeedDio();
    when(() => dio.get('/feed/posts', queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/feed/posts'),
          data: {'content': []}));
    expect(await FeedRepository(dio: dio).buscarPosts(), isEmpty);
  });

  test('falha HTTP é propagada sem retornar dados mockados', () async {
    final dio = MockFeedDio();
    when(() => dio.get('/feed/posts', queryParameters: any(named: 'queryParameters')))
        .thenThrow(DioException(requestOptions: RequestOptions(path: '/feed/posts'),
          type: DioExceptionType.connectionError));
    await expectLater(FeedRepository(dio: dio).buscarPosts(), throwsA(isA<Exception>()));
  });

  test('envio de comentário retorna o autor e conteúdo do servidor', () async {
    final dio = MockFeedDio();
    when(() => dio.post('/feed/posts/post-real/comentarios', data: any(named: 'data')))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/feed/posts/post-real/comentarios'),
          data: {'id': 'comentario-real', 'nomeUsuario': 'Autor', 'conteudo': 'Gostei',
            'isAuthor': true, 'criadoEm': '2026-10-04T17:00:00Z'}));
    final comment = await FeedRepository(dio: dio).comentar('post-real', ' Gostei ');
    expect(comment.id, 'comentario-real');
    expect(comment.isAuthor, isTrue);
    verify(() => dio.post('/feed/posts/post-real/comentarios', data: {'conteudo': 'Gostei'})).called(1);
  });

  test('descurtir e salvar usam DELETE e PUT', () async {
    final dio = MockFeedDio();
    when(() => dio.delete('/feed/posts/post-real/curtida'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/feed/posts/post-real/curtida'), data: postData()));
    when(() => dio.put('/feed/posts/post-real/salvo'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/feed/posts/post-real/salvo'), data: postData()));
    final repository = FeedRepository(dio: dio);
    await repository.interagir('post-real', ativo: false);
    await repository.interagir('post-real', ativo: true, salvar: true);
    verify(() => dio.delete('/feed/posts/post-real/curtida')).called(1);
    verify(() => dio.put('/feed/posts/post-real/salvo')).called(1);
  });
}
