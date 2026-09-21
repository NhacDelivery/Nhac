import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/components/botoes/botao_largo_nhac.dart';
import 'package:nhac/components/seta_voltar.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:nhac/globals/ui_utils.dart';

class NovaSenhaRecuperacaoPage extends StatefulWidget {
  final String metodo;
  final String contato;
  final String codigo;

  const NovaSenhaRecuperacaoPage({
    super.key,
    required this.metodo,
    required this.contato,
    required this.codigo,
  });

  @override
  State<NovaSenhaRecuperacaoPage> createState() => _NovaSenhaRecuperacaoPageState();
}

class _NovaSenhaRecuperacaoPageState extends State<NovaSenhaRecuperacaoPage> {
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmaController = TextEditingController();
  bool _valido = false;
  String? _erro;
  bool _isLoading = false;
  bool _senhaVisivel = false;
  bool _confirmaVisivel = false;

  @override
  void initState() {
    super.initState();
    _senhaController.addListener(_verificarSenhas);
    _confirmaController.addListener(_verificarSenhas);
  }

  void _verificarSenhas() {
    if (!mounted) return;
    final senha = _senhaController.text;
    final confirma = _confirmaController.text;
    String? erroTemp;
    
    if (senha.length < 6) {
      erroTemp = 'A senha deve ter no mínimo 6 caracteres';
    } else if (senha != confirma && confirma.isNotEmpty) {
      erroTemp = 'As senhas não coincidem';
    }

    setState(() {
      _erro = erroTemp;
      _valido = erroTemp == null && senha.isNotEmpty && confirma.isNotEmpty && senha == confirma;
    });
  }

  @override
  void dispose() {
    _senhaController.removeListener(_verificarSenhas);
    _confirmaController.removeListener(_verificarSenhas);
    _senhaController.dispose();
    _confirmaController.dispose();
    super.dispose();
  }

  Future<void> _redefinirSenha() async {
    final authService = context.read<AuthService>();
    setState(() => _isLoading = true);

    try {
      await authService.redefinirSenhaEmail(
        widget.contato,
        widget.codigo,
        _senhaController.text,
      );

      if (!mounted) return;
      context.showSuccess("Senha redefinida com sucesso! Faça login.");
      context.go('/bem-vindo');
    } catch (e) {
      if (!mounted) return;
      context.showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPasswordField(String label, TextEditingController controller, bool visivel, VoidCallback toggle) {
    return TextFormField(
      controller: controller,
      obscureText: !visivel,
      style: const TextStyle(
        fontSize: 18.0,
        color: Color(0xFF5D201C),
        fontWeight: FontWeight.w500,
        letterSpacing: 2.0,
      ),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon: Icon(visivel ? Icons.visibility : Icons.visibility_off, color: const Color(0xFFFF6961)),
          onPressed: toggle,
        ),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6961), width: 2)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      const Text(
                        'Nova Senha',
                        style: TextStyle(
                          fontSize: 28.0,
                          color: Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      const Text(
                        'Crie uma nova senha segura para sua conta.',
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Color(0xFFC9BCBC),
                          fontFamily: 'Roboto',
                        ),
                      ),
                      const SizedBox(height: 32.0),
                      _buildPasswordField('Nova Senha', _senhaController, _senhaVisivel, () => setState(() => _senhaVisivel = !_senhaVisivel)),
                      const SizedBox(height: 16.0),
                      _buildPasswordField('Confirmar Nova Senha', _confirmaController, _confirmaVisivel, () => setState(() => _confirmaVisivel = !_confirmaVisivel)),
                      if (_erro != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Text(_erro!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                        ),
                    ],
                  ),
                ),
              ),
              BotaoLargoNhac(
                texto: 'Redefinir Senha',
                onPressed: _valido ? _redefinirSenha : null,
                carregando: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
