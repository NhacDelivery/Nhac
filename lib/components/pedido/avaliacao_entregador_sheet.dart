import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nhac/components/loading_nhac.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/globals/ui_utils.dart';
import 'package:nhac/repositories/pedido_repository.dart';

class AvaliacaoEntregadorSheet extends StatefulWidget {
  final String pedidoId;
  final String? entregadorNome;
  final PedidoRepository? pedidoRepository;
  final VoidCallback? onAvaliado;

  const AvaliacaoEntregadorSheet({
    super.key,
    required this.pedidoId,
    this.entregadorNome,
    this.pedidoRepository,
    this.onAvaliado,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String pedidoId,
    String? entregadorNome,
    PedidoRepository? pedidoRepository,
    VoidCallback? onAvaliado,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AvaliacaoEntregadorSheet(
        pedidoId: pedidoId,
        entregadorNome: entregadorNome,
        pedidoRepository: pedidoRepository,
        onAvaliado: onAvaliado,
      ),
    );
  }

  @override
  State<AvaliacaoEntregadorSheet> createState() => _AvaliacaoEntregadorSheetState();
}

class _AvaliacaoEntregadorSheetState extends State<AvaliacaoEntregadorSheet> {
  int _nota = 0;
  final TextEditingController _comentarioController = TextEditingController();
  bool _enviando = false;
  late final PedidoRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.pedidoRepository ?? PedidoRepository();
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  bool _isJaAvaliadoError(dynamic error) {
    if (error is AppException) {
      final code = (error.code ?? '').toUpperCase();
      if (code.contains('JA_AVALIADO') || code.contains('AVALIACAO_EXISTENTE')) {
        return true;
      }
    }
    final msg = error.toString().toLowerCase();
    return msg.contains('já avaliad') ||
        msg.contains('ja avaliad') ||
        msg.contains('já foi avaliad') ||
        msg.contains('ja foi avaliad');
  }

  Future<void> _enviarAvaliacao() async {
    if (_nota < 1 || _nota > 5 || _enviando) return;

    setState(() => _enviando = true);

    try {
      await _repository.avaliarEntregador(
        widget.pedidoId,
        _nota,
        _comentarioController.text,
      );

      if (!mounted) return;
      widget.onAvaliado?.call();
      Navigator.of(context).pop(true);
      context.showSuccess('Obrigado pela sua avaliação!');
    } catch (e) {
      if (!mounted) return;

      if (_isJaAvaliadoError(e)) {
        widget.onAvaliado?.call();
        Navigator.of(context).pop(true);
        context.showSuccess('Avaliação já registrada.');
        return;
      }

      setState(() => _enviando = false);
      context.showError('Não foi possível enviar a avaliação. Tente novamente.');
    }
  }

  String _descricaoNota(int nota) {
    switch (nota) {
      case 1:
        return 'Péssimo';
      case 2:
        return 'Ruim';
      case 3:
        return 'Regular';
      case 4:
        return 'Bom';
      case 5:
        return 'Excelente';
      default:
        return 'Toque nas estrelas para avaliar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final nome = widget.entregadorNome ?? 'o entregador';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.only(
        left: 24.w,
        right: 24.w,
        top: 20.h,
        bottom: bottomInset > 0 ? bottomInset + 16.h : 32.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Avaliar $nome',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5D201C),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6.h),
            Text(
              'Como foi a entrega do seu pedido?',
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 18.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final estrela = index + 1;
                final selecionada = estrela <= _nota;
                return GestureDetector(
                  key: Key('estrela-$estrela'),
                  onTap: _enviando ? null : () => setState(() => _nota = estrela),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6.w),
                    child: Icon(
                      selecionada ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: selecionada ? Colors.amber.shade700 : Colors.grey.shade400,
                      size: 38.sp,
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 8.h),
            Text(
              _descricaoNota(_nota),
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: _nota > 0 ? Colors.amber.shade800 : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            TextField(
              key: const Key('campo-comentario-avaliacao'),
              controller: _comentarioController,
              enabled: !_enviando,
              maxLength: 500,
              maxLines: 3,
              minLines: 2,
              style: TextStyle(fontSize: 14.sp, color: const Color(0xFF5D201C)),
              decoration: InputDecoration(
                hintText: 'Deixe um comentário sobre a entrega (opcional)...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.sp),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFFFF6961)),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: EdgeInsets.all(12.w),
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              height: 48.h,
              child: ElevatedButton(
                key: const Key('botao-enviar-avaliacao'),
                onPressed: (_nota == 0 || _enviando) ? null : _enviarAvaliacao,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6961),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade500,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50.r),
                  ),
                ),
                child: _enviando
                    ? const LoadingNhac(telaCheia: false, tamanho: 24.0)
                    : Text(
                        'Enviar avaliação',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
