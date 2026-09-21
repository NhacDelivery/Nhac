import 'package:nhac/components/seta_voltar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nhac/components/botoes/botao_largo_nhac.dart';
import 'package:nhac/controllers/cadastro_controller.dart';
import 'package:nhac/controllers/user_provider.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:nhac/globals/ui_utils.dart';
import 'package:nhac/e2e/e2e_keys.dart';

@NowaGenerated()
class ContinuarSenha extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const ContinuarSenha({super.key});

  @override
  State<ContinuarSenha> createState() {
    return _ContinuarSenhaState();
  }
}

@NowaGenerated()
class _ContinuarSenhaState extends State<ContinuarSenha> {
  bool _senhaValida = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _senhaVisivel = false;

  final TextEditingController _senhaController = TextEditingController();

  void _verificarSenha() {
    if (!mounted) {
      return;
    }
    setState(() {
      _senhaValida = _senhaController.text.isNotEmpty;
      if (_errorMessage != null) {
        _errorMessage = null;
      }
    });
  }

  @override
  void dispose() {
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> logar() async {
    final localContext = context;
    try {
      setState(() => _isLoading = true);

      final authService = localContext.read<AuthService>();
      final cadastroData = localContext.read<CadastroController>();

      await authService.login(
        email: cadastroData.email,
        senha: _senhaController.text.trim()
      );
      
      if (!localContext.mounted) return;

      localContext.read<UserProvider>().carregarDadosUsuario();
      cadastroData.limparDados();
      
      localContext.showSuccess("Logado com sucesso!");
      localContext.go('/home-page'); 

    } catch (e) {
      if (!localContext.mounted) return;
      
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      
      localContext.showError(e.toString());
    } finally {
      if (localContext.mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        'Bem-vindo Novamente!\nInsira sua senha',
                        style: TextStyle(
                          fontSize: 28.0,
                          color: Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      SizedBox(
                        width: double.infinity,
                        child: TextFormField(
                          key: E2EKeys.loginPassword,
                          enabled: true,
                          autofocus: true,
                          showCursor: true,
                          obscureText: !_senhaVisivel,
                          obscuringCharacter: '⬤',
                          cursorColor: const Color(0xFFFF6961),
                          style: TextStyle(
                            color: const Color(0xFF5D201C),
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w600,
                            letterSpacing: _senhaVisivel ? 0.0 : 4.0,
                          ),
                          decoration: InputDecoration(
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: _errorMessage != null
                                    ? Colors.red
                                    : Colors.grey,
                                width: 1.0,
                              ),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: _errorMessage != null
                                    ? Colors.red
                                    : const Color(0xFFC9BCBC),
                                width: 2.0,
                              ),
                            ),
                            hintText: 'Senha',
                            hintStyle: const TextStyle(
                              color: Color(0xFFC9BCBC),
                              letterSpacing: 0.0,
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
                          controller: _senhaController, 
                          onChanged: (value) => _verificarSenha(),
                        ),
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(
                        height: 50.0,
                        width: double.infinity,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Semantics(
                            button: true,
                            label: 'Toque para recuperar sua senha',
                            child: GestureDetector(
                              onTap: () {
                                context.push('/recuperacao/input', extra: 'email');
                              },
                              child: const Text(
                                'Esqueceu sua senha?',
                                style: TextStyle(
                                  fontSize: 14.0,
                                  color: Color(0xFFFF6961),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 40.0,
                        width: double.infinity,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Semantics(
                            button: true,
                            label: 'Toque para criar uma conta',
                            child: GestureDetector(
                              onTap: () {
                                context.push('/cadastro/nome');
                              },
                              child: const Text(
                                'Não tem conta? Criar conta',
                                style: TextStyle(
                                  fontSize: 14.0,
                                  color: Color(0xFF5D201C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24.0),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
              padding: const EdgeInsets.only(left: 21.0, right: 21.0, bottom: 24.0, top: 8.0),
              child: BotaoLargoNhac(
                key: E2EKeys.loginSubmit,
                texto: 'Continuar',
                onPressed: _senhaValida ? () => logar() : null,
                carregando: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
