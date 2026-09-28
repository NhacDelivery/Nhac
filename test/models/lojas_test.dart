import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/models/loja/lojas.dart';

void main() {
  group('LojasModel', () {
    test('deve inicializar LojasModel com sucesso', () {
      final loja = LojasModel(
        id: '1',
        nome: 'Loja Teste',
        categoria: 'Lanches',
      );

      expect(loja.id, '1');
      expect(loja.nome, 'Loja Teste');
      expect(loja.categoria, 'Lanches');
      expect(loja.descricao, '');
      expect(loja.imagemUrl, '');
      expect(loja.isAberto, true);
    });

    test('deve criar LojasModel a partir de um Map', () {
      final map = {
        'id': '2',
        'nome': 'Burguer Shop',
        'categoria': 'Hamburguer',
        'descricao': 'O melhor',
        'imagemUrl': 'img.jpg',
        'isAberto': false,
        'dadosOperacionais': {
          'avaliacaoMedia': 4.5,
          'taxaEntregaBase': 5.0,
          'tempoEntregaMin': 30,
          'tempoEntregaMax': 45,
          'totalAvaliacoes': 100,
        },
        'endereco': {
          'rua': 'Rua A',
          'numero': '123',
          'cidade': 'São Paulo',
          'estado': 'SP',
          'cep': '00000-000',
        },
        'horarios': {
          'segunda': '09:00 - 18:00',
        }
      };

      final loja = LojasModel.fromMap(map);

      expect(loja.id, '2');
      expect(loja.nome, 'Burguer Shop');
      expect(loja.isAberto, false);
      expect(loja.dadosOperacionais?.avaliacaoMedia, 4.5);
      expect(loja.endereco?.rua, 'Rua A');
      expect(loja.horarios?.segunda, '09:00 - 18:00');
    });

    test('deve lidar com nulos graciosamente no LojasModel', () {
      final loja = LojasModel.fromMap({});
      
      expect(loja.id, '');
      expect(loja.nome, '');
      expect(loja.isAberto, true);
      expect(loja.dadosOperacionais, null);
    });

    test('deve inicializar DadosOperacionais a partir de um Map e tratar tipos', () {
      final dados = DadosOperacionais.fromMap({
        'avaliacaoMedia': '4.5',
        'taxaEntregaBase': '10',
        'tempoEntregaMin': 20,
        'tempoEntregaMax': 40,
        'totalAvaliacoes': 50,
      });

      expect(dados.avaliacaoMedia, 4.5);
      expect(dados.taxaEntregaBase, 10.0);
    });

    test('deve lidar com nulos no DadosOperacionais graciosamente', () {
      final dados = DadosOperacionais.fromMap({});
      
      expect(dados.avaliacaoMedia, 0.0);
      expect(dados.taxaEntregaBase, 0.0);
      expect(dados.tempoEntregaMin, 0);
      expect(dados.totalAvaliacoes, 0);
    });

    test('deve inicializar EnderecoLoja a partir de um Map', () {
      final endereco = EnderecoLoja.fromMap({
        'rua': 'Av B',
      });

      expect(endereco.rua, 'Av B');
      expect(endereco.numero, '');
    });

    test('deve inicializar HorariosLoja a partir de um Map com default Fechado', () {
      final horarios = HorariosLoja.fromMap({
        'domingo': '10:00 - 20:00',
      });

      expect(horarios.domingo, '10:00 - 20:00');
      expect(horarios.segunda, 'Fechado');
    });
  });
}
