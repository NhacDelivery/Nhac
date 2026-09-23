// lib/pages/auth/cadastro/verificar_email_cadastro.dart
//
// Etapa que faltava no cadastro depois que o backend passou a exigir
// confirmação de e-mail por código (V031/V032 + AuthController.registrar).
//
// Segue o mesmo visual da InserirCodigoRecuperacaoPage pra não parecer
// uma tela de outro app.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/components/seta_voltar.dart';
import 'package:nhac/globals/ui_utils.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

class VerificarEmailCadastro extends StatefulWidget {
  final String email;

  const VerificarEmailCadastro({super.key, required this.email});

  @override
  State<VerificarEmailCadastro> createState() => _VerificarEmailCadastroState();
}

class _VerificarEmailCadastroState extends State<VerificarEmailCadastro> {
  final TextEditingController _codigoController = TextEditingController();
  final FocusNode _codigoFocus = FocusNode();

  int _tempoRestante = 60;
  bool _podeReenviar = false;
  bool _validando = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _iniciarTimer();
  }

  void _iniciarTimer() {
    _timer?.cancel();
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
        setState(() => _tempoRestante--);
      } else {
        setState(() => _podeReenviar = true);
        timer.cancel();
      }
    });
  }

  Future<void> _reenviarCodigo() async {
    final authService = context.read<AuthService>();
    try {
      await authService.enviarCodigoCadastro(widget.email);
      if (!mounted) return;
      _iniciarTimer();
      if (mounted) context.showSuccess('Código reenviado com sucesso!');
    } catch (e) {
      if (mounted) {
        context.showError(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _validarCodigo(String codigo) async {
    if (_validando) return;
    final localContext = context;
    final authService = localContext.read<AuthService>();

    setState(() => _validando = true);
    try {
      await authService.confirmarEmailCadastro(widget.email, codigo);
      if (!localContext.mounted) return;
      // A partir daqui o backend libera o POST /auth/registrar por 30 min.
      localContext.push('/cadastro/nome');
    } catch (e) {
      if (!localContext.mounted) return;
      final mensagem = e.toString().replaceAll('Exception: ', '');
      localContext.showError(mensagem);
      _codigoController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _codigoFocus.requestFocus();
      });
    } finally {
      if (mounted) {
        setState(() => _validando = false);
        if (_codigoController.text.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _codigoFocus.requestFocus();
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codigoController.dispose();
    _codigoFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final corAtual =
        _podeReenviar ? const Color(0xFFFF6961) : const Color(0xFF5D201C);
    final textoAtual = _podeReenviar
        ? 'Reenviar código'
        : 'Reenviar código em 00:${_tempoRestante.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SetaVoltar(),
                const SizedBox(height: 18.0),
                const Text(
                  'Confirme seu e-mail',
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
                    text: 'Insira o código de 6 dígitos que enviamos para ',
                    style: const TextStyle(
                      color: Color(0x995D201C),
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      TextSpan(
                        text: widget.email,
                        style: const TextStyle(
                          color: Color(0xFF5D201C),
                          fontWeight: FontWeight.w900,
                          fontSize: 16.0,
                        ),
                      ),
                      const TextSpan(
                        text:
                            '. O código pode demorar até 1 minuto para chegar e expira em 15 minutos.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32.0),
                PinCodeTextField(
                  appContext: context,
                  controller: _codigoController,
                  focusNode: _codigoFocus,
                  // O State é o único responsável pelo descarte.
                  autoDisposeControllers: false,
                  autoDismissKeyboard: false,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  length: 6,
                  autoFocus: true,
                  enabled: !_validando,
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
                  textStyle: const TextStyle(
                    color: Color(0xFF5D201C),
                    fontSize: 24.0,
                    fontWeight: FontWeight.w600,
                  ),
                  keyboardType: TextInputType.number,
                  enableActiveFill: true,
                  onChanged: (_) {},
                  onCompleted: _validarCodigo,
                ),
                const SizedBox(height: 16.0),
                if (_validando)
                  const Center(
                    child: SizedBox(
                      height: 22.0,
                      width: 22.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Color(0xFFFF6961),
                      ),
                    ),
                  ),
                const SizedBox(height: 16.0),
                Center(
                  child: TextButton(
                    onPressed:
                        (_podeReenviar && !_validando) ? _reenviarCodigo : null,
                    style: TextButton.styleFrom(
                      foregroundColor: corAtual,
                      textStyle: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                      ),
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
