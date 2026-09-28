import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nhac/components/seta_voltar.dart';

class FormasPagamentoPage extends StatelessWidget {
  const FormasPagamentoPage({super.key});

  static const _primary = Color(0xFFFF6961);
  static const _text = Color(0xFF5D201C);
  static const _background = Color(0xFFFFE7E5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: SetaVoltar(),
            ),
            SizedBox(height: 24.h),
            Text(
              'Formas de pagamento',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.w800,
                color: _text,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Escolha no checkout como você prefere pagar seu pedido.',
              style: TextStyle(
                fontSize: 14.sp,
                height: 1.45,
                color: _text.withValues(alpha: 0.68),
              ),
            ),
            SizedBox(height: 24.h),
            _PaymentCard(
              icon: Icons.payments_outlined,
              title: 'Dinheiro',
              description:
                  'Pague na entrega e informe no checkout se precisar de troco.',
              badge: 'Na entrega',
            ),
            SizedBox(height: 12.h),
            _PaymentCard(
              icon: Icons.pix,
              title: 'PIX',
              description:
                  'Após criar o pedido, use o QR Code ou o código copia e cola.',
              badge: 'Rápido',
            ),
            SizedBox(height: 12.h),
            _PaymentCard(
              icon: Icons.credit_card_rounded,
              title: 'Cartão de crédito',
              description:
                  'O pagamento é concluído pelo fluxo seguro durante a finalização.',
              badge: 'Online',
            ),
            SizedBox(height: 24.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color: _primary.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38.r,
                    height: 38.r,
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 20.r,
                      color: _primary,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Por enquanto, cartões não ficam salvos no perfil. A forma de pagamento é escolhida a cada pedido.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        height: 1.45,
                        color: _text.withValues(alpha: 0.78),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String badge;

  const _PaymentCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFFF6961);
    const text = Color(0xFF5D201C);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: text.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50.r,
            height: 50.r,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: primary, size: 26.r),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: text,
                        ),
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13.sp,
                    height: 1.4,
                    color: text.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
