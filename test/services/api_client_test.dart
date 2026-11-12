import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/utils/app_exceptions.dart';
import 'package:nhac/globals/exceptions.dart' as globals;

class ErrorAdapter implements HttpClientAdapter {
  final String body;
  final int status;
  final String contentType;
  ErrorAdapter(this.body, this.status, this.contentType);
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(body, status, headers: {
        Headers.contentTypeHeader: [contentType]
      });
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
      () => dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080'));
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    ApiClient().atualizarTokenCache(null);
  });
  test(
      'catálogo público evita autenticação; pedidos e loja privada mantêm token',
      () async {
    final client = ApiClient();
    client.atualizarTokenCache('token-de-teste');
    client.dio.httpClientAdapter = ErrorAdapter('{}', 200, 'application/json');
    final catalogo = await client.dio.get('/produtos/cards');
    final pedidos = await client.dio.get('/pedidos/ativos');
    final minhaLoja = await client.dio.get('/lojas/minha-loja');
    expect(catalogo.requestOptions.headers['Authorization'], isNull);
    expect(pedidos.requestOptions.headers['Authorization'],
        'Bearer token-de-teste');
    expect(minhaLoja.requestOptions.headers['Authorization'],
        'Bearer token-de-teste');
  });

  test('HTML de proxy resulta em erro tratado, sem exceção no interceptor',
      () async {
    final dio = ApiClient().dio;
    dio.httpClientAdapter =
        ErrorAdapter('<html>Bad Gateway</html>', 502, 'text/html');
    await expectLater(
        dio.get('/teste').timeout(const Duration(seconds: 2)),
        throwsA(isA<DioException>()
            .having((e) => e.error, 'erro', isA<ServerException>())));
  });
  test('erro JSON mantém a mensagem da API', () async {
    final dio = ApiClient().dio;
    dio.httpClientAdapter =
        ErrorAdapter('{"message":"Cupom expirado"}', 400, 'application/json');
    await expectLater(
        dio.get('/teste'),
        throwsA(isA<DioException>()
            .having((e) => e.error.toString(), 'mensagem', 'Cupom expirado')));
  });
  test('details malformado não interrompe o tratamento', () async {
    final dio = ApiClient().dio;
    dio.httpClientAdapter = ErrorAdapter(
        '{"message":"Inválido","details":"texto"}', 400, 'application/json');
    await expectLater(
        dio.get('/teste'),
        throwsA(isA<DioException>()
            .having((e) => e.error, 'erro', isA<BusinessRuleException>())));
  });
  test('indisponibilidade PIX preserva código e mensagem até a tela', () async {
    final dio = ApiClient().dio;
    dio.httpClientAdapter = ErrorAdapter(
      '{"message":"PIX temporariamente indisponível","errorCode":"PAGAMENTO_INDISPONIVEL"}',
      409, 'application/json');
    try {
      await dio.get('/pedidos/pix/pagamento');
      fail('Esperava indisponibilidade');
    } catch (e) {
      final mapped = globals.mapException(e) as globals.AppException;
      expect(mapped, isA<globals.AppException>());
      expect(mapped.code, 'PAGAMENTO_INDISPONIVEL');
      expect(mapped.message, 'PIX temporariamente indisponível');
    }
  });

  test('validação do cadastro mostra a confirmação e a senha rejeitadas', () async {
    final dio = ApiClient().dio;
    dio.httpClientAdapter = ErrorAdapter(
      '{"message":"Alguns campos enviados são inválidos. Verifique os detalhes.",'
      '"error":"VALIDACAO_FALHOU","details":{'
      '"tokenCadastro":"Confirme seu e-mail antes de concluir o cadastro.",'
      '"senha":"A senha deve conter pelo menos uma letra e um número."}}',
      400, 'application/json');
    try {
      await dio.post('/auth/registrar', data: {});
      fail('Esperava erro de validação');
    } catch (e) {
      final mapped = globals.mapException(e) as globals.AppException;
      expect(mapped.statusCode, 400);
      expect(mapped.message, contains('Confirmação de e-mail: Confirme seu e-mail'));
      expect(mapped.message, contains('Senha: A senha deve conter'));
    }
  });

  test('validação sem interceptor também preserva o detalhe do campo', () {
    final options = RequestOptions(path: '/auth/registrar');
    final mapped = globals.mapException(DioException(
      requestOptions: options,
      response: Response(requestOptions: options, statusCode: 400, data: {
        'message': 'Campos inválidos',
        'details': {'telefone': 'não deve estar em branco'},
      }),
    ));
    expect(mapped.toString(), 'Telefone: não deve estar em branco');
  });

  test('detalhes vazios ou malformados mantêm a mensagem genérica', () {
    for (final details in [{}, {'senha': null}, {'senha': []}, {'senha': ' '}]) {
      final mapped = globals.mapException(
          ValidationException('Campos inválidos', details));
      expect(mapped.toString(), 'Campos inválidos');
    }
  });

}
