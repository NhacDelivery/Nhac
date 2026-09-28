abstract class AppException implements Exception {
  final String message;
  AppException(this.message);

  @override
  String toString() => message;
}

// 1. Validação de formulários (Status 400)
class ValidationException extends AppException {
  final Map<String, dynamic> validationErrors;
  ValidationException(super.message, this.validationErrors);
}

// 1 e 5. Regra de Negócio (Status 400 / 422)
class BusinessRuleException extends AppException {
  BusinessRuleException(super.message);
}

// 2. Não Encontrado (Status 404)
class NotFoundException extends AppException {
  NotFoundException(super.message);
}

// 3. Autenticação e Permissão (Status 401, 403)
class UnauthorizedException extends AppException {
  UnauthorizedException(super.message);
}

class ForbiddenException extends AppException {
  ForbiddenException(super.message);
}

// 4. Rate Limit (Status 429)
class TooManyRequestsException extends AppException {
  TooManyRequestsException([super.message = "Muitas tentativas! Aguarde uns minutos e tente de novo."]);
}

// 6. Erro Interno do Servidor (Status 500)
class ServerException extends AppException {
  ServerException([super.message = "Algo deu errado do nosso lado. Tente novamente mais tarde."]);
}
