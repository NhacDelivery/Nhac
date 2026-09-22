import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/models/loja/lojas.dart';

void main() {
  test('respeita abertura da API mesmo com horários cadastrados como fechado',
      () {
    final loja = LojasModel.fromMap({
      'id': 'loja-1',
      'isAberto': true,
      'horarios': {
        for (final dia in [
          'segunda',
          'terca',
          'quarta',
          'quinta',
          'sexta',
          'sabado',
          'domingo'
        ])
          dia: 'Fechado',
      },
    });

    expect(loja.isAberto, isTrue);
  });

  test('respeita fechamento da API mesmo com horário de funcionamento integral',
      () {
    final loja = LojasModel.fromMap({
      'id': 'loja-1',
      'isAberto': false,
      'horarios': {
        for (final dia in [
          'segunda',
          'terca',
          'quarta',
          'quinta',
          'sexta',
          'sabado',
          'domingo'
        ])
          dia: '00:00 - 23:59',
      },
    });

    expect(loja.isAberto, isFalse);
  });
}
