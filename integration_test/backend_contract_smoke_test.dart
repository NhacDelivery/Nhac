import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nhac/globals/app_constants.dart';

import 'support/e2e_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const runE2E = bool.fromEnvironment('RUN_E2E', defaultValue: false);
  const e2eToken = String.fromEnvironment('E2E_TOKEN', defaultValue: '');

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
  }, skip: !runE2E);

  testWidgets(
    'token E2E acessa histórico pelo contrato canônico GET /pedidos',
    (_) async {
      await E2EConfig.validate();
      final dio = Dio(
        BaseOptions(
          baseUrl: AppConstants.apiBaseUrl,
          headers: {'Authorization': 'Bearer $e2eToken'},
        ),
      );

      final response = await dio.get(
        '/pedidos',
        queryParameters: {'page': 0, 'size': 1, 'sort': 'criadoEm,desc'},
      );

      expect(response.statusCode, 200);
      expect(response.data, isA<Map>());
      expect((response.data as Map).containsKey('content'), isTrue);
    },
    skip: !runE2E || e2eToken.isEmpty,
  );
}
