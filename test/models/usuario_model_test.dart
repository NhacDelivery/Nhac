import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/models/usuario/usuario_model.dart';

void main() {
  group('UsuarioModel', () {
    test('deve inicializar com sucesso', () {
      final usuario = UsuarioModel(
        id: '1',
        nome: 'João',
        email: 'joao@teste.com',
        telefone: '+5511999999999',
        imagemUrl: 'http://img.com',
        senha: '123',
      );

      expect(usuario.id, '1');
      expect(usuario.nome, 'João');
      expect(usuario.email, 'joao@teste.com');
      expect(usuario.telefone, '+5511999999999');
      expect(usuario.imagemUrl, 'http://img.com');
      expect(usuario.senha, '123');
    });

    test('deve criar a partir do Map (fromMap)', () {
      final map = {
        'id': '2',
        'nome': 'Maria',
        'email': 'maria@teste.com',
        'telefone': '11988887777',
        'imagemUrl': 'http://maria.com',
      };

      final usuario = UsuarioModel.fromMap(map);

      expect(usuario.id, '2');
      expect(usuario.nome, 'Maria');
      expect(usuario.email, 'maria@teste.com');
      expect(usuario.telefone, '11988887777');
      expect(usuario.imagemUrl, 'http://maria.com');
      expect(usuario.senha, null);
    });

    test('deve lidar com valores nulos no fromMap de forma segura', () {
      final map = <String, dynamic>{};

      final usuario = UsuarioModel.fromMap(map);

      expect(usuario.id, '');
      expect(usuario.nome, '');
      expect(usuario.email, '');
      expect(usuario.telefone, '');
      expect(usuario.imagemUrl, null);
    });

    test('deve serializar para Map corretamente (toMap)', () {
      final usuario = UsuarioModel(
        id: '3',
        nome: 'Carlos',
        email: 'carlos@teste.com',
        telefone: '11977776666',
        imagemUrl: 'http://carlos.com',
        senha: 'abc',
      );

      final map = usuario.toMap();

      expect(map['id'], '3');
      expect(map['nome'], 'Carlos');
      expect(map['email'], 'carlos@teste.com');
      expect(map['telefone'], '11977776666');
      expect(map['imagemUrl'], 'http://carlos.com');
      expect(map['senha'], 'abc');
    });
  });
}
