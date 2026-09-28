import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeOrderTrackingCard extends StatefulWidget {
  const HomeOrderTrackingCard({super.key});

  @override
  State<HomeOrderTrackingCard> createState() => _HomeOrderTrackingCardState();
}

class _HomeOrderTrackingCardState extends State<HomeOrderTrackingCard>
    with SingleTickerProviderStateMixin {
  PedidoModel? _activePedido;
  bool _loading = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadActiveOrder();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveOrder() async {
    try {
      final historico =
          await PedidoRepository().buscarHistorico(page: 0, size: 5);
      final active = historico.where((p) => !p.status.terminal).toList();
      if (active.isNotEmpty) {
        final fullPedido =
            await PedidoRepository().buscarPedidoPorId(active.first.id);
        if (mounted) {
          setState(() {
            _activePedido = fullPedido;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _estimativa(StatusPedido status) {
    switch (status) {
      case StatusPedido.pendente:
        return 'Aguardando pagamento';
      case StatusPedido.pago:
        return 'Estimativa: ~35 min';
      case StatusPedido.preparando:
        return 'Estimativa: ~20 min';
      case StatusPedido.saiuEntrega:
        return 'Estimativa: ~10 min';
      default:
        return '';
    }
  }

  IconData _statusIcon(StatusPedido status) {
    switch (status) {
      case StatusPedido.pendente:
        return Icons.payment_rounded;
      case StatusPedido.pago:
        return Icons.check_circle_outline_rounded;
      case StatusPedido.preparando:
        return Icons.restaurant_rounded;
      case StatusPedido.saiuEntrega:
        return Icons.delivery_dining_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _activePedido == null) return const SizedBox.shrink();

    final pedido = _activePedido!;
    final stage = pedido.status.stage;
    const totalStages = 4;
    final progress = stage / totalStages;

    final imageUrl =
        pedido.itens.isNotEmpty ? pedido.itens.first.imagemUrl : '';

    return GestureDetector(
      onTap: () => context.push('/rastreio?pedidoId=${pedido.id}'),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row: icon + status + arrow ──
              Row(
                children: [
                  // Animated pulse icon
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 42.w,
                        height: 42.w,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE7E5).withValues(
                              alpha: 0.5 + _pulseController.value * 0.5),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          _statusIcon(pedido.status),
                          color: const Color(0xFFFE645C),
                          size: 22.r,
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pedido.status.label,
                          style: TextStyle(
                            color: const Color(0xFF5D201C),
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          _estimativa(pedido.status),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.grey.shade400,
                      size: 14.r,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 14.h),

              // Product thumbnail and name
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 48.w,
                            height: 48.w,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 48.w,
                              height: 48.w,
                              color: const Color(0xFFFFE7E5),
                              child: Icon(
                                Icons.fastfood_rounded,
                                color: const Color(0xFFFE645C),
                                size: 20.r,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 48.w,
                              height: 48.w,
                              color: const Color(0xFFFFE7E5),
                              child: Icon(
                                Icons.fastfood_rounded,
                                color: const Color(0xFFFE645C),
                                size: 20.r,
                              ),
                            ),
                          )
                        : Container(
                            width: 48.w,
                            height: 48.w,
                            color: const Color(0xFFFFE7E5),
                            child: Icon(
                              Icons.fastfood_rounded,
                              color: const Color(0xFFFE645C),
                              size: 20.r,
                            ),
                          ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      pedido.itens.isNotEmpty
                          ? pedido.itens.first.nome
                          : pedido.lojaNome,
                      style: TextStyle(
                        color: const Color(0xFF5D201C),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 14.h),

              // ── Progress bar ──
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6.r),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      tween: Tween(begin: 0, end: progress),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 6.h,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFE645C)),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 8.h),
                  // ── Stage labels ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStageLabel('Pago', stage >= 1),
                      _buildStageLabel('Preparo', stage >= 2),
                      _buildStageLabel('A caminho', stage >= 3),
                      _buildStageLabel('Entregue', stage >= 4),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageLabel(String label, bool active) {
    return Text(
      label,
      style: TextStyle(
        color: active ? const Color(0xFFFE645C) : Colors.grey.shade400,
        fontSize: 10.sp,
        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
