import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/repositories/entrega_repository.dart';

class MockDio extends Mock implements Dio {}

void main() {
  test('parseia rota real retornada pelo backend', () async {
    final dio = MockDio();
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
