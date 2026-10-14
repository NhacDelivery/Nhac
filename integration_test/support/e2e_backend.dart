import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/globals/app_constants.dart';
import 'package:nhac/services/api_client.dart';

import 'e2e_config.dart';

/// Atores usam as rotas públicas da aplicação, com sessões separadas do cliente.
Future<Dio> fixtureActor(String email) async {
  AppConstants.validateE2EConfiguration();
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  final response = await dio.post<Map<String, dynamic>>(
    '/auth/login',
    data: {'email': email, 'senha': E2EConfig.password},
  );
  dio.options.headers['Authorization'] = 'Bearer ${response.data!['token']}';
  return dio;
}

Future<Map<String, dynamic>> clientOrder(String id) async =>
    (await ApiClient().dio.get<Map<String, dynamic>>('/pedidos/$id')).data!;

Future<void> expectSingleOrderAndStock(String id, Dio merchant) async {
  // HTTP direto evita que o próprio teste aprove uma resposta em cache.
  final history =
      (await ApiClient().dio.get<Map<String, dynamic>>(
            '/pedidos',
          )).data!['content']
          as List;
  expect(history, hasLength(1));
  expect((history.single as Map)['id'], id);
  final product = await merchant.get<Map<String, dynamic>>(
    '/lojista/produtos/${E2EConfig.productId}',
  );
  expect(product.data!['estoque'], 19, reason: 'uma única reserva de estoque');
}

/// Evento assinado contra o segredo exclusivo de application-e2e.properties.
/// A API version acompanha stripe-java 33.4.2; nunca chama o provedor externo.
Future<void> stripeEvent(String id, String type, {bool invalid = false}) async {
  AppConstants.validateE2EConfiguration();
  final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final payload = jsonEncode({
    'id': 'evt_e2e_${id}_${type.split('.').last}',
    'object': 'event',
    'api_version': '2026-08-26.dahlia',
    'created': timestamp,
    'livemode': false,
    'type': type,
    'data': {
      'object': {
        'id': 'e2e_mock_cartao_$id',
        'object': 'payment_intent',
        'amount': 3000,
        'currency': 'brl',
        'status': type.endsWith('succeeded')
            ? 'succeeded'
            : 'requires_payment_method',
      },
    },
  });
  final signature = Hmac(
    sha256,
    utf8.encode('whsec_e2e_mock'),
  ).convert(utf8.encode('$timestamp.$payload'));
  final response = await Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl))
      .post(
        '/webhooks/stripe',
        data: payload,
        options: Options(
          contentType: 'application/json',
          headers: {
            'Stripe-Signature':
                't=$timestamp,v1=${invalid ? 'invalid' : signature}',
          },
          validateStatus: (status) => status == 200 || status == 400,
        ),
      );
  expect(response.statusCode, invalid ? 400 : 200);
}
