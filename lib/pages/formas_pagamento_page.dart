import 'package:flutter/material.dart';
import 'package:nhac/components/seta_voltar.dart';

class FormasPagamentoPage extends StatelessWidget {
  const FormasPagamentoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            Align(alignment: Alignment.centerLeft, child: SetaVoltar()),
            SizedBox(height: 24),
            Text('Formas de pagamento',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('Escolha a forma de pagamento ao finalizar seu pedido.'),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.money),
              title: Text('Dinheiro'),
              subtitle: Text('Informe no checkout se precisa de troco.'),
            ),
            ListTile(
              leading: Icon(Icons.pix),
              title: Text('PIX'),
              subtitle: Text('Use o QR Code ou copie o código após criar o pedido.'),
            ),
            ListTile(
              leading: Icon(Icons.credit_card),
              title: Text('Cartão de crédito'),
              subtitle: Text('Preencha os dados na tela segura de pagamento do pedido.'),
            ),
            SizedBox(height: 24),
            Text('Ainda não é possível cadastrar ou gerenciar cartões salvos pelo perfil.'),
          ],
        ),
      ),
    );
  }
}
