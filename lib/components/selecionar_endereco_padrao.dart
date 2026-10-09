import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nhac/controllers/endereco_provider.dart';
import 'package:nhac/globals/ui_utils.dart';

Future<bool> selecionarEnderecoPadrao(BuildContext context, String id) async {
  try {
    await context.read<EnderecoProvider>().definirComoPadrao(id);
    return context.mounted;
  } catch (_) {
    if (context.mounted) {
      context.showError(
          'Não foi possível alterar o endereço padrão. Tente novamente.');
    }
    return false;
  }
}
