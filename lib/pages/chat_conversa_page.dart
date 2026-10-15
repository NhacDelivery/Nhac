// lib/pages/chat_loja_page.dart
//
// Fluxo compartilhado de conversa com loja ou pessoa. O histórico e o
// fallback de envio usam REST; o WebSocket atualiza a mesma conversa.
//
// O modelo do backend é conversa contínua por (loja, cliente) — não é uma
// conversa por pedido. Então a mesma tela serve pra falar da loja em geral
// ou de um pedido específico.

import 'dart:async';
import 'package:nhac/components/estado_com_retry.dart';
import 'package:nhac/services/session_storage_service.dart';
import 'package:nhac/utils/error_ui_helper.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/chat/pedido_chat_referencia.dart';
import 'package:nhac/models/chat/produto_chat_referencia.dart';

import 'package:flutter/material.dart';
import 'package:nhac/components/loading_nhac.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:nhac/globals/ui_utils.dart';
import 'package:nhac/models/chat/mensagem_chat.dart';
import 'package:nhac/repositories/chat_repository.dart';
import 'package:nhac/services/chat_socket_service.dart';
import 'package:nhac/models/produto/produtos.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatConversaPage extends StatefulWidget {
  final String? lojaId;
  final String? conversaId;
  final String? usuarioId;
  final bool conversaPessoa;
  final String interlocutorNome;
  final ProdutosModel? produtoReferencia;
  final PedidoChatReferencia? pedidoReferencia;
  final ChatRepository? repository;
  final ChatSocketService? socket;

  const ChatConversaPage({
    super.key,
    this.lojaId,
    this.conversaId,
    this.usuarioId,
    this.conversaPessoa = false,
    required this.interlocutorNome,
    this.produtoReferencia,
    this.pedidoReferencia,
    this.repository,
    this.socket,
  });

  @override
  State<ChatConversaPage> createState() => _ChatConversaPageState();
}

class _ChatConversaPageState extends State<ChatConversaPage>
    with WidgetsBindingObserver {
  late final _repository = widget.repository ?? ChatRepository();
  late final _socket = widget.socket ?? ChatSocketService();
  final _campoController = TextEditingController();
  final _scrollController = ScrollController();

  final List<MensagemChat> _mensagens = [];
  final List<StreamSubscription> _inscricoes = [];

  String? _conversaId;
  bool _carregando = true;
  bool _conectado = false;
  String? _erroFatal;
  String? _pendenteId;
  String? _pendenteTexto;
  bool _pendenteComReferencia = false;
  bool _referenciaEnviada = false;
  bool _envioIncerto = false;
  int _paginaHistorico = 0;
  bool _temMensagensAntigas = true;
  bool _carregandoAntigas = false;
  Timer? _prazoConfirmacao;
  Timer? _polling;
  String? _usuarioId;
  String? _erroAtualizacao;
  bool _inicializando = false;
  bool _atualizando = false;
  bool _enviandoRest = false;
  bool _reconectando = false;
  bool _ativo = true;

  bool _minhaMensagem(MensagemChat mensagem) => widget.conversaPessoa
      ? mensagem.remetenteUsuarioId != null &&
          mensagem.remetenteUsuarioId == _usuarioId
      : mensagem.isDoCliente;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _campoController.addListener(() {
      if (mounted) setState(() {});
    });
    _iniciar();
  }

  Future<void> _iniciar() async {
    if (_inicializando) return;
    _inicializando = true;
    try {
      if (widget.conversaPessoa) {
        _usuarioId =
            widget.usuarioId ?? await SessionStorageService().obterUsuarioId();
        if (_usuarioId == null || _usuarioId!.isEmpty) {
          throw AuthException(
              'Sessão expirada. Entre novamente para conversar.');
        }
      }
      final conversaId = widget.conversaId ??
          (widget.lojaId?.isNotEmpty == true
              ? await _repository.abrirConversaComLoja(widget.lojaId!)
              : throw AppException('Esta conversa não está disponível.'));
      if (conversaId.isEmpty)
        throw AppException('Esta conversa não está disponível.');
      final historico = await _repository.historico(conversaId);

      if (!mounted) return;
      setState(() {
        _conversaId = conversaId;
        _mensagens
          ..clear()
          ..addAll(historico);
        _paginaHistorico = 1;
        _temMensagensAntigas = historico.length == 30;
        _carregando = false;
      });

      _repository.marcarComoLida(conversaId);

      if (_inscricoes.isEmpty) {
        _inscricoes.add(_socket.mensagens.listen(_aoReceberMensagem));
        _inscricoes.add(
          _socket.conectado.listen((valor) {
            if (!mounted) return;
            setState(() => _conectado = valor);
            _configurarPolling();
            if (valor) _atualizarHistorico(conversaId);
          }),
        );
        _inscricoes.add(
          _socket.erros.listen((mensagem) {
            if (mounted) {
              if (_pendenteId != null) setState(() => _envioIncerto = true);
              setState(() => _erroAtualizacao = mensagem);
            }
          }),
        );
      }
      try {
        await _socket.conectar(conversaId);
      } catch (_) {
        if (mounted)
          setState(() => _erroAtualizacao =
              'O chat está sem atualização em tempo real. Você pode tentar reconectar.');
      }
      _configurarPolling();
      _irParaOFim();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erroFatal = ErrorUIHelper.mensagem(e,
            fallback: 'Não foi possível abrir a conversa. Tente novamente.');
      });
    } finally {
      _inicializando = false;
    }
  }

  void _aoReceberMensagem(MensagemChat mensagem) {
    if (!mounted || mensagem.conversaId != _conversaId) return;
    _confirmarSePendente(mensagem);
    // O id vem do backend, então dá pra deduplicar se o socket reconectar e
    // reentregar algo que já está na lista.
    if (_mensagens.any((m) => m.id == mensagem.id)) return;
    setState(() => _mensagens.add(mensagem));
    if (!_minhaMensagem(mensagem) && _conversaId != null) {
      _repository.marcarComoLida(_conversaId!);
    }
    _irParaOFim();
  }

  void _confirmarSePendente(MensagemChat mensagem) {
    if (_pendenteId == null || mensagem.id != 'msg_$_pendenteId') return;
    _prazoConfirmacao?.cancel();
    _campoController.clear();
    setState(() {
      if (_pendenteComReferencia) _referenciaEnviada = true;
      _pendenteComReferencia = false;
      _pendenteId = null;
      _pendenteTexto = null;
      _envioIncerto = false;
    });
  }

  Future<void> _atualizarHistorico(String conversaId) async {
    if (_atualizando || !_ativo) return;
    _atualizando = true;
    try {
      final historico = await _repository.historico(conversaId);
      if (!mounted || _conversaId != conversaId) return;
      for (final mensagem in historico) {
        _confirmarSePendente(mensagem);
      }
      final ids = _mensagens.map((m) => m.id).toSet();
      setState(() {
        _erroAtualizacao = null;
        for (final mensagem in historico) {
          if (ids.add(mensagem.id)) _mensagens.add(mensagem);
        }
        _mensagens.sort((a, b) => a.enviadaEm.compareTo(b.enviadaEm));
      });
    } catch (e) {
      if (mounted) setState(() => _erroAtualizacao = ErrorUIHelper.mensagem(e));
    } finally {
      _atualizando = false;
    }
  }

  Future<void> _carregarMensagensAntigas() async {
    final id = _conversaId;
    if (id == null || !_temMensagensAntigas || _carregandoAntigas) return;
    setState(() => _carregandoAntigas = true);
    try {
      final anteriores = await _repository.historico(
        id,
        pagina: _paginaHistorico,
      );
      if (!mounted || _conversaId != id) return;
      final ids = _mensagens.map((m) => m.id).toSet();
      setState(() {
        _mensagens.insertAll(0, anteriores.where((m) => ids.add(m.id)));
        _paginaHistorico++;
        _temMensagensAntigas = anteriores.length == 30;
      });
    } catch (_) {
      if (mounted)
        context.showError(
          'Não foi possível carregar mensagens antigas. Tente novamente.',
        );
    } finally {
      if (mounted) setState(() => _carregandoAntigas = false);
    }
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

  Future<void> _enviar() async {
    final texto = _campoController.text.trim();
    final produto = widget.produtoReferencia;
    final pedido = widget.pedidoReferencia;
    final anexar = (produto != null || pedido != null) && !_referenciaEnviada;
    if (texto.isEmpty && !anexar && _pendenteId == null) return;
    if (_enviandoRest ||
        _conversaId == null ||
        (_pendenteId != null && !_envioIncerto)) return;
    final id = _pendenteId ?? const Uuid().v4();
    final mensagem = _pendenteTexto ??
        (anexar
            ? (produto != null
                ? ProdutoChatReferencia(
                        nome: produto.nome,
                        id: produto.id,
                        preco: NumberFormat.currency(
                          locale: 'pt_BR',
                          symbol: 'R\$',
                        ).format(produto.preco),
                        imagem: produto.imagemUrl,
                        mensagem: texto)
                    .serializar()
                : pedido!.comMensagem(texto).serializar())
            : texto);
    if (mensagem.length > 4000) {
      context
          .showError('Reduza a mensagem para enviar junto com a referência.');
      return;
    }
    setState(() {
      _pendenteId = id;
      _pendenteTexto = mensagem;
      _pendenteComReferencia = anexar;
      _envioIncerto = false;
      _erroAtualizacao = null;
    });
    _prazoConfirmacao?.cancel();
    if (!_socket.enviar(mensagem, id)) {
      await _enviarPorRest();
      return;
    }
    _prazoConfirmacao = Timer(const Duration(seconds: 15), () {
      if (mounted && _pendenteId == id) _enviarPorRest();
    });
  }

  Future<void> _enviarPorRest() async {
    final id = _pendenteId;
    final texto = _pendenteTexto;
    final conversa = _conversaId;
    if (_enviandoRest || id == null || texto == null || conversa == null)
      return;
    setState(() => _enviandoRest = true);
    try {
      final mensagem = await _repository.enviarMensagem(conversa,
          conteudo: texto, clientMessageId: id);
      if (!mounted || _conversaId != conversa) return;
      _aoReceberMensagem(mensagem);
    } catch (e) {
      if (mounted && _pendenteId == id)
        setState(() {
          _envioIncerto = true;
          _erroAtualizacao = ErrorUIHelper.mensagem(e,
              fallback: 'A mensagem ainda não foi confirmada. Tente reenviar.');
        });
    } finally {
      if (mounted) setState(() => _enviandoRest = false);
    }
  }

  void _configurarPolling() {
    _polling?.cancel();
    if (!_ativo || _conectado || _conversaId == null || !mounted) return;
    _polling = Timer.periodic(
        const Duration(seconds: 15), (_) => _atualizarHistorico(_conversaId!));
  }

  Future<void> _reconectar() async {
    final id = _conversaId;
    if (id == null || _reconectando) return;
    setState(() => _reconectando = true);
    try {
      await _socket.reconectar(id);
      await _atualizarHistorico(id);
    } catch (e) {
      if (mounted) setState(() => _erroAtualizacao = ErrorUIHelper.mensagem(e));
    } finally {
      if (mounted) {
        setState(() => _reconectando = false);
        _configurarPolling();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _ativo = state == AppLifecycleState.resumed;
    if (_ativo) {
      _reconectar();
    } else {
      _polling?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _polling?.cancel();
    _prazoConfirmacao?.cancel();
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
              widget.interlocutorNome,
              style: const TextStyle(
                color: Color(0xFF5D201C),
                fontSize: 17.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _conectado ? 'Conectado ao chat' : 'Atualização por consulta',
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
      return const LoadingNhac(telaCheia: false, tamanho: 120);
    }

    if (_erroFatal != null) {
      return Center(
          child: BannerErroInline(
        mensagem: _erroFatal!,
        aoTentarNovamente: () {
          setState(() {
            _carregando = true;
            _erroFatal = null;
          });
          _iniciar();
        },
      ));
    }

    return LayoutBuilder(
        builder: (context, constraints) => Column(
              children: [
                if (_erroAtualizacao != null || !_conectado)
                  ConstrainedBox(
                    constraints:
                        BoxConstraints(maxHeight: constraints.maxHeight * .25),
                    child: SingleChildScrollView(
                        child: Semantics(
                      liveRegion: true,
                      child: BannerErroInline(
                        mensagem: _erroAtualizacao ??
                            'Sem atualização em tempo real. A conversa continua disponível.',
                        aoTentarNovamente: _reconectando ? null : _reconectar,
                      ),
                    )),
                  ),
                Expanded(
                  child: _mensagens.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              'Ainda não há mensagens.\nEnvie a primeira mensagem.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF8A8A8A),
                                fontSize: 15.0,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          itemCount: _mensagens.length +
                              (_temMensagensAntigas ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_temMensagensAntigas && index == 0) {
                              return TextButton(
                                onPressed: _carregandoAntigas
                                    ? null
                                    : _carregarMensagensAntigas,
                                child: Text(
                                  _carregandoAntigas
                                      ? 'Carregando...'
                                      : 'Ver mensagens anteriores',
                                ),
                              );
                            }
                            return _balao(
                              _mensagens[
                                  index - (_temMensagensAntigas ? 1 : 0)],
                            );
                          },
                        ),
                ),
                ConstrainedBox(
                  constraints:
                      BoxConstraints(maxHeight: constraints.maxHeight * .70),
                  child: SingleChildScrollView(child: _barraDeEnvio()),
                ),
              ],
            ));
  }

  Widget _balao(MensagemChat mensagem) {
    final doCliente = _minhaMensagem(mensagem);
    return Align(
      alignment: doCliente ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 10.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
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
            _conteudoMensagem(mensagem.conteudo, doCliente),
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

  Widget _conteudoMensagem(String conteudo, bool doCliente) {
    // O contexto viaja no texto já persistido pelo backend. Também lê referências antigas.
    final pedidoRef = PedidoChatReferencia.ler(conteudo);
    if (pedidoRef != null) return _cartaoPedido(pedidoRef, doCliente);
    final referencia = ProdutoChatReferencia.ler(conteudo);
    final cor = doCliente ? Colors.white : const Color(0xFF5D201C);
    if (referencia == null)
      return Text(
        conteudo,
        style: TextStyle(color: cor, fontSize: 15, height: 1.3),
      );
    final imagem = referencia.imagem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (imagem != null && Uri.tryParse(imagem)?.scheme == 'https')
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imagem,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      referencia.nome,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D201C),
                      ),
                    ),
                    Text(
                      referencia.preco,
                      style: const TextStyle(color: Color(0xFF5D201C)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (referencia.mensagem.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            referencia.mensagem,
            style: TextStyle(color: cor, fontSize: 15, height: 1.3),
          ),
        ],
      ],
    );
  }

  Widget _cartaoReferenciaPedido(PedidoChatReferencia r) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.receipt_long, color: Color(0xFFFF6961)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pedido ${r.codigo}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D201C),
                    ),
                  ),
                  Text(
                    r.resumo,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF5D201C)),
                  ),
                  Text(
                    r.status == null ? r.total : '${r.total} · ${r.status}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5D201C),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _cartaoPedido(PedidoChatReferencia r, bool doCliente) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cartaoReferenciaPedido(r),
          if (r.mensagem.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              r.mensagem,
              style: TextStyle(
                color: doCliente ? Colors.white : const Color(0xFF5D201C),
                fontSize: 15,
                height: 1.3,
              ),
            ),
          ],
        ],
      );

  Widget _previaPedido(PedidoChatReferencia r) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            _cartaoReferenciaPedido(r),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _referenciaEnviada
                        ? 'Pedido enviado à loja'
                        : 'O pedido será incluído na próxima mensagem',
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF5D201C)),
                  ),
                ),
                if (!_referenciaEnviada)
                  TextButton(
                    onPressed:
                        !_enviandoRest && (_pendenteId == null || _envioIncerto)
                            ? _enviar
                            : null,
                    child: const Text('Enviar pedido à loja'),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _barraDeEnvio() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 12.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 6.0)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.pedidoReferencia case final pedido?) _previaPedido(pedido),
          if (widget.produtoReferencia case final produto?)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (produto.imagemUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: produto.imagemUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              produto.nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              NumberFormat.currency(
                                locale: 'pt_BR',
                                symbol: 'R\$',
                              ).format(produto.preco),
                            ),
                            Text(
                              _referenciaEnviada
                                  ? 'Referência enviada à loja'
                                  : 'Referência incluída na próxima mensagem',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF5D201C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!_referenciaEnviada)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: !_enviandoRest &&
                                (_pendenteId == null || _envioIncerto)
                            ? _enviar
                            : null,
                        child: const Text('Enviar produto à loja'),
                      ),
                    ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _campoController,
                  readOnly: _pendenteId != null,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 4000,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _enviar(),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Escreva sua mensagem...',
                    hintStyle: const TextStyle(color: Color(0xFFB9ADAD)),
                    filled: true,
                    fillColor: const Color(0x33C9BCBC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
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
                child: IconButton(
                  tooltip:
                      _envioIncerto ? 'Reenviar mensagem' : 'Enviar mensagem',
                  onPressed:
                      _enviandoRest || (_pendenteId != null && !_envioIncerto)
                          ? null
                          : _enviar,
                  icon: Icon(
                    _envioIncerto ? Icons.refresh : Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          if (_pendenteId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _envioIncerto
                      ? 'Sem confirmação. Confira a conversa ou toque em enviar para reenviar.'
                      : 'Aguardando confirmação da mensagem...',
                  style: const TextStyle(
                    color: Color(0xFF5D201C),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
