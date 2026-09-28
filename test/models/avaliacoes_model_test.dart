import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/models/produto/avaliacoes.dart';

void main() {
  test('preserva a data enviada pelo contrato de avaliações do backend', () {
    final avaliacao = AvaliacoesModel.fromMap({
      'id': 'avaliacao-1',
      'nomeUsuario': 'Maria',
      'nota': 5,
      'comentario': 'Muito bom!',
      'dataCriacao': '2026-09-21T12:30:00',
    }, 'avaliacao-1');

    expect(avaliacao.criadoEm, '2026-09-21T12:30:00');
    expect(avaliacao.nota, 5.0);
    expect(avaliacao.nomeUsuario, 'Maria');
  });

  test('mantém a leitura de datas de avaliações antigas', () {
    final avaliacao = AvaliacoesModel.fromMap({
      'criadoEm': '2025-01-01T10:00:00',
    }, 'antiga');

    expect(avaliacao.criadoEm, '2025-01-01T10:00:00');
  });

  test('prioriza a data do backend quando ambos os campos existem', () {
    final avaliacao = AvaliacoesModel.fromMap({
      'dataCriacao': '2026-09-21T12:30:00',
      'criadoEm': '2025-01-01T10:00:00',
    }, 'avaliacao-1');

    expect(avaliacao.criadoEm, '2026-09-21T12:30:00');
  });
}
