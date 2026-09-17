// lib/pages/chat_loja_page.dart
//
// Chat do cliente com a loja. Abre (ou recupera) a conversa, carrega o
// histórico por REST e depois fica ouvindo o WebSocket.
//
// O modelo do backend é conversa contínua por (loja, cliente) — não é uma
// conversa por pedido. Então a mesma tela serve pra falar da loja em geral
// ou de um pedido específico.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nhac/globals/ui_utils.dart';
import 'package:nhac/models/chat/mensagem_chat.dart';
import 'package:nhac/repositories/chat_repository.dart';
import 'package:nhac/services/chat_socket_service.dart';

class ChatLojaPage extends StatefulWidget {
  final String lojaId;
  final String lojaNome;

  const ChatLojaPage({super.key, required this.lojaId, required this.lojaNome});

  @override
  State<ChatLojaPage> createState() => _ChatLojaPageState();
}

class _ChatLojaPageState extends State<ChatLojaPage> {
  final _repository = ChatRepository();
  final _socket = ChatSocketService();
  final _campoController = TextEditingController();
  final _scrollController = ScrollController();

  final List<MensagemChat> _mensagens = [];
  final List<StreamSubscription> _inscricoes = [];

  String? _conversaId;
  bool _carregando = true;
  bool _conectado = false;
  String? _erroFatal;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      final conversaId = await _repository.abrirConversaComLoja(widget.lojaId);
      final historico = await _repository.historico(conversaId);

      if (!mounted) return;
      setState(() {
        _conversaId = conversaId;
        _mensagens
          ..clear()
          ..addAll(historico);
        _carregando = false;
      });

      _repository.marcarComoLida(conversaId);

      _inscricoes.add(_socket.mensagens.listen(_aoReceberMensagem));
      _inscricoes.add(_socket.conectado.listen((valor) {
        if (mounted) setState(() => _conectado = valor);
      }));
      _inscricoes.add(_socket.erros.listen((mensagem) {
        if (mounted) context.showError(mensagem);
      }));

      await _socket.conectar(conversaId);
      _irParaOFim();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erroFatal = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _aoReceberMensagem(MensagemChat mensagem) {
    if (!mounted) return;
    // O id vem do backend, então dá pra deduplicar se o socket reconectar e
    // reentregar algo que já está na lista.
    if (_mensagens.any((m) => m.id == mensagem.id)) return;
    setState(() => _mensagens.add(mensagem));
    if (!mensagem.isDoCliente && _conversaId != null) {
      _repository.marcarComoLida(_conversaId!);
    }
    _irParaOFim();
  }

  void _irParaOFim() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _enviar() {
    final texto = _campoController.text.trim();
    if (texto.isEmpty) return;
    final enviou = _socket.enviar(texto);
    if (!enviou) {
      context.showError('Sem conexão com o chat. Tentando reconectar...');
      return;
    }
    _campoController.clear();
  }

  @override
  void dispose() {
    for (final inscricao in _inscricoes) {
      inscricao.cancel();
    }
    _socket.dispose();
    _campoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF5D201C)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.lojaNome,
              style: const TextStyle(
                color: Color(0xFF5D201C),
                fontSize: 17.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _conectado ? 'online' : 'conectando...',
              style: TextStyle(
                color: _conectado ? const Color(0xFF3BA55D) : Colors.grey,
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(child: _corpo()),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6961)),
      );
    }

    if (_erroFatal != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline,
                  size: 48.0, color: Color(0xFFC9BCBC)),
              const SizedBox(height: 16.0),
              Text(
                _erroFatal!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF5D201C), fontSize: 15.0),
              ),
              const SizedBox(height: 16.0),
              TextButton(
                onPressed: () {
                  setState(() {
                    _carregando = true;
                    _erroFatal = null;
                  });
                  _iniciar();
                },
                child: const Text('Tentar novamente',
                    style: TextStyle(color: Color(0xFFFF6961))),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _mensagens.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'Ainda não há mensagens.\nMande a primeira para a loja.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8A8A8A), fontSize: 15.0),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  itemCount: _mensagens.length,
                  itemBuilder: (context, index) =>
                      _balao(_mensagens[index]),
                ),
        ),
        _barraDeEnvio(),
      ],
    );
  }

  Widget _balao(MensagemChat mensagem) {
    final doCliente = mensagem.isDoCliente;
    return Align(
      alignment: doCliente ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 10.0),
        padding:
            const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: doCliente ? const Color(0xFFFF6961) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16.0),
            topRight: const Radius.circular(16.0),
            bottomLeft: Radius.circular(doCliente ? 16.0 : 4.0),
            bottomRight: Radius.circular(doCliente ? 4.0 : 16.0),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 4.0,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              doCliente ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              mensagem.conteudo,
              style: TextStyle(
                color: doCliente ? Colors.white : const Color(0xFF5D201C),
                fontSize: 15.0,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              DateFormat('HH:mm').format(mensagem.enviadaEm),
              style: TextStyle(
                color: doCliente ? const Color(0xCCFFFFFF) : Colors.grey,
                fontSize: 11.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barraDeEnvio() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 12.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x0F000000), blurRadius: 6.0),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _campoController,
              minLines: 1,
              maxLines: 4,
              maxLength: 4000, // mesmo limite do EnviarMensagemDTO
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _enviar(),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Escreva sua mensagem...',
                hintStyle: const TextStyle(color: Color(0xFFB9ADAD)),
                filled: true,
                fillColor: const Color(0x33C9BCBC),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          Material(
            color: const Color(0xFFFF6961),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _enviar,
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Icon(Icons.send_rounded, color: Colors.white, size: 22.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

