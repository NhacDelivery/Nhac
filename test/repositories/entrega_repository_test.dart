import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/repositories/entrega_repository.dart';

class MockDio extends Mock implements Dio {}

void main() {
  test(
      '204 é ausência de localização e chamadas simultâneas compartilham operação',
      () async {
    final dio = MockDio();
    when(() => dio.options).thenReturn(BaseOptions());
    when(() => dio.get('/entregas/ped1/localizacao-entregador')).thenAnswer(
        (_) async => Response(
            requestOptions:
                RequestOptions(path: '/entregas/ped1/localizacao-entregador'),
            statusCode: 204));
    final repository = EntregaRepository(dio: dio);
    expect(
        await Future.wait([
          repository.buscarLocalizacaoEntregador('ped1'),
          repository.buscarLocalizacaoEntregador('ped1')
        ]),
        [null, null]);
    verify(() => dio.get('/entregas/ped1/localizacao-entregador')).called(1);
  });

  test('400 preserva mensagem e código de negócio do backend', () async {
    final dio = MockDio();
    when(() => dio.options).thenReturn(BaseOptions());
    final options = RequestOptions(path: '/entregas/ped1/rota');
    when(() => dio.get('/entregas/ped1/rota')).thenThrow(DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 400, data: {
          'errorCode': 'REGRA_DE_NEGOCIO',
          'message': 'Coordenadas da loja inválidas. Corrija o cadastro.',
        })));
    await expectLater(
        EntregaRepository(dio: dio).buscarRota('ped1'),
        throwsA(predicate((e) =>
            e.toString() ==
            'Coordenadas da loja inválidas. Corrija o cadastro.')));
    verify(() => dio.get('/entregas/ped1/rota')).called(1);
  });
  test('parseia rota real retornada pelo backend', () async {
    final dio = MockDio();
    when(() => dio.options).thenReturn(BaseOptions());
    final repository = EntregaRepository(dio: dio);

    when(() => dio.get('/entregas/ped1/rota')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/entregas/ped1/rota'),
        statusCode: 200,
        data: {
          'pedidoId': 'ped1',
          'lojaNome': 'Nhac',
          'origem': {'latitude': -23.5, 'longitude': -46.6},
          'destino': {'latitude': -23.6, 'longitude': -46.7},
          'distanciaMetros': 1200,
          'distanciaKm': 1.2,
          'duracaoEstimadaMinutos': 8,
          'polyline': '',
          'waypoints': [
            {'latitude': -23.5, 'longitude': -46.6},
            {'latitude': -23.6, 'longitude': -46.7},
          ],
        },
      ),
    );

    final rota = await repository.buscarRota('ped1');

    expect(rota.pedidoId, 'ped1');
    expect(rota.distanciaKm, 1.2);
    expect(rota.duracaoEstimadaMinutos, 8);
    expect(rota.waypoints, hasLength(2));
  });
}
