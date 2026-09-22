import 'package:flutter/material.dart';
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
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Align(alignment: Alignment.centerLeft, child: SetaVoltar()),
            const SizedBox(height: 24),
            const Text('Meus cupons', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Receba seu cupom de boas-vindas uma vez por conta e aplique no checkout. O desconto vale para os produtos, sem incluir a entrega.'),
            const SizedBox(height: 16),
            if (!_carregando && _erro == null && _cupons.isEmpty)
              ElevatedButton(
                onPressed: _ocupado ? null : _ganhar,
                child: Text(_ocupado ? 'Resgatando...' : 'Ganhar cupom de boas-vindas'),
              ),
            if (_carregando) const Center(child: CircularProgressIndicator()),
            if (_erro != null) ...[
              Text(_erro!),
              TextButton(onPressed: _carregar, child: const Text('Tentar novamente')),
            ],
            for (final cupom in _cupons)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cupom.titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${_moeda.format(cupom.desconto)} de desconto em produtos a partir de ${_moeda.format(cupom.usoMinimo)}'),
                      Text(_validade(cupom)),
                      Text(cupom.status == 'USADO' ? 'Usado' : cupom.status == 'EXPIRADO' ? 'Expirado' : 'Disponível'),
                      if (cupom.status == 'DISPONIVEL')
                        TextButton(
                          onPressed: _ocupado ? null : () => _usar(cupom),
                          child: Text(widget.subtotal == null ? 'Como usar' : 'Aplicar cupom'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
