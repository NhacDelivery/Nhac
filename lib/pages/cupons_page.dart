import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nhac/components/seta_voltar.dart';
import 'package:nhac/globals/ui_utils.dart';
import 'package:nhac/models/usuario/cupom_model.dart';
import 'package:nhac/repositories/cupom_repository.dart';

class CuponsPage extends StatefulWidget {
  final double? subtotal;
  const CuponsPage({super.key, this.subtotal});

  @override
  State<CuponsPage> createState() => _CuponsPageState();
}

class _CuponsPageState extends State<CuponsPage> {
  final _repository = CupomRepository();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  List<CupomModel> _cupons = [];
  bool _carregando = true;
  bool _ocupado = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final cupons = await _repository.buscarCupons();
      if (!mounted) return;
      setState(() {
        _cupons = cupons;
        _erro = null;
      });
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _ganhar() async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      final cupom = await _repository.ganharBoasVindas();
      if (!mounted) return;
      context.showSuccess(cupom.status == 'DISPONIVEL'
          ? 'Seu cupom de boas-vindas está disponível!'
          : 'Você já recebeu seu cupom de boas-vindas.');
      await _carregar();
    } catch (e) {
      if (mounted) context.showError(e.toString());
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _usar(CupomModel cupom) async {
    if (_ocupado) return;
    if (widget.subtotal == null) {
      context.showInfo('Escolha seus produtos e aplique o cupom no checkout.');
      return;
    }
    setState(() => _ocupado = true);
    try {
      final validado = await _repository.validarCupom(cupom.id, widget.subtotal!);
      if (mounted) context.pop(validado);
    } catch (e) {
      if (mounted) context.showError(e.toString());
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  String _validade(CupomModel cupom) {
    final data = DateTime.tryParse(cupom.dataValidade ?? '');
    return data == null ? 'Sem validade definida' : 'Válido até ${DateFormat('dd/MM/yyyy').format(data)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFFF6961),
          onRefresh: _carregar,
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
          children: [
            const Align(alignment: Alignment.centerLeft, child: SetaVoltar()),
            const SizedBox(height: 24),
            const Text('Meus cupons', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF5D201C))),
            const SizedBox(height: 12),
            Text(
              widget.subtotal == null
                  ? 'Confira seus benefícios e use um cupom na próxima compra.'
                  : 'Escolha um cupom disponível para aplicar neste pedido.',
              style: const TextStyle(color: Color(0x995D201C), height: 1.45),
            ),
            const SizedBox(height: 16),
            if (!_carregando && _erro == null && _cupons.isEmpty)
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: const Color(0xFFFF6961).withValues(alpha: 0.12)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.local_offer_outlined, size: 36.r, color: const Color(0xFFFF6961)),
                    SizedBox(height: 10.h),
                    const Text('Nenhum cupom por aqui', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF5D201C))),
                    SizedBox(height: 14.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _ocupado ? null : _ganhar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6961),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                        ),
                        child: Text(_ocupado ? 'Resgatando...' : 'Ganhar cupom de boas-vindas'),
                      ),
                    ),
                  ],
                ),
              ),
            if (_carregando) const Center(child: CircularProgressIndicator()),
            if (_erro != null) ...[
              Text(_erro!),
              TextButton(onPressed: _carregar, child: const Text('Tentar novamente')),
            ],
            for (final cupom in _cupons)
              Container(
                margin: EdgeInsets.only(bottom: 14.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: const Color(0xFFFF6961).withValues(alpha: 0.14)),
                  boxShadow: [BoxShadow(color: const Color(0xFF5D201C).withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 8))],
                ),
                child: Padding(
                  padding: EdgeInsets.all(18.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42.r,
                            height: 42.r,
                            decoration: BoxDecoration(color: const Color(0xFFFF6961).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13.r)),
                            child: Icon(Icons.local_offer_rounded, color: const Color(0xFFFF6961), size: 22.r),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(child: Text(cupom.titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF5D201C)))),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Text('${_moeda.format(cupom.desconto)} de desconto em produtos a partir de ${_moeda.format(cupom.usoMinimo)}'),
                      Text(_validade(cupom)),
                      Text(cupom.status == 'USADO' ? 'Usado' : cupom.status == 'EXPIRADO' ? 'Expirado' : 'Disponível'),
                      if (cupom.status == 'DISPONIVEL')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _ocupado ? null : () => _usar(cupom),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6961),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                            ),
                            child: Text(widget.subtotal == null ? 'Como usar' : 'Aplicar cupom'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}
