import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:nhac/globals/ui_utils.dart';
import 'app_exceptions.dart';
import 'package:nhac/globals/exceptions.dart' as legacy;

class ErrorUIHelper {
  /// Ponto único de texto para banners e notificações, sem expor erros técnicos.
  static String mensagem(
    Object? error, {
    String fallback =
        'Não foi possível concluir a solicitação. Tente novamente.',
  }) {
    final exception = error is DioException ? error.error : error;
    if (exception is AppException) return exception.message;
    if (exception is legacy.AppException) return exception.message;
    if (error is DioException) {
      final mapped = legacy.mapException(error);
      if (mapped is legacy.AppException) return mapped.message;
    }
    return fallback;
  }

  static void handle(
    BuildContext context,
    dynamic error, {
    Function(Map<String, dynamic> errors)? onValidationFailed,
    Function()? onNotFound,
  }) {
    // 1. Extrai o erro caso ele venha embrulhado pelo DioException
    final exception = (error is DioException) ? error.error : error;

    // 2. Validação de Formulários (Status 400)
    if (exception is ValidationException && onValidationFailed != null) {
      onValidationFailed(exception.validationErrors);
      return;
    }

    // 3. Recurso não encontrado (Status 404)
    if (exception is NotFoundException && onNotFound != null) {
      onNotFound(); // A tela decide se fecha ou se renderiza um Empty State
      return;
    }

    // 4. Exibição de Mensagens para o Usuário (SnackBar / Toast)
    final displayMessage = mensagem(error);

    // Usando context.showError para mostrar o feedback global
    context.showError(displayMessage);
  }
}
