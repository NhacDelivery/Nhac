import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/feed_tentativa_service.dart';
import 'package:nhac/utils/request_outcome.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nhac/services/image_upload_service.dart';
import 'package:nhac/repositories/avaliacao_repository.dart';

class AvaliarProdutoPage extends StatefulWidget {
  final String produtoId, pedidoId, nome;
  const AvaliarProdutoPage({
    super.key,
    required this.produtoId,
    required this.pedidoId,
    required this.nome,
  });
  @override
  State<AvaliarProdutoPage> createState() => _AvaliarProdutoPageState();
}

class _AvaliarProdutoPageState extends State<AvaliarProdutoPage> {
  final _texto = TextEditingController();
  final _fotos = <XFile>[];
  final _urls = <String>[];
  int _nota = 5;
  bool _busy = false, _incerto = false;
  String? _error;
  bool _loading = true, _conferida = false;
  Map<String, dynamic>? _existente;
  final _tentativas = const FeedTentativaService();
  String get _escopo => 'avaliacao:${widget.pedidoId}:${widget.produtoId}';
  String? get _uid => context.read<AuthService>().usuarioId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restaurar());
  }

  Future<void> _restaurar() async {
    try {
      final uid = _uid;
      if (uid == null) throw StateError('Faça login para avaliar.');
      final pending = await _tentativas.carregar(uid, _escopo);
      if (!mounted) return;
      if (pending != null) {
        final payload = pending['payload'] as Map;
        _nota = (payload['nota'] as num).toInt();
        _texto.text = payload['comentario'] as String;
        _urls.clear();
        _urls.addAll(List<String>.from(payload['imagens'] as List));
        _incerto = true;
      }
      final avaliacoes = await AvaliacaoRepository().minhasDados(
        widget.pedidoId,
      );
      if (!mounted || _uid != uid) return;
      _conferida = true;
      for (final a in avaliacoes)
        if (a['produtoId'] == widget.produtoId) {
          _existente = a;
          _nota = (a['nota'] as num).toInt();
          _texto.text = a['comentario'] as String? ?? '';
          _urls.clear();
          _urls.addAll(List<String>.from(a['imagens'] as List? ?? []));
          await _tentativas.concluir(uid, _escopo);
          _incerto = false;
          break;
        }
    } catch (e) {
      if (mounted)
        _error = 'Não foi possível conferir sua avaliação. Tente novamente. $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _foto() async {
    if (_busy ||
        _incerto ||
        _existente != null ||
        _fotos.length + _urls.length >= 6)
      return;
    setState(() => _busy = true);
    try {
      final foto = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (foto != null) {
        final size = await foto.length();
        if (size < 1 || size > 5 * 1024 * 1024)
          throw StateError('Escolha uma foto com até 5 MB.');
        if (mounted) setState(() => _fotos.add(foto));
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Não foi possível selecionar a foto. Use uma imagem de até 5 MB.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enviar() async {
    if (_busy || _loading || !_conferida || _existente != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_incerto) {
        while (_fotos.isNotEmpty) {
          _urls.add(await ImageUploadService().enviar(_fotos.first));
          _fotos.removeAt(0);
        }
      }
      final uid = _uid;
      if (uid == null) throw StateError('Faça login para avaliar.');
      final pending = await _tentativas.preparar(uid, _escopo, {
        'nota': _nota,
        'comentario': _texto.text.trim(),
        'imagens': List.of(_urls),
      });
      _incerto = true;
      final payload = pending['payload'] as Map;
      await AvaliacaoRepository().avaliarProduto(
        widget.produtoId,
        widget.pedidoId,
        (payload['nota'] as num).toInt(),
        payload['comentario'] as String,
        List<String>.from(payload['imagens'] as List),
      );
      await _tentativas.concluir(uid, _escopo);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final status = e is DioException
          ? e.response?.statusCode
          : e is AppException
          ? e.statusCode
          : null;
      if (status == 409) {
        // Pode haver uma avaliação confirmada em outro dispositivo.
        await _restaurar();
        if (_existente != null) {
          if (mounted) setState(() => _error = null);
          return;
        }
      }
      if (rejeicaoDefinitiva(e)) {
        final uid = _uid;
        if (uid != null) await _tentativas.concluir(uid, _escopo);
        _incerto = false;
      }
      if (mounted)
        setState(
          () => _error = rejeicaoDefinitiva(e)
              ? 'Avaliação rejeitada. Corrija os dados e tente novamente. $e'
              : 'Não foi possível confirmar a avaliação. Tente novamente com o mesmo conteúdo.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          _existente == null ? 'Avaliar ${widget.nome}' : 'Sua avaliação',
        ),
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_existente != null)
            const Text(
              'Você já avaliou este produto neste pedido.',
              style: TextStyle(
                color: Color(0xFF5D201C),
                fontWeight: FontWeight.bold,
              ),
            ),
          const Text('Sua nota para este produto'),
          Wrap(
            children: [
              for (var nota = 1; nota <= 5; nota++)
                IconButton(
                  tooltip: 'Nota $nota',
                  onPressed: _busy || _loading || _existente != null || _incerto
                      ? null
                      : () => setState(() => _nota = nota),
                  icon: Icon(
                    nota <= _nota ? Icons.star : Icons.star_border,
                    color: const Color(0xFFFF6961),
                  ),
                ),
            ],
          ),
          TextField(
            controller: _texto,
            enabled: !_busy && !_loading && !_incerto && _existente == null,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Comentário',
              border: OutlineInputBorder(),
            ),
          ),
          for (var i = 0; i < _urls.length; i++)
            ListTile(
              leading: Image.network(
                _urls[i],
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
              ),
              title: Text('Foto ${i + 1}'),
              trailing: IconButton(
                tooltip: 'Remover foto',
                onPressed: _busy || _loading || _incerto || _existente != null
                    ? null
                    : () => setState(() => _urls.removeAt(i)),
                icon: const Icon(Icons.close),
              ),
            ),
          for (var i = 0; i < _fotos.length; i++)
            ListTile(
              title: Text('Foto ${i + 1}'),
              trailing: IconButton(
                tooltip: 'Remover foto',
                onPressed: _busy || _loading || _existente != null || _incerto
                    ? null
                    : () => setState(() {
                        _fotos.removeAt(i);
                      }),
                icon: const Icon(Icons.close),
              ),
            ),
          OutlinedButton.icon(
            onPressed:
                _busy ||
                    _loading ||
                    _existente != null ||
                    _incerto ||
                    _fotos.length + _urls.length >= 6
                ? null
                : _foto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Adicionar foto'),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (!_conferida && !_loading)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _restaurar();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Conferir avaliação novamente'),
            ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _busy || _loading || !_conferida || _existente != null
                  ? null
                  : _enviar,
              child: Text(
                _busy
                    ? 'Enviando...'
                    : _incerto
                    ? 'Confirmar avaliação anterior'
                    : _existente != null
                    ? 'Avaliação registrada'
                    : 'Enviar avaliação',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
