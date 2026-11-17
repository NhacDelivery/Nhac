import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/controllers/user_provider.dart';
import 'package:nhac/models/usuario/usuario_model.dart';
import 'package:nhac/repositories/user_repository.dart';
import 'package:nhac/services/auth_service.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockAuthService extends Mock implements AuthService {}

void main() {
  group('UserProvider Unit Tests', () {
    late UserProvider userProvider;
    late MockUserRepository mockRepo;
    late MockAuthService mockAuth;

    setUp(() {
      mockRepo = MockUserRepository();
      mockAuth = MockAuthService();

      when(() => mockAuth.usuarioId).thenReturn('user-123');

      userProvider = UserProvider(authService: mockAuth, repository: mockRepo);
    });

    tearDown(() => userProvider.dispose());

    test('limparUsuario deve resetar o usuário', () {
      userProvider.limparUsuario();
      expect(userProvider.usuario, isNull);
    });

    test(
      'o perfil exibe o novo banner quando o servidor confirma a troca',
      () async {
        final imagem = XFile('capa.jpg');
        const url = 'https://example.com/capa.jpg';
        when(() => mockRepo.atualizarBanner('user-123', imagem)).thenAnswer(
          (_) async => UsuarioModel(
            id: 'user-123',
            nome: 'Cliente',
            email: '',
            telefone: '',
            bannerUrl: url,
          ),
        );

        expect(await userProvider.atualizarBannerPerfil(imagem), isTrue);
        expect(userProvider.usuario?.bannerUrl, url);
      },
    );
  });
}
