import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nhac/controllers/endereco_provider.dart';
import 'package:nhac/components/estado_com_retry.dart';

class EstadoEnderecos extends StatelessWidget {
  const EstadoEnderecos({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EnderecoProvider>();
    if (provider.erro != null) {
      return BannerErroInline(
        mensagem: provider.erro!,
        aoTentarNovamente: provider.buscarEnderecos,
      );
    }
    if (provider.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('Atualizando endereços...'),
      );
    }
    return const SizedBox.shrink();
  }
}
