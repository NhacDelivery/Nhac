import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nhac/services/feed_tentativa_service.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080/api/v1');
  });
  test(
    'reabrir mantém chave e payload da tentativa e isola as contas',
    () async {
      const first = FeedTentativaService();
      final pending = await first.preparar('u1', 'post', {
        'conteudo': 'Pedido',
      });
      const reopened = FeedTentativaService();
      final recovered = await reopened.preparar('u1', 'post', {
        'conteudo': 'Pedido',
      });
      expect(recovered['key'], pending['key']);
      expect(await reopened.carregar('u2', 'post'), isNull);
      await expectLater(
        reopened.preparar('u1', 'post', {'conteudo': 'Alterado'}),
        throwsStateError,
      );
      await reopened.concluir('u1', 'post');
      final next = await reopened.preparar('u1', 'post', {'conteudo': 'Novo'});
      expect(next['key'], isNot(pending['key']));
    },
  );
  test(
    'comentários de posts diferentes possuem tentativas independentes',
    () async {
      const service = FeedTentativaService();
      final a = await service.preparar('u1', 'comentario:a', {
        'conteudo': 'Igual',
      });
      final b = await service.preparar('u1', 'comentario:b', {
        'conteudo': 'Igual',
      });
      expect(a['key'], isNot(b['key']));
    },
  );
  test(
    'avaliação incerta restaura nota, comentário e URLs sem mudar o envio',
    () async {
      const service = FeedTentativaService();
      final payload = {
        'nota': 4,
        'comentario': 'Chegou quente',
        'imagens': ['https://example.com/foto.jpg'],
      };
      await service.preparar('u1', 'avaliacao:pedido:produto', payload);
      expect(
        (await const FeedTentativaService().carregar(
          'u1',
          'avaliacao:pedido:produto',
        ))!['payload'],
        payload,
      );
      expect(await service.carregar('u2', 'avaliacao:pedido:produto'), isNull);
      expect(await service.carregar('u1', 'avaliacao:outro:produto'), isNull);
    },
  );
}
