import 'package:flutter/material.dart';
import 'package:nhac/components/seta_voltar.dart';
import 'dart:async';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/globals/ui_utils.dart';

class InserirCodigoRecuperacaoPage extends StatefulWidget {
  final String metodo;
  final String contato;

  const InserirCodigoRecuperacaoPage({super.key, required this.metodo, required this.contato});

  @override
  State<InserirCodigoRecuperacaoPage> createState() => _InserirCodigoRecuperacaoPageState();
}

class _InserirCodigoRecuperacaoPageState extends State<InserirCodigoRecuperacaoPage> {
  int _tempoRestante = 60;
  bool _podeReenviar = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _iniciarTimer();
  }

  void _iniciarTimer() {
    setState(() {
      _tempoRestante = 60;
      _podeReenviar = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_tempoRestante > 0) {
        setState(() {
          _tempoRestante--;
        });
      } else {
        setState(() {
          _podeReenviar = true;
        });
        timer.cancel();
      }
    });
  }

  Future<void> _reenviarCodigo() async {
    final authService = context.read<AuthService>();
    try {
      await authService.esqueciSenhaEmail(widget.contato);
      _iniciarTimer();
      if (mounted) {
        context.showSuccess("Código reenviado com sucesso!");
      }
    } catch (e) {
      if (mounted) {
        context.showError(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final corAtual = _podeReenviar ? const Color(0xFFFF6961) : const Color(0xFF5D201C);
    final textoAtual = _podeReenviar
        ? 'Reenviar código'
        : 'Reenviar código em 00:${_tempoRestante.toString().padLeft(2, '0')}';
        
    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SetaVoltar(),
                const SizedBox(height: 18.0),
                const Text(
                  'Verifique o código',
                  style: TextStyle(
                    fontSize: 28.0,
                    color: Color(0xFF5D201C),
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text.rich(
                  TextSpan(
                    text: 'Insira o código enviado para ',
                    style: const TextStyle(color: Color(0x995D201C), fontWeight: FontWeight.w600),
                    children: [
                      TextSpan(
                        text: widget.contato,
                        style: const TextStyle(color: Color(0xFF5D201C), fontWeight: FontWeight.w900, fontSize: 16.0),
                      ),
                      const TextSpan(text: '. O código pode demorar até 1 minuto para chegar.'),
                    ],
                  ),
                ),
                const SizedBox(height: 32.0),
                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  pinTheme: PinTheme(
                    inactiveFillColor: const Color(0x33C9BCBC),
                    activeFillColor: const Color(0x33C9BCBC),
                    selectedFillColor: const Color(0x33C9BCBC),
                    inactiveColor: Colors.transparent,
                    activeColor: Colors.transparent,
                    selectedColor: Colors.transparent,
                    borderWidth: 1.0,
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(8.0),
                    fieldWidth: 50.0,
                    fieldHeight: 50.0,
                  ),
                  textStyle: const TextStyle(color: Color(0xFF5D201C), fontSize: 24.0, fontWeight: FontWeight.w600),
                  keyboardType: TextInputType.number,
                  enableActiveFill: true,
                  onChanged: (value) {},
                  onCompleted: (value) {
                    context.push('/recuperacao/nova-senha', extra: {
                      'metodo': widget.metodo,
                      'contato': widget.contato,
                      'codigo': value,
                    });
                  },
                ),
                const SizedBox(height: 24.0),
                Center(
                  child: TextButton(
                    onPressed: _podeReenviar ? _reenviarCodigo : null,
                    style: TextButton.styleFrom(
                      foregroundColor: corAtual,
                      textStyle: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600),
                    ),
                    child: Text(textoAtual),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
