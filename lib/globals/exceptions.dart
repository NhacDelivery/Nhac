import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nhac/utils/app_exceptions.dart' as app_exc;

class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, {this.code});

  @override
  String toString() => message;
}

class AuthException extends AppException {
  AuthException(super.message, {super.code});
}

class NetworkException extends AppException {
  NetworkException(super.message);
}

class CustomCheckoutException extends AppException {
  final String title;
  final String? produtoId;
  final List<dynamic>? suggestions;

  CustomCheckoutException({
    required String message,
    required this.title,
    this.produtoId,
    this.suggestions,
    String? code,
  }) : super(message, code: code);
}

Exception mapException(Object error) {
  if (error is DioException) {
    if (error.error is app_exc.AppException) {
      return error.error as app_exc.AppException;
    }

    if (error.response?.data != null && error.response!.data is Map) {
      final data = error.response!.data as Map;
      if (data.containsKey('message')) {
        return AppException(
          data['message'].toString(),
          code: data['error']?.toString(),
        );
      }
    }

    if (error.response?.statusCode == 401) {
      return AuthException('Sessão expirada. Faça login novamente.');
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return NetworkException('Sem conexão com a internet.');
    }

    if (error.type == DioExceptionType.cancel) {
      return NetworkException('Tempo esgotado. Tente novamente.');
    }

    return AppException(
      'Ocorreu um erro no servidor: ${error.response?.statusCode ?? error.message}',
      code: error.response?.statusCode?.toString(),
    );
  }

  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'user-not-found':
        return AuthException('Usuário não encontrado.');
      case 'wrong-password':
        return AuthException('Senha incorreta.');
      case 'email-already-in-use':
        return AuthException('Este e-mail já está em uso por outra conta.');
      case 'invalid-email':
        return AuthException('E-mail inválido.');
      case 'weak-password':
        return AuthException('A senha deve ter no mínimo 6 caracteres.');
      case 'user-disabled':
        return AuthException('Esta conta foi desativada.');
      case 'operation-not-allowed':
        return AuthException('Operação não permitida pelo servidor.');
      case 'account-exists-with-different-credential':
        return AuthException('Este e-mail já está associado a outra conta.');
      case 'invalid-credential':
        return AuthException('Credenciais inválidas. Tente novamente.');
      default:
        return AuthException(error.message ?? 'Erro de autenticação.');
    }
  }

  if (error is AppException) return error;

  if (error.toString().contains('SocketException')) {
    return NetworkException('Sem conexão com a internet.');
  }

  return AppException('Ocorreu um erro inesperado: $error');
}
