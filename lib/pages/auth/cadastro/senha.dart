import 'package:nhac/components/seta_voltar.dart';
import 'package:flutter/material.dart';
import 'package:nhac/components/botoes/botao_largo_nhac.dart';
import 'package:nhac/controllers/cadastro_controller.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:nhac/globals/ui_utils.dart';

import 'package:nhac/components/nhac_input_field.dart';

import 'package:nhac/utils/validators.dart';

@NowaGenerated()
class Senha extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const Senha({super.key});

  @override
  State<Senha> createState() {
    return _SenhaState();
  }
}

@NowaGenerated()
class _SenhaState extends State<Senha> {
  bool _senhaValida = false;
  bool _isLoading = false;
  String? _erroSenha;
  String? _erroConfirmacao;
  bool _senhaVisivel = false;
  bool _confirmacaoVisivel = false;

  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController = TextEditingController();
  final FocusNode _senhaFocus = FocusNode();
  final FocusNode _confirmarSenhaFocus = FocusNode();

  void _verificarSenha() {
    if (!mounted) return;
    final texto = _senhaController.text;
    final confirmacao = _confirmarSenhaController.text;

    String? erroTemp = Validators.validarSenha(texto);
    String? erroConfirmacaoTemp;

    if (confirmacao.isNotEmpty && texto != confirmacao) {
      erroConfirmacaoTemp = 'As senhas não coincidem';
    }

    setState(() {
      _erroSenha = erroTemp;
      _erroConfirmacao = erroConfirmacaoTemp;
      _senhaValida = erroTemp == null &&
          texto.isNotEmpty &&
          confirmacao.isNotEmpty &&
          erroConfirmacaoTemp == null;
    });
  }

  @override
  void dispose() {
    _senhaFocus.dispose();
    _confirmarSenhaFocus.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SetaVoltar(),
                      const SizedBox(height: 18.0),
                      const Text(
                        'Vamos criar a sua senha',
                        style: TextStyle(
                          fontSize: 28.0,
                          color: Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      const Text(
                        'A sua nova senha tem que ter pelo menos 8 caracteres e 1 letra maiúscula.',
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 24.0),
                      NhacInputField(
                        controller: _senhaController,
                        focusNode: _senhaFocus,
                        onChanged: (value) => _verificarSenha(),
                        obscureText: !_senhaVisivel,
                        obscuringCharacter: '⬤',
                        autofocus: true,
                        hintText: 'Senha',
                        errorText: _erroSenha,
                        validator: Validators.validarSenha,
                        style: TextStyle(
                          color: const Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600,
                          letterSpacing: _senhaVisivel ? 0.0 : 4.0,
                        ),
                        suffixIcon: IconButton(
                          icon: _senhaVisivel
                              ? const Icon(
                                  Icons.visibility,
                                  color: Color(0xFFFF6961),
                                )
                              : SvgPicture.asset(
                                  'assets/olho-fechado.svg',
                                  width: 24.0,
                                  height: 24.0,
                                  colorFilter: const ColorFilter.mode(
                                    Color(0xFFC9BCBC),
                                    BlendMode.srcIn,
                                  ),
                                ),
                          onPressed: () {
                            setState(() {
                              _senhaVisivel = !_senhaVisivel;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 24.0),
                      NhacInputField(
                        controller: _confirmarSenhaController,
                        focusNode: _confirmarSenhaFocus,
                        onChanged: (value) => _verificarSenha(),
                        obscureText: !_confirmacaoVisivel,
                        obscuringCharacter: '⬤',
                        hintText: 'Confirmar senha',
                        errorText: _erroConfirmacao,
                        validator: Validators.validarSenha,
                        style: TextStyle(
                          color: const Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600,
                          letterSpacing: _confirmacaoVisivel ? 0.0 : 4.0,
                        ),
                        suffixIcon: IconButton(
                          icon: _confirmacaoVisivel
                              ? const Icon(
                                  Icons.visibility,
                                  color: Color(0xFFFF6961),
                                )
                              : SvgPicture.asset(
                                  'assets/olho-fechado.svg',
                                  width: 24.0,
                                  height: 24.0,
                                  colorFilter: const ColorFilter.mode(
                                    Color(0xFFC9BCBC),
                                    BlendMode.srcIn,
                                  ),
                                ),
                          onPressed: () {
                            setState(() {
                              _confirmacaoVisivel = !_confirmacaoVisivel;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 21.0,
                right: 21.0,
                bottom: 24.0,
                top: 8.0,
              ),
              child: BotaoLargoNhac(
                texto: 'Cadastrar', 
                onPressed: _senhaValida ? () => cadastrar() : null, 
                carregando: _isLoading,
              ),
            ),
            ],
        ),
      ),
    );
  }
  
  Future<void> cadastrar() async {
    final localContext = context;
    try {
      setState(() => _isLoading = true);

      final authService = localContext.read<AuthService>();
      final cadastroData = localContext.read<CadastroController>();

      await authService.registrar(
        nome: cadastroData.nome,
        email: cadastroData.email,
        telefone: cadastroData.telefone,
        senha: _senhaController.text,
      );

      if (!localContext.mounted) return;

      cadastroData.limparDados();
      localContext.showSuccess("Conta criada com sucesso!");
      localContext.go('/home-page');

        } catch (e) {
      if (!localContext.mounted) return;
      final mensagem = e.toString().replaceAll('Exception: ', '');
      // Janela de 30 min do código de cadastro expirou: reenvia e volta pra
      // tela de código em vez de deixar o usuário travado no fim do fluxo.
      if (mensagem.toLowerCase().contains('não verificado')) {
        final email = localContext.read<CadastroController>().email;
        try {
          await localContext.read<AuthService>().enviarCodigoCadastro(email);
          if (!localContext.mounted) return;
          localContext.showError('Seu código expirou. Enviamos um novo para $email.');
          localContext.push('/cadastro/verificar-email', extra: email);
          return;
        } catch (_) {
          // cai no showError genérico abaixo
        }
      }
      localContext.showError(mensagem);
    } finally {
      if (localContext.mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
