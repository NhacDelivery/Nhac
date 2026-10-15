import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/models/entrega/rota_entrega_model.dart';

void main() {
  test('interpreta coordenadas, distância e trajeto da API real', () {
    final rota = RotaEntregaModel.fromMap({
      'pedidoId': 'p1',
      'lojaNome': 'Loja',
      'origem': {'latitude': -23.55, 'longitude': -46.63},
      'destino': {'latitude': '-23.56', 'longitude': '-46.64'},
      'distanciaKm': 2.3,
      'duracaoEstimadaMinutos': 12,
      'waypoints': [
        {'latitude': -23.55, 'longitude': -46.63},
        {'latitude': -23.56, 'longitude': -46.64},
      ],
    });
    expect(rota.origem.isValido, isTrue);
    expect(rota.destino.isValido, isTrue);
    expect(rota.distanciaKm, 2.3);
    expect(rota.duracaoEstimadaMinutos, 12);
    expect(rota.waypoints, hasLength(2));
  });

  test(
    'coordenadas ausentes, fora do intervalo ou não finitas não vão ao mapa',
    () {
      for (final ponto in [
        const PontoCoordenadaModel(latitude: 0, longitude: 0),
        const PontoCoordenadaModel(latitude: 91, longitude: -46),
        const PontoCoordenadaModel(latitude: -23, longitude: 181),
        PontoCoordenadaModel(latitude: double.nan, longitude: -46),
      ]) {
        expect(ponto.isValido, isFalse);
      }
    },
  );
}
