import 'package:flutter/material.dart';
import 'package:nhac/components/botoes/botao_largo_nhac.dart';
import 'package:nhac/components/seta_voltar.dart';
import 'package:nhac/controllers/cadastro_controller.dart';
import 'package:nhac/controllers/user_provider.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:nhac/globals/ui_utils.dart';

import 'package:nhac/components/nhac_input_field.dart';

import 'package:nhac/utils/validators.dart';

@NowaGenerated()
class Nome extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const Nome({super.key});

  @override
  State<Nome> createState() {
    return _NomeState();
  }
}

@NowaGenerated()
class _NomeState extends State<Nome> {
  bool _nomeValido = false;
  final bool  _isLoading = false;
  String? _erroNome;

  final TextEditingController _nomeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nomeController.addListener(_verificarNome);
  }

  void _verificarNome() {
    if (!mounted) return;
    final texto = _nomeController.text;
    String? erroTemp = Validators.validarNome(texto);

    setState(() {
      _erroNome = erroTemp;
      _nomeValido = erroTemp == null && texto.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _nomeController.removeListener(_verificarNome);
    _nomeController.dispose();
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
                    horizontal: 24.0, 
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SetaVoltar(),
                      const SizedBox(height: 24.0),  
                      const Text(
                        'Qual o seu nome?',
                        style: TextStyle(
                          fontSize: 28.0,
                          color: Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      NhacInputField(
                        controller: _nomeController,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        hintText: 'Nome',
                        errorText: _erroNome,
                        validator: Validators.validarNome,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            Padding( 
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0, top: 8.0),
              child: BotaoLargoNhac(
                texto: 'Continuar',
                carregando: _isLoading,
                        onPressed: _nomeValido
                    ? () async {
                        final localContext = context;
                        final cadastroData = localContext.read<CadastroController>();
                        final authService = localContext.read<AuthService>();
                        final novoNome = _nomeController.text.trim();
                        cadastroData.setNome(novoNome);

                        if (authService.isAuthenticated) {
                     
                          try {
                            await authService.updateUserName(userName: novoNome);
                            if (localContext.mounted) {
                              localContext.read<UserProvider>().carregarDadosUsuario();
                              localContext.go('/home-page');
                            }
                          } catch (e) {
                            if (localContext.mounted) {
                              localContext.showError(e.toString());
                            }
                          }
                        } else if (cadastroData.email.isNotEmpty) {
                          localContext.push('/cadastro/telefone');
                        } else {
                          if (localContext.mounted) {
                            localContext.showError('Usuário não autenticado.');
                          }
                        }
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
