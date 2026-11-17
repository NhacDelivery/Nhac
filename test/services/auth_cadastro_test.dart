import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/session_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CadastroAdapter implements HttpClientAdapter {
  final Object confirmacao;
  final requests = <RequestOptions>[];

  CadastroAdapter(this.confirmacao);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final confirmando = options.path == '/auth/confirmar-email-cadastro';
    return ResponseBody.fromString(
      jsonEncode(confirmando ? confirmacao : {
        'token': 'jwt-do-servidor',
        'usuarioId': 'id-do-servidor',
        'nome': 'Cliente',
      }),
      confirmando ? 200 : 201,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => dotenv.testLoad(
      fileInput: 'API_BASE_URL=http://localhost:8080/api/v1'));
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    ApiClient().atualizarTokenCache(null);
  });

  test('confirmação fornece prova enviada ao registrar e adota sessão do servidor',
      () async {
    final adapter = CadastroAdapter({'tokenCadastro': 'prova-do-email'});
    ApiClient().dio.httpClientAdapter = adapter;
    final auth = AuthService();
    addTearDown(auth.dispose);
    final token = await auth.confirmarEmailCadastro(' cliente@exemplo.com ', '123456');
    expect(token, 'prova-do-email');

    await auth.registrar(
      nome: 'Cliente',
      email: 'cliente@exemplo.com',
      telefone: '11999999999',
      senha: 'senha123',
      tokenCadastro: token,
    );

    expect(adapter.requests.first.data,
        {'email': 'cliente@exemplo.com', 'codigo': '123456'});
    expect(adapter.requests.last.path, '/auth/registrar');
    expect(adapter.requests.last.data, {
      'nome': 'Cliente',
      'email': 'cliente@exemplo.com',
      'telefone': '11999999999',
      'senha': 'senha123',
      'tokenCadastro': 'prova-do-email',
    });
    expect(auth.usuarioId, 'id-do-servidor');
    expect(auth.isAuthenticated, isTrue);
    expect(await SessionStorageService().obterToken(), 'jwt-do-servidor');
  });

  for (final resposta in [{}, {'tokenCadastro': ''}, {'tokenCadastro': 123}, 'inválido']) {
    test('não prossegue com confirmação sem prova válida: $resposta', () async {
      ApiClient().dio.httpClientAdapter = CadastroAdapter(resposta);
      final auth = AuthService();
      await Future<void>.delayed(Duration.zero);
      addTearDown(auth.dispose);
      await expectLater(auth.confirmarEmailCadastro('cliente@exemplo.com', '123456'),
          throwsA(isA<AuthException>()));
      expect(auth.isAuthenticated, isFalse);
    });
  }

  test('prova vazia impede requisição de registro', () async {
    final adapter = CadastroAdapter({});
    ApiClient().dio.httpClientAdapter = adapter;
    final auth = AuthService();
    await Future<void>.delayed(Duration.zero);
    addTearDown(auth.dispose);
    await expectLater(
      auth.registrar(nome: 'Cliente', email: 'cliente@exemplo.com',
          telefone: '11999999999', senha: 'senha123', tokenCadastro: ' '),
      throwsA(isA<AuthException>()),
    );
    expect(adapter.requests, isEmpty);
  });
}
