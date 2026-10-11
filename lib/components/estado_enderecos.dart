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
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            LoadingNhac(telaCheia: false, tamanho: 32),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Atualizando endereço…',
                style: TextStyle(
                  color: Color(0xFF5D201C),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
