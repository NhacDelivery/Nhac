import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:nhac/globals/ui_utils.dart';
import 'app_exceptions.dart';

class ErrorUIHelper {
  static void handle(BuildContext context, dynamic error, {
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
    String displayMessage = "Ocorreu um erro inesperado.";
    
    if (exception is AppException) {
      displayMessage = exception.message;
    }

    // Usando context.showError para mostrar o feedback global
    context.showError(displayMessage);
  }
}
