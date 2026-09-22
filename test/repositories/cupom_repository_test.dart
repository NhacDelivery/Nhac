import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/repositories/cupom_repository.dart';
class MockDio extends Mock implements Dio {}
void main() {
  test('validação envia cupom e subtotal; desconto vem do servidor', () async {
    final dio = MockDio();
    when(() => dio.post('/cupons/validar', data: any(named: 'data'))).thenAnswer((_) async => Response(
      requestOptions: RequestOptions(path: '/cupons/validar'), data: {
        'id': 'cupom', 'desconto': 5, 'usoMinimo': 25, 'descontoAplicado': 5, 'status': 'DISPONIVEL',
      },
    ));
    final resultado = await CupomRepository(dio: dio).validarCupom('cupom', 30);
    expect(resultado.descontoAplicado, 5);
    verify(() => dio.post('/cupons/validar', data: {'cupomId': 'cupom', 'subtotal': 30.0})).called(1);
  });
}
