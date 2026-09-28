import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/utils/app_exceptions.dart';

class ErrorAdapter implements HttpClientAdapter {
  final String body;
  final int status;
  final String contentType;
  ErrorAdapter(this.body, this.status, this.contentType);
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(body, status, headers: {Headers.contentTypeHeader: [contentType]});
  @override void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080'));
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    ApiClient().atualizarTokenCache(null);
  });
  test('HTML de proxy resulta em erro tratado, sem exceção no interceptor', () async {
    final dio = ApiClient().dio;
    dio.httpClientAdapter = ErrorAdapter('<html>Bad Gateway</html>', 502, 'text/html');
    await expectLater(dio.get('/teste').timeout(const Duration(seconds: 2)),
        throwsA(isA<DioException>().having((e) => e.error, 'erro', isA<ServerException>())));
  });
  test('erro JSON mantém a mensagem da API', () async {
    final dio = ApiClient().dio;
    dio.httpClientAdapter = ErrorAdapter('{"message":"Cupom expirado"}', 400, 'application/json');
    await expectLater(dio.get('/teste'), throwsA(isA<DioException>().having(
        (e) => e.error.toString(), 'mensagem', 'Cupom expirado')));
  });
  test('details malformado não interrompe o tratamento', () async {
    final dio = ApiClient().dio;
    dio.httpClientAdapter = ErrorAdapter('{"message":"Inválido","details":"texto"}', 400, 'application/json');
    await expectLater(dio.get('/teste'), throwsA(isA<DioException>().having(
        (e) => e.error, 'erro', isA<BusinessRuleException>())));
  });
}
