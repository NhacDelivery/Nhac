import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/utils/endereco_utils.dart';

void main() {
  group('EnderecoUtils', () {
    group('normalizarEstado', () {
      test('deve retornar string vazia para nulo', () {
        expect(EnderecoUtils.normalizarEstado(null), '');
      });

      test('deve retornar string vazia para string vazia ou espaços', () {
        expect(EnderecoUtils.normalizarEstado('   '), '');
      });

      test('deve retornar a própria sigla em uppercase se já tiver 2 caracteres', () {
        expect(EnderecoUtils.normalizarEstado('sp'), 'SP');
        expect(EnderecoUtils.normalizarEstado(' rj '), 'RJ');
      });

      test('deve converter nome completo para sigla (sem acentos e case insensitive)', () {
        expect(EnderecoUtils.normalizarEstado('São Paulo'), 'SP');
        expect(EnderecoUtils.normalizarEstado('são paulo'), 'SP');
        expect(EnderecoUtils.normalizarEstado('SAO PAULO'), 'SP');
        expect(EnderecoUtils.normalizarEstado(' Ceará '), 'CE');
        expect(EnderecoUtils.normalizarEstado('Mato Grosso do SUL'), 'MS');
      });

      test('deve retornar string vazia se não encontrar o estado', () {
        expect(EnderecoUtils.normalizarEstado('Estado Inexistente'), '');
      });
    });

    group('normalizarNumero', () {
      test('deve retornar S/N para nulo', () {
        expect(EnderecoUtils.normalizarNumero(null), 'S/N');
      });

      test('deve retornar S/N para string vazia', () {
        expect(EnderecoUtils.normalizarNumero('   '), 'S/N');
      });

      test('deve retornar o número sem espaços extras', () {
        expect(EnderecoUtils.normalizarNumero(' 123 '), '123');
        expect(EnderecoUtils.normalizarNumero('123A'), '123A');
      });
    });

    group('normalizarCidade', () {
      test('deve retornar a primeira cidade não nula e não vazia da lista', () {
        expect(EnderecoUtils.normalizarCidade([null, '  ', 'São Paulo', 'Campinas']), 'São Paulo');
        expect(EnderecoUtils.normalizarCidade(['Campinas', 'São Paulo']), 'Campinas');
      });

      test('deve retornar string vazia se nenhuma cidade for válida', () {
        expect(EnderecoUtils.normalizarCidade([null, '  ']), '');
        expect(EnderecoUtils.normalizarCidade([]), '');
      });
    });

    group('ehValido', () {
      test('deve retornar true se todos os campos forem preenchidos corretamente', () {
        expect(EnderecoUtils.ehValido(cidade: 'São Paulo', estado: 'SP', numero: '123'), true);
      });

      test('deve retornar false se a cidade estiver vazia', () {
        expect(EnderecoUtils.ehValido(cidade: '   ', estado: 'SP', numero: '123'), false);
      });

      test('deve retornar false se o estado não tiver 2 caracteres', () {
        expect(EnderecoUtils.ehValido(cidade: 'São Paulo', estado: 'São Paulo', numero: '123'), false);
        expect(EnderecoUtils.ehValido(cidade: 'São Paulo', estado: 'S', numero: '123'), false);
      });

      test('deve retornar false se o número estiver vazio', () {
        expect(EnderecoUtils.ehValido(cidade: 'São Paulo', estado: 'SP', numero: '   '), false);
      });
    });
  });
}
