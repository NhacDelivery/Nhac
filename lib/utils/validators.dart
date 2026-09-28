import 'package:email_validator/email_validator.dart';

class Validators {
  
  static String? validarNome(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório';
    }
        if (value.trim().length < 2) {
      return 'O nome deve ter pelo menos 2 letras';
    }

    if (!RegExp(r'^[a-zA-ZÀ-ÿ\s]+$').hasMatch(value)) {
      return 'O nome não pode conter números ou caracteres especiais';
    }
    return null;
  }

  static String? validarEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'E-mail obrigatório';
    }
    if (!RegExp(r'^[a-zA-Z0-9@.]+$').hasMatch(value.trim())) {
      return 'Caracteres inválidos (use apenas letras, números, @ e ponto)';
    }

    if (!EmailValidator.validate(value.trim())) {
      return 'E-mail inválido';
    }
    return null;
  }

  static String? validarSenha(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Senha obrigatória';
    }
    if (value.length < 8) {
      return 'Mínimo de 8 caracteres';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Precisa de pelo menos uma letra maiúscula';
    }
    return null;
  }

  static String? validarTelefone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Telefone obrigatório';
    }
    if (!RegExp(r'^[0-9\s()\-]+$').hasMatch(value)) {
      return 'O telefone não pode conter letras ou caracteres especiais';
    }

    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 10 || digitsOnly.length > 11) {
      return 'Tamanho inválido (deve ter 10 ou 11 números)';
    }
    return null;
  }

  static String? validarCPF(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'CPF obrigatório';
    }

    final cpf = value.replaceAll(RegExp(r'\D'), '');

    if (cpf.length != 11) {
      return 'O CPF deve ter 11 dígitos';
    }

    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) {
      return 'CPF inválido';
    }

    if (!_validarDigitosCPF(cpf)) {
      return 'CPF inválido';
    }

    return null;
  }

  static bool _validarDigitosCPF(String cpf) {
    List<int> numbers = cpf.split('').map((s) => int.parse(s)).toList();

    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += numbers[i] * (10 - i);
    }
    int result = sum % 11;
    int firstDigit = result < 2 ? 0 : 11 - result;
    if (numbers[9] != firstDigit) return false;

    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += numbers[i] * (11 - i);
    }
    result = sum % 11;
    int secondDigit = result < 2 ? 0 : 11 - result;
    if (numbers[10] != secondDigit) return false;

    return true;
  }
}
