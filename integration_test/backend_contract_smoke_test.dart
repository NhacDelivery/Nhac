import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nhac/globals/app_constants.dart';

import 'support/e2e_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const runE2E = bool.fromEnvironment('RUN_E2E', defaultValue: false);

  testWidgets('backend responde catálogo no contrato /api/v1/lojas', (_) async {
    await E2EConfig.validate();
    final dio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
    final response = await dio.get(
      '/lojas',
      queryParameters: {'page': 0, 'size': 1},
    );

    expect(response.statusCode, 200);
    expect(response.data, isA<Map>());
    expect((response.data as Map).containsKey('content'), isTrue);
    dio.close(force: true);
  }, skip: !runE2E);

  testWidgets(
    'login da fixture acessa histórico pelo contrato canônico GET /pedidos',
    (_) async {
      await E2EConfig.validate();
      final dio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));

      final login = await dio.post(
        '/auth/login',
        data: {'email': E2EConfig.email, 'senha': E2EConfig.password},
      );
      expect(login.statusCode, 200);
      final token = (login.data as Map)['token'];
      expect(token, isA<String>());
      expect(token, isNotEmpty);
      dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await dio.get(
        '/pedidos',
        queryParameters: {'page': 0, 'size': 1, 'sort': 'criadoEm,desc'},
      );

      expect(response.statusCode, 200);
      expect(response.data, isA<Map>());
      expect((response.data as Map)['content'], isEmpty);
      expect((response.data as Map)['totalElements'], 0);
      dio.close(force: true);
    },
    skip: !runE2E,
  );
}
