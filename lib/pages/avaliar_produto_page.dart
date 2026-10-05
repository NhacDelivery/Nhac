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
  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _foto() async {
    if (_busy || _fotos.length >= 6) return;
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
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      while (_urls.length < _fotos.length) {
        _urls.add(await ImageUploadService().enviar(_fotos[_urls.length]));
      }
      _incerto = true;
      await AvaliacaoRepository().avaliarProduto(
        widget.produtoId,
        widget.pedidoId,
        _nota,
        _texto.text.trim(),
        _urls,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Não foi possível confirmar a avaliação. Tente novamente com o mesmo conteúdo.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: Text('Avaliar ${widget.nome}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Sua nota para este produto'),
          Wrap(
            children: [
              for (var nota = 1; nota <= 5; nota++)
                IconButton(
                  tooltip: 'Nota $nota',
                  onPressed: _busy || _incerto
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
            enabled: !_busy && !_incerto,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Comentário',
              border: OutlineInputBorder(),
            ),
          ),
          for (var i = 0; i < _fotos.length; i++)
            ListTile(
              title: Text('Foto ${i + 1}'),
              trailing: IconButton(
                tooltip: 'Remover foto',
                onPressed: _busy || _incerto
                    ? null
                    : () => setState(() {
                        _fotos.removeAt(i);
                        _urls.clear();
                      }),
                icon: const Icon(Icons.close),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _busy || _incerto || _fotos.length == 6 ? null : _foto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Adicionar foto'),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _busy ? null : _enviar,
              child: Text(_busy ? 'Enviando...' : 'Enviar avaliação'),
            ),
          ),
        ],
      ),
    ),
  );
}
