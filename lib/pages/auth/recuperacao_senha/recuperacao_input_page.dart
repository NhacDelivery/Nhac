import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/components/botoes/botao_largo_nhac.dart';
import 'package:nhac/components/seta_voltar.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:nhac/controllers/cadastro_controller.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:nhac/utils/validators.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/globals/ui_utils.dart';

class RecuperacaoInputPage extends StatefulWidget {
  final String metodo; // Mantido por compatibilidade de navegação; backend usa e-mail.

  const RecuperacaoInputPage({super.key, required this.metodo});

  @override
  State<RecuperacaoInputPage> createState() => _RecuperacaoInputPageState();
}

class _RecuperacaoInputPageState extends State<RecuperacaoInputPage> {
  final TextEditingController _controller = TextEditingController();
  bool _valido = false;
  String? _erro;
  bool _isLoading = false;
  // ignore: unused_field
  final _telefoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    if (widget.metodo == 'email') {
      final cadastroData = context.read<CadastroController>();
      if (cadastroData.email.isNotEmpty) {
        _controller.text = cadastroData.email;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _verificarInput();
        });
      }
    }
    _controller.addListener(_verificarInput);
  }

  void _verificarInput() {
    if (!mounted) return;
    final texto = _controller.text;
    String? erroTemp;
    
    if (widget.metodo == 'email') {
      erroTemp = Validators.validarEmail(texto);
    } else {
      if (texto.length < 14) {
        erroTemp = 'Telefone inválido';
      }
    }

    setState(() {
      _erro = erroTemp;
      _valido = erroTemp == null && texto.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_verificarInput);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _enviarCodigo() async {
    final authService = context.read<AuthService>();
    setState(() => _isLoading = true);

    final cancelToken = CancelToken();
    Timer? timeoutTimer = Timer(const Duration(seconds: 15), () {
      cancelToken.cancel('Tempo limite excedido. O servidor demorou muito para responder.');
    });

    try {
      await authService.esqueciSenhaEmail(
        _controller.text.trim(),
        cancelToken: cancelToken,
      );
      timeoutTimer.cancel();

      if (!mounted) return;
      context.push('/recuperacao/codigo', extra: {
        'metodo': widget.metodo,
        'contato': _controller.text.trim(),
      });
    } on DioException catch (e) {
      timeoutTimer.cancel();
      if (!mounted) return;
      context.showError(e.message ?? 'Erro desconhecido');
    } catch (e) {
      timeoutTimer.cancel();
      if (!mounted) return;
      
      String msg = e.toString().replaceAll('Exception: ', '');
      if (e is AppException && e.code == '500') {
        msg = 'Não foi possível enviar o e-mail no momento. Tente novamente mais tarde.';
      }
      
      context.showError(msg);
    } finally {
      timeoutTimer.cancel();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmail = widget.metodo == 'email';

    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SetaVoltar(),
                      const SizedBox(height: 24.0),
                      Text(
                        'Qual o seu e-mail?',
                        style: const TextStyle(
                          fontSize: 28.0,
                          color: Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        'Enviaremos um código para redefinir sua senha.',
                        style: const TextStyle(
                          fontSize: 16.0,
                          color: Color(0xFFC9BCBC),
                          fontFamily: 'Roboto',
                        ),
                      ),
                      const SizedBox(height: 32.0),
                      TextFormField(
                        controller: _controller,
                        keyboardType: TextInputType.emailAddress,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 18.0,
                          color: Color(0xFF5D201C),
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: isEmail ? 'seu@email.com' : '(DD) 9XXXX-XXXX',
                          errorText: _erro,
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFFF6961), width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              BotaoLargoNhac(
                texto: 'Continuar',
                onPressed: _valido ? _enviarCodigo : null,
                carregando: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
