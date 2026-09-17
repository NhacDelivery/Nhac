import 'package:flutter/material.dart';
import 'package:nhac/components/botoes/botao_largo_nhac.dart';
import 'package:nhac/components/seta_voltar.dart';
import 'package:nhac/controllers/cadastro_controller.dart';
import 'package:nhac/controllers/user_provider.dart';
import 'package:nhac/globals/ui_utils.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:nhac/components/nhac_input_field.dart';

import 'package:nhac/utils/validators.dart';

@NowaGenerated()
class EmailCliente extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const EmailCliente({super.key});

  @override
  State<EmailCliente> createState() {
    return _EmailClienteState();
  }
}

@NowaGenerated()
class _EmailClienteState extends State<EmailCliente> {
  final TextEditingController _emailController = TextEditingController();

  bool _emailValido = false;
  String? _erroEmail;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  final List<String> _dominios = [
    '@gmail.com',
    '@hotmail.com',
    '@outlook.com',
    '@yahoo.com.br',
    '@icloud.com',
  ];

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_verificarEmail);
  }

  void _verificarEmail() {
    if (!mounted) return;
    final texto = _emailController.text;
    String? erroTemp = Validators.validarEmail(texto);

    setState(() {
      _erroEmail = erroTemp;
      _emailValido = erroTemp == null && texto.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _emailController.removeListener(_verificarEmail);
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      const Text(
                        'Qual o seu email?',
                        style: TextStyle(
                          fontSize: 28.0,
                          color: Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      const Text(
                        'Precisamos dele para iniciar o seu cadastro ou aceder ao aplicativo.',
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 22.0),
                      NhacInputField(
                        controller: _emailController,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        hintText: 'Email',
                        errorText: _erroEmail,
                        validator: Validators.validarEmail,
                      ),
                      const SizedBox(height: 16.0),
                      SizedBox(
                        height: 40.0,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _dominios.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 10.0),
                          itemBuilder: (context, index) => ActionChip(
                            label: Text(_dominios[index]),
                            backgroundColor:
                                const Color.fromARGB(255, 248, 234, 234),
                            labelStyle: const TextStyle(
                              color: Color(0xFF5D201C),
                              fontWeight: FontWeight.w800,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                              side: const BorderSide(
                                color: Color.fromARGB(255, 248, 234, 234),
                                width: 1.0,
                              ),
                            ),
                            onPressed: () {
                              final textoAtual = _emailController.text.trim();
                              final indexArroba = textoAtual.indexOf('@');
                              final prefixo = indexArroba != -1
                                  ? textoAtual.substring(0, indexArroba)
                                  : textoAtual;
                              if (prefixo.isNotEmpty) {
                                _emailController.text =
                                    '$prefixo${_dominios[index]}';
                                _emailController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(
                                      offset: _emailController.text.length),
                                );
                              }
                            },
                          ),
                          physics: const BouncingScrollPhysics(),
                        ),
                      ),
                      const SizedBox(height: 22.0),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Divider(
                                color: Colors.grey[300], thickness: 1.0),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10.0),
                            child: Text(
                              'ou',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                                color: Colors.grey[300], thickness: 1.0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22.0),
                      BotaoLargoNhac(
                        texto: 'Continuar com o Google',
                        isSecundario: true,
                        carregando: _isGoogleLoading,
                        icone: SvgPicture.asset(
                          'assets/google-logo.svg',
                          height: 24.0,
                          width: 24.0,
                        ),
                        onPressed: () async {
                          setState(() => _isGoogleLoading = true);
                          try {
                            final authService = context.read<AuthService>();
                            await authService.loginComGoogle();

                            if (context.mounted) {
                              context
                                  .read<UserProvider>()
                                  .carregarDadosUsuario();
                              context.showSuccess("Logado com sucesso!");
                              context.go('/home-page');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              context.showError(e.toString());
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isGoogleLoading = false);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 16.0),
                      BotaoLargoNhac(
                        texto: 'Continuar com o telefone',
                        isSecundario: true,
                        icone: const Icon(Icons.phone,
                            size: 24.0, color: Color(0xFF5D201C)),
                        onPressed: () {
                          context.push('/insira_telefone');
                        },
                      ),
                    ],
                  ),
                ),
              ),
              BotaoLargoNhac(
                texto: 'Continuar',
                carregando: _isLoading,
                onPressed: _emailValido
                    ? () async {
                        await redirecionadorEmail();
                      }
                    : null,
              ),
              const SizedBox(height: 16.0),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> redirecionadorEmail() async {
    final localContext = context;
    final cadastroData = localContext.read<CadastroController>();
    final authService = localContext.read<AuthService>();

    final emailDoUsuario = _emailController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      final existe = await authService.checarEmail(emailDoUsuario);

      if (!localContext.mounted) return;
      cadastroData.setEmail(emailDoUsuario);

      if (existe) {
        localContext.push('/continuar_senha');
      } else {
        // O backend exige e-mail confirmado por código antes do /auth/registrar.
        await authService.enviarCodigoCadastro(emailDoUsuario);
        if (!localContext.mounted) return;
        localContext.push('/cadastro/verificar-email', extra: emailDoUsuario);
      }
    } catch (e) {
      if (localContext.mounted) {
        localContext.showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
