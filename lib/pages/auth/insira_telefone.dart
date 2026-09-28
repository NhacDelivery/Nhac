import 'dart:core';

import 'package:nhac/components/botoes/botao_largo_nhac.dart';
import 'package:nhac/components/seta_voltar.dart';
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/controllers/cadastro_controller.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/globals/ui_utils.dart';

@NowaGenerated()
class InsiraTelefone extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const InsiraTelefone({super.key});

  @override
  State<InsiraTelefone> createState() {
    return _InsiraTelefoneState();
  }
}

@NowaGenerated()
class _InsiraTelefoneState extends State<InsiraTelefone> {
  final TextEditingController _telefoneController = TextEditingController();

  bool _numeroValido = false;
  bool _isLoading = false;

  final maskFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp('[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void initState() {
    super.initState();
    // Limpar estado de cadastro anterior para evitar que dados "sujos"
    // (ex: email de uma tentativa anterior) poluam o fluxo de cadastro por SMS.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CadastroController>().limparDados();
    });
  }

  @override
  void dispose() {
    _telefoneController.dispose();
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
                        'Qual o seu número?',
                        style: TextStyle(
                          fontSize: 28.0,
                          color: Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      
                      TextFormField(
                        controller: _telefoneController,
                        enabled: true,
                        autofocus: true,
                        showCursor: true,
                        cursorColor: const Color(0xFFFF6961),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [maskFormatter],
                        onChanged: (value) {
                          final apenasNumeros = maskFormatter.getUnmaskedText();
                          bool ehValido = false;

                          if (apenasNumeros.length == 11) {
                            final primeiroDigitoDDD = apenasNumeros[0];
                            final digitoNove = apenasNumeros[2];

                            if (primeiroDigitoDDD != '0' && digitoNove == '9') {
                              ehValido = true;
                            }
                          }

                          if (_numeroValido != ehValido) {
                            setState(() {
                              _numeroValido = ehValido;
                            });
                          }
                        },
                        style: const TextStyle(
                          color: Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey, width: 1.0),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFFC9BCBC),
                              width: 2.0,
                            ),
                          ),
                          hintText: '(11) 99999-9999',
                          hintStyle: TextStyle(color: Color(0xFFC9BCBC)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                bottom: 24.0,
                top: 8.0,
              ),
               child: BotaoLargoNhac(
                texto: 'Continuar', 
                carregando: _isLoading,
                 onPressed: _numeroValido
                      ? () async {
                          setState(() {
                            _isLoading = true;
                          });
                          try {
                            await context.read<AuthService>().enviarCodigoSms(_telefoneController.text);
                            if (context.mounted) {
                              context.push('/verificacao_numero', extra: _telefoneController.text);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              context.showError(e.toString());
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
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
