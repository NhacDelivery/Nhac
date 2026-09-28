import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/repositories/loja_repository.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late LojaRepository repository;

  setUp(() {
    dio = MockDio();
    repository = LojaRepository(dio: dio);
  });

  test('calcularFrete usa o contrato tipado do backend', () async {
    when(() => dio.post(
          '/lojas/loja1/calcular-frete',
          data: {'lat': -23.5, 'lng': -46.6},
        )).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/lojas/loja1/calcular-frete'),
        statusCode: 200,
        data: {'valor': 5.50, 'tempoEstimadoMinutos': 45},
      ),
    );
    final frete = await repository.calcularFrete(
      'loja1',
      lat: -23.5,
      lng: -46.6,
    );

    expect(frete.valor, 5.5);
    expect(frete.tempoEstimadoMinutos, 45);
  });
}
