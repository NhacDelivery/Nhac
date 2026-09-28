import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nhac/globals/exceptions.dart';

void main() {
  group('Exceptions', () {
    test('AppException toString retorna a mensagem', () {
      final ex = AppException('Teste de erro');
      expect(ex.toString(), 'Teste de erro');
    });

    group('mapException', () {
      test('deve retornar a mensagem do backend se DioException tiver response com message', () {
        final options = RequestOptions(path: '/');
        final response = Response(
          requestOptions: options,
          statusCode: 400,
          data: {'message': 'Erro customizado do backend'},
        );
        final dioError = DioException(
          requestOptions: options,
          response: response,
          type: DioExceptionType.badResponse,
        );

        final result = mapException(dioError);
        expect(result, isA<AppException>());
        expect(result.toString(), 'Erro customizado do backend');
      });

      test('deve retornar AuthException se statusCode for 401', () {
        final options = RequestOptions(path: '/');
        final response = Response(
          requestOptions: options,
          statusCode: 401,
          data: {}, // Sem message para cair no 401 genérico
        );
        final dioError = DioException(
          requestOptions: options,
          response: response,
          type: DioExceptionType.badResponse,
        );

        final result = mapException(dioError);
        expect(result, isA<AuthException>());
        expect(result.toString(), 'Sessão expirada. Faça login novamente.');
      });

      test('deve retornar NetworkException para timeouts ou connectionError do Dio', () {
        final options = RequestOptions(path: '/');
        
        final errors = [
          DioExceptionType.connectionTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.connectionError,
        ];

        for (final type in errors) {
          final dioError = DioException(
            requestOptions: options,
            type: type,
          );
          final result = mapException(dioError);
          expect(result, isA<NetworkException>());
          expect(result.toString(), 'Sem conexão com a internet.');
        }
      });

      test('deve retornar erro generico de servidor se DioException for badResponse sem message', () {
        final options = RequestOptions(path: '/');
        final response = Response(
          requestOptions: options,
          statusCode: 500,
        );
        final dioError = DioException(
          requestOptions: options,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'Internal Server Error',
        );

        final result = mapException(dioError);
        expect(result.toString(), 'Ocorreu um erro no servidor: 500');
      });

      test('deve mapear FirebaseAuthException corretamente', () {
        final cases = {
          'user-not-found': 'Usuário não encontrado.',
          'wrong-password': 'Senha incorreta.',
          'email-already-in-use': 'Este e-mail já está em uso por outra conta.',
          'invalid-email': 'E-mail inválido.',
          'weak-password': 'A senha deve ter no mínimo 6 caracteres.',
          'user-disabled': 'Esta conta foi desativada.',
          'operation-not-allowed': 'Operação não permitida pelo servidor.',
          'account-exists-with-different-credential': 'Este e-mail já está associado a outra conta.',
          'invalid-credential': 'Credenciais inválidas. Tente novamente.',
        };

        cases.forEach((code, expectedMessage) {
          final fbError = FirebaseAuthException(code: code);
          final result = mapException(fbError);
          expect(result, isA<AuthException>());
          expect(result.toString(), expectedMessage);
        });
      });

      test('deve retornar default para FirebaseAuthException desconhecida', () {
        final fbError = FirebaseAuthException(code: 'unknown', message: 'Mensagem original');
        final result = mapException(fbError);
        expect(result, isA<AuthException>());
        expect(result.toString(), 'Mensagem original');
      });

      test('deve retornar a mesma exceção se já for AppException', () {
        final ex = AppException('Erro app');
        final result = mapException(ex);
        expect(result, ex);
      });

      test('deve retornar NetworkException se toString contiver SocketException', () {
        final error = Exception('SocketException: failed to connect');
        final result = mapException(error);
        expect(result, isA<NetworkException>());
        expect(result.toString(), 'Sem conexão com a internet.');
      });

      test('deve retornar AppException para erro inesperado', () {
        final error = Exception('Algo quebrou');
        final result = mapException(error);
        expect(result, isA<AppException>());
        expect(result.toString(), contains('Ocorreu um erro inesperado: Exception: Algo quebrou'));
      });
    });
  });
}
