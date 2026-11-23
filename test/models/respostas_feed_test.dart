import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/models/feed/feed_comment_model.dart';

void main() {
  FeedCommentModel c(String id, [String? pai]) => FeedCommentModel(
    id: id, respostaAId: pai, nome: 'Autor', conteudo: id,
    isAuthor: false, criadoEm: DateTime.utc(2026),
  );

  test('respostas seguem seus pais mesmo quando a API mistura datas e páginas', () {
    final itens = [c('neta', 'filha'), c('B'), c('filha', 'A'), c('A'), c('b1', 'B')];
    final grupo = organizarComentarios(itens);
    expect(grupo.map((r) => (r.comentario.id, r.nivel)),
        [('B', 0), ('b1', 1), ('A', 0), ('filha', 1), ('neta', 2)]);
    expect(organizarComentarios([c('B'), c('filha', 'A')]).last.nivel, 0);
  });
}
