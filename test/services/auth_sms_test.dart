import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SmsAdapter implements HttpClientAdapter {
  _SmsAdapter({this.statusEnvio = 200});

  final int statusEnvio;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final login = options.path == '/auth/login-sms';
    final body = login
        ? {
            'token': 'jwt-sms',
            'usuarioId': 'cliente-sms',
            'nome': 'Cliente',
            'isNovoUsuario': false,
          }
        : {'error': 'SERVICO_INDISPONIVEL'};
    return ResponseBody.fromString(
      jsonEncode(body),
      login ? 200 : statusEnvio,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () =>
        dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080/api/v1'),
  );
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    ApiClient().atualizarTokenCache(null);
  });

  test(
    'envio e login usam o mesmo telefone nacional ou internacional',
    () async {
      final adapter = _SmsAdapter();
      ApiClient().dio.httpClientAdapter = adapter;
      final auth = AuthService();
      addTearDown(auth.dispose);

      await auth.enviarCodigoSms('(55) 99999-8888');
      expect(await auth.loginSms('+55 (55) 99999-8888', ' 012345 '), isFalse);

      expect(
        adapter.requests.first.path,
        '/verificacao-telefone/enviar-codigo',
      );
      expect(adapter.requests.first.data, {'telefone': '+5555999998888'});
      expect(adapter.requests.last.data, {
        'telefone': '+5555999998888',
        'codigo': '012345',
      });
      expect(auth.usuarioId, 'cliente-sms');
      expect(auth.isPhoneUser, isTrue);
    },
  );

  test('indisponibilidade no envio informa que o problema é no SMS', () async {
    ApiClient().dio.httpClientAdapter = _SmsAdapter(statusEnvio: 503);
    final auth = AuthService();
    addTearDown(auth.dispose);
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      auth.enviarCodigoSms('11999998888'),
      throwsA(
        isA<AuthException>().having(
          (erro) => erro.message,
          'mensagem',
          contains('envio de SMS está indisponível'),
        ),
      ),
    );
  });
}
