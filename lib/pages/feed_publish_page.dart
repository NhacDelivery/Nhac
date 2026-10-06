import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/utils/request_outcome.dart';
import 'package:nhac/components/nhac_confirm_dialog.dart';
import 'package:provider/provider.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/feed_tentativa_service.dart';

import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nhac/models/loja/lojas.dart';
import 'package:nhac/repositories/feed_repository.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:nhac/services/image_upload_service.dart';

class FeedPublishPage extends StatefulWidget {
  final FeedPostModel? post;
  final FeedRepository? repository;
  final LojaRepository? lojaRepository;
  final ImageUploadService? uploadService;
  const FeedPublishPage({
    super.key,
    this.repository,
    this.post,
    this.lojaRepository,
    this.uploadService,
  });

  @override
  State<FeedPublishPage> createState() => _FeedPublishPageState();
}

class _FotoPublicacao {
  final XFile? arquivo;
  final Uint8List? bytes;
  String? url;
  _FotoPublicacao(this.arquivo, this.bytes, {this.url});
}

class _FeedPublishPageState extends State<FeedPublishPage> {
  final _form = GlobalKey<FormState>();
  final _conteudo = TextEditingController();
  final _tags = TextEditingController();
  final _busca = TextEditingController();
  final _focoConteudo = FocusNode();
  final _fotos = <_FotoPublicacao>[];
  late final _repository = widget.repository ?? FeedRepository();
  late final _lojasRepository = widget.lojaRepository ?? LojaRepository();
  late final _upload = widget.uploadService ?? ImageUploadService();
  List<LojasModel> _lojas = [];
  LojasModel? _loja;
  String? _lojaRestauradaId, _lojaRestauradaNome;
  String? get _lojaId => _loja?.id ?? _lojaRestauradaId;
  bool _enviando = false;
  bool _selecionandoFoto = false;
  bool _buscando = false;
  bool _buscou = false;
  bool _podeSair = false;
  int _consulta = 0;
  String? _erro;
  String? _erroBusca;
  String? _progresso;

  final _tentativas = const FeedTentativaService();
  Map<String, dynamic>? _pendente;
  bool _restaurando = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restaurar());
  }

  Future<void> _restaurar() async {
    try {
      final uid = context.read<AuthService>().usuarioId;
      if (widget.post != null) {
        _conteudo.text = widget.post!.conteudo;
        _tags.text = widget.post!.hashTags.join(' ');
        _fotos.addAll(
          widget.post!.imagens.map(
            (url) => _FotoPublicacao(null, null, url: url),
          ),
        );
        _lojaRestauradaId = widget.post!.mentionedStore?.id;
        _lojaRestauradaNome = widget.post!.mentionedStore?.nome;
      }
      if (uid != null && widget.post == null)
        _pendente = await _tentativas.carregar(uid, 'post');
      if (!mounted) return;
      if (_pendente != null) {
        _conteudo.text = _pendente!['payload']['conteudo'] as String;
        _tags.text = (_pendente!['payload']['hashTags'] as List).join(' ');
        _fotos.addAll(
          (_pendente!['payload']['imagens'] as List).map(
            (url) => _FotoPublicacao(null, null, url: url as String),
          ),
        );
        _lojaRestauradaId = _pendente!['payload']['lojaId'] as String?;
        if (_lojaRestauradaId != null) {
          try {
            final loja = await _lojasRepository.buscarLoja(_lojaRestauradaId!);
            _lojaRestauradaNome = loja?.nome;
          } catch (_) {}
        }
      }
    } catch (_) {
      if (mounted) _erro = 'Não foi possível recuperar o envio anterior. Reabra a tela para tentar novamente.';
    } finally {
      if (mounted) setState(() => _restaurando = false);
    }
  }

  bool get _ocupado => _enviando || _selecionandoFoto || _restaurando;
  bool get _alterado {
    final original = widget.post;
    if (original == null)
      return _conteudo.text.isNotEmpty ||
          _tags.text.isNotEmpty ||
          _fotos.isNotEmpty ||
          _lojaId != null;
    return _conteudo.text != original.conteudo ||
        !listEquals(_hashtags, original.hashTags) ||
        _lojaId != original.mentionedStore?.id ||
        !listEquals(_fotos.map((f) => f.url).toList(), original.imagens);
  }

  List<String> get _hashtags => _tags.text
      .trim()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toSet()
      .toList();

  @override
  void dispose() {
    _conteudo.dispose();
    _tags.dispose();
    _busca.dispose();
    _focoConteudo.dispose();
    super.dispose();
  }

  Future<void> _sair() async {
    if (_ocupado) return;
    final descartar =
        !_alterado ||
        await confirmarNhac(
          context,
          titulo: widget.post == null
              ? 'Descartar publicação?'
              : 'Descartar alterações?',
          mensagem: _pendente != null
              ? 'O envio sem confirmação será preservado para conferir o resultado ao reabrir.'
              : 'As alterações que ainda não foram enviadas serão descartadas.',
          confirmar: 'Descartar',
          cancelar: 'Continuar editando',
        );
    if (!mounted || !descartar) return;
    setState(() => _podeSair = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  Future<void> _adicionarFoto() async {
    if (_ocupado || _fotos.length >= 6) return;
    setState(() {
      _selecionandoFoto = true;
      _erro = null;
    });
    try {
      final arquivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (arquivo == null) return;
      final tamanho = await arquivo.length();
      if (tamanho == 0 || tamanho > 5 * 1024 * 1024) {
        if (mounted) setState(() => _erro = 'Escolha uma foto com até 5 MB.');
        return;
      }
      final bytes = await arquivo.readAsBytes();
      if (mounted) setState(() => _fotos.add(_FotoPublicacao(arquivo, bytes)));
    } catch (_) {
      if (mounted)
        setState(
          () =>
              _erro = 'Não foi possível abrir a foto. Tente selecionar outra.',
        );
    } finally {
      if (mounted) setState(() => _selecionandoFoto = false);
    }
  }

  Future<void> _buscarLoja() async {
    if (_ocupado ||
        _pendente != null ||
        _buscando ||
        _busca.text.trim().isEmpty)
      return;
    final consulta = ++_consulta;
    setState(() {
      _buscando = true;
      _erroBusca = null;
      _lojas = [];
      _buscou = false;
    });
    try {
      final lojas = await _lojasRepository.buscarLojasPorNome(_busca.text);
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _lojas = lojas;
        _buscou = true;
      });
    } catch (_) {
      if (mounted && consulta == _consulta)
        setState(
          () =>
              _erroBusca = 'Não foi possível buscar as lojas. Tente novamente.',
        );
    } finally {
      if (mounted && consulta == _consulta) setState(() => _buscando = false);
    }
  }

  Future<void> _publicar() async {
    if (_ocupado) return;
    if (!_form.currentState!.validate()) {
      _focoConteudo.requestFocus();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      for (var i = 0; i < _fotos.length; i++) {
        setState(
          () => _progresso = 'Enviando foto ${i + 1} de ${_fotos.length}',
        );
        // Reutiliza uploads confirmados quando a publicação falha.
        _fotos[i].url ??= await _upload.enviar(_fotos[i].arquivo!);
        if (!mounted) return;
      }
      setState(() => _progresso = 'Publicando...');
      final uid = context.read<AuthService>().usuarioId;
      if (uid == null) throw StateError('Faça login para publicar.');
      if (widget.post != null) {
        final post = await _repository.editar(
          widget.post!,
          _conteudo.text,
          _hashtags,
          imagens: _fotos.map((f) => f.url!).toList(),
          lojaId: _lojaId,
          alterarLoja: true,
        );
        if (!mounted) return;
        setState(() => _podeSair = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.pop(post);
        });
        return;
      }
      _pendente ??= await _tentativas.preparar(uid, 'post', {
        'conteudo': _conteudo.text.trim(),
        'imagens': _fotos.map((f) => f.url!).toList(),
        'hashTags': _hashtags,
        'lojaId': _lojaId,
      });
      final payload = _pendente!['payload'] as Map;
      final post = await _repository.criarPost(
        conteudo: payload['conteudo'] as String,
        imagens: List<String>.from(payload['imagens'] as List),
        hashTags: List<String>.from(payload['hashTags'] as List),
        lojaId: payload['lojaId'] as String?,
        idempotencyKey: _pendente!['key'] as String,
      );
      await _tentativas.concluir(uid, 'post');
      if (!mounted) return;
      setState(() => _podeSair = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop(post);
      });
    } catch (e) {
      if (rejeicaoDefinitiva(e)) {
        final uid = context.read<AuthService>().usuarioId;
        if (uid != null && widget.post == null)
          await _tentativas.concluir(uid, 'post');
        _pendente = null;
      }
      if (mounted)
        setState(
          () => _erro = rejeicaoDefinitiva(e)
              ? 'O servidor rejeitou o envio. Corrija o conteúdo e tente novamente. $e'
              : 'Não foi possível confirmar a publicação. Seu conteúdo foi preservado. Toque em Confirmar envio anterior para verificar o resultado.',
        );
    } finally {
      if (mounted)
        setState(() {
          _enviando = false;
          _progresso = null;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _podeSair,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _sair();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Voltar',
            onPressed: _ocupado ? null : _sair,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            widget.post == null ? 'Nova publicação' : 'Editar publicação',
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF5D201C),
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_pendente != null)
                  const Text(
                    'Há um envio sem confirmação. Confirme o resultado antes de criar outra publicação.',
                  ),
                Text(
                  'O que deu vontade de compartilhar?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Conte sua experiência e mostre seu pedido para a comunidade Nhac.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('feed.publish.conteudo'),
                  controller: _conteudo,
                  focusNode: _focoConteudo,
                  enabled: !_ocupado && _pendente == null,
                  minLines: 5,
                  maxLines: 10,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                    labelText: 'Sua publicação',
                    hintText: 'Meu pedido de hoje...',
                    filled: true,
                    fillColor: Color(0xFFFFF6F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Escreva algo para publicar.'
                      : null,
                ),
                const SizedBox(height: 12),
                if (_fotos.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _fotos.length; i++)
                        SizedBox(
                          width: 96,
                          height: 116,
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _fotos[i].bytes == null
                                    ? Image.network(
                                        _fotos[i].url!,
                                        width: 96,
                                        height: 76,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox(
                                              height: 76,
                                              child: Icon(Icons.broken_image),
                                            ),
                                      )
                                    : Image.memory(
                                        _fotos[i].bytes!,
                                        width: 96,
                                        height: 76,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox(
                                              height: 76,
                                              child: Icon(Icons.broken_image),
                                            ),
                                      ),
                              ),
                              SizedBox(
                                height: 40,
                                child: TextButton(
                                  onPressed: _ocupado || _pendente != null
                                      ? null
                                      : () =>
                                            setState(() => _fotos.removeAt(i)),
                                  child: Text('Remover ${i + 1}'),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                OutlinedButton.icon(
                  onPressed: _ocupado || _pendente != null || _fotos.length == 6
                      ? null
                      : _adicionarFoto,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text('Adicionar foto (${_fotos.length}/6)'),
                ),
                const Text('JPG, PNG ou WEBP, até 5 MB por foto.'),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _tags,
                  enabled: !_ocupado && _pendente == null,
                  decoration: const InputDecoration(
                    labelText: 'Hashtags (opcional)',
                    hintText: '#Nhac #MeuPedido',
                    filled: true,
                    fillColor: Color(0xFFFFF6F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (_) {
                    final tags = _hashtags;
                    if (tags.length > 10) return 'Use até 10 hashtags.';
                    if (tags.any(
                      (t) =>
                          t.length > 60 ||
                          !RegExp(
                            r'^#[\p{L}\p{N}_]+$',
                            unicode: true,
                          ).hasMatch(t),
                    )) {
                      return 'Comece cada hashtag com # e use letras, números ou _.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Mencionar uma loja (opcional)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_lojaId != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      label: Text(
                        _loja?.nome ??
                            _lojaRestauradaNome ??
                            'Loja vinculada ($_lojaRestauradaId)',
                      ),
                      onDeleted: _ocupado || _pendente != null
                          ? null
                          : () => setState(() {
                              _loja = null;
                              _lojaRestauradaId = null;
                              _lojaRestauradaNome = null;
                            }),
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _busca,
                  enabled: !_ocupado && _pendente == null,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _buscarLoja(),
                  onChanged: (_) => setState(() {
                    _consulta++;
                    _buscando = false;
                    _buscou = false;
                    _lojas = [];
                    _erroBusca = null;
                  }),
                  decoration: InputDecoration(
                    labelText: 'Nome da loja',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: _ocupado || _pendente != null
                          ? null
                          : () => setState(() {
                              _busca.clear();
                              _consulta++;
                              _buscando = false;
                              _buscou = false;
                              _lojas = [];
                              _erroBusca = null;
                            }),
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _ocupado || _pendente != null || _buscando
                      ? null
                      : _buscarLoja,
                  icon: const Icon(Icons.search),
                  label: Text(_buscando ? 'Buscando...' : 'Buscar loja'),
                ),
                if (_erroBusca != null)
                  Text(_erroBusca!, style: TextStyle(color: cores.error)),
                if (_buscou && _lojas.isEmpty)
                  const Text('Nenhuma loja encontrada. Tente outro nome.'),
                for (final loja in _lojas)
                  ListTile(
                    title: Text(loja.nome),
                    subtitle: Text(loja.categoria),
                    selected: _loja?.id == loja.id,
                    trailing: Icon(
                      _loja?.id == loja.id
                          ? Icons.check_circle
                          : Icons.add_circle_outline,
                    ),
                    onTap: _ocupado || _pendente != null
                        ? null
                        : () => setState(() {
                            _loja = loja;
                            _lojas = [];
                            _buscou = false;
                          }),
                  ),
                if (_lojas.length == 50)
                  const Text(
                    'Mostrando 50 lojas. Refine o nome para encontrar a sua.',
                  ),
                const SizedBox(height: 20),
                if (_erro != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_erro!, style: TextStyle(color: cores.error)),
                    ),
                  ),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6961),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    key: const Key('feed.publish.submit'),
                    onPressed: _ocupado ? null : _publicar,
                    child: _ocupado
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _pendente == null
                                ? widget.post == null
                                      ? 'Publicar'
                                      : 'Salvar alterações'
                                : 'Confirmar envio anterior',
                          ),
                  ),
                ),
                if (_progresso != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_progresso!),
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
