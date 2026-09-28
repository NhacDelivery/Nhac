import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/utils/validators.dart';

void main() {
  group('Validators', () {
    group('validarNome', () {
      test('deve retornar erro para nulo', () {
        expect(Validators.validarNome(null), 'Campo obrigatório');
      });

      test('deve retornar erro para string vazia', () {
        expect(Validators.validarNome('   '), 'Campo obrigatório');
      });

      test('deve retornar erro para nome menor que 2 caracteres', () {
        expect(Validators.validarNome('A'), 'O nome deve ter pelo menos 2 letras');
      });

      test('deve retornar erro para nome com números', () {
        expect(Validators.validarNome('João 123'), 'O nome não pode conter números ou caracteres especiais');
      });

      test('deve retornar erro para nome com caracteres especiais', () {
        expect(Validators.validarNome('João@'), 'O nome não pode conter números ou caracteres especiais');
      });

      test('deve retornar nulo para nome válido', () {
        expect(Validators.validarNome('João Silva'), null);
        expect(Validators.validarNome('Maria'), null);
        expect(Validators.validarNome('Carlos Antônio'), null);
      });
    });

    group('validarEmail', () {
      test('deve retornar erro para nulo', () {
        expect(Validators.validarEmail(null), 'E-mail obrigatório');
      });

      test('deve retornar erro para string vazia', () {
        expect(Validators.validarEmail('   '), 'E-mail obrigatório');
      });

      test('deve retornar erro para caracteres inválidos', () {
        expect(Validators.validarEmail('joão@gmail.com'), 'Caracteres inválidos (use apenas letras, números, @ e ponto)');
      });

      test('deve retornar erro para email inválido sem domínio', () {
        expect(Validators.validarEmail('joao@'), 'E-mail inválido');
      });

      test('deve retornar nulo para email válido', () {
        expect(Validators.validarEmail('teste@teste.com'), null);
        expect(Validators.validarEmail('usuario123@gmail.com'), null);
      });
    });

    group('validarSenha', () {
      test('deve retornar erro para nulo', () {
        expect(Validators.validarSenha(null), 'Senha obrigatória');
      });

      test('deve retornar erro para string vazia', () {
        expect(Validators.validarSenha('   '), 'Senha obrigatória');
      });

      test('deve retornar erro para senha menor que 8 caracteres', () {
        expect(Validators.validarSenha('Senh1'), 'Mínimo de 8 caracteres');
      });

      test('deve retornar erro para senha sem letra maiúscula', () {
        expect(Validators.validarSenha('senha1234'), 'Precisa de pelo menos uma letra maiúscula');
      });

      test('deve retornar nulo para senha válida', () {
        expect(Validators.validarSenha('Senha123'), null);
      });
    });

    group('validarTelefone', () {
      test('deve retornar erro para nulo', () {
        expect(Validators.validarTelefone(null), 'Telefone obrigatório');
      });

      test('deve retornar erro para string vazia', () {
        expect(Validators.validarTelefone('   '), 'Telefone obrigatório');
      });

      test('deve retornar erro se contiver letras', () {
        expect(Validators.validarTelefone('(11) 9AAAA-BBBB'), 'O telefone não pode conter letras ou caracteres especiais');
      });

      test('deve retornar erro para tamanho menor que 10', () {
        expect(Validators.validarTelefone('(11) 123-456'), 'Tamanho inválido (deve ter 10 ou 11 números)');
      });

      test('deve retornar erro para tamanho maior que 11', () {
        expect(Validators.validarTelefone('(11) 99999-99999'), 'Tamanho inválido (deve ter 10 ou 11 números)');
      });

      test('deve retornar nulo para telefone válido de 10 dígitos', () {
        expect(Validators.validarTelefone('(11) 4002-8922'), null);
      });

      test('deve retornar nulo para telefone válido de 11 dígitos', () {
        expect(Validators.validarTelefone('(11) 99999-9999'), null);
      });
    });

    group('validarCPF', () {
      test('deve retornar erro para nulo', () {
        expect(Validators.validarCPF(null), 'CPF obrigatório');
      });

      test('deve retornar erro para string vazia', () {
        expect(Validators.validarCPF('   '), 'CPF obrigatório');
      });

      test('deve retornar erro se o CPF não tiver 11 dígitos numéricos', () {
        expect(Validators.validarCPF('123.456.789'), 'O CPF deve ter 11 dígitos');
        expect(Validators.validarCPF('123.456.789-012'), 'O CPF deve ter 11 dígitos');
      });

      test('deve retornar erro se todos os dígitos forem iguais', () {
        expect(Validators.validarCPF('111.111.111-11'), 'CPF inválido');
        expect(Validators.validarCPF('00000000000'), 'CPF inválido');
      });

      test('deve retornar erro para CPF com dígito verificador inválido', () {
        expect(Validators.validarCPF('123.456.789-01'), 'CPF inválido');
      });

      test('deve retornar nulo para CPF válido', () {
        expect(Validators.validarCPF('52998224725'), null);
        expect(Validators.validarCPF('529.982.247-25'), null);
      });
    });
  });
}