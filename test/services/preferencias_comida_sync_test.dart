import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/services/local_cache_service.dart';
import 'package:nhac/services/preferencias_comida_service.dart';

class PreferenciasAdapter implements HttpClientAdapter {
  bool falha = false;
  List<String>? servidor;
  int envios = 0;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancel) async {
    if (falha)
      throw DioException.connectionError(
          requestOptions: options, reason: 'offline');
    if (options.method == 'PUT') {
      envios++;
      servidor = List<String>.from(options.data['preferencias']);
    }
    return ResponseBody.fromString(jsonEncode({'preferencias': servidor}), 200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreferenciasAdapter adapter;
  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080/api/v1');
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    adapter = PreferenciasAdapter();
    ApiClient().dio.httpClientAdapter = adapter;
  });
  test(
      'reabre com a escolha local pendente e sincroniza exatamente essa escolha',
      () async {
    adapter.falha = true;
    await expectLater(PreferenciasComidaService.salvar('cliente', {'Pizza'}),
        throwsA(isA<DioException>()));
    expect(await LocalCacheService.carregarPreferenciasComida('cliente'),
        {'Pizza'});
    adapter.falha = false;
    adapter.servidor = ['Sushi'];
    expect(await PreferenciasComidaService.carregar('cliente'), {'Pizza'});
    expect(adapter.servidor, ['Pizza']);
    expect(adapter.envios, 1);
  });
  test('escolha vazia confirmada em outro aparelho substitui a antiga',
      () async {
    await LocalCacheService.salvarPreferenciasComida('cliente', {'Pizza'});
    adapter.servidor = [];
    expect(await PreferenciasComidaService.carregar('cliente'), isEmpty);
    expect(
        await LocalCacheService.carregarPreferenciasComida('cliente'), isEmpty);
    expect(adapter.envios, 0);
  });
}
