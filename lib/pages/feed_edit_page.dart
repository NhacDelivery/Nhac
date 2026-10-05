import 'package:flutter/material.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/repositories/feed_repository.dart';

class FeedEditPage extends StatefulWidget {
  final FeedPostModel post;
  const FeedEditPage({super.key, required this.post});
  @override
  State<FeedEditPage> createState() => _FeedEditPageState();
}

class _FeedEditPageState extends State<FeedEditPage> {
  final _form = GlobalKey<FormState>();
  late final _text = TextEditingController(text: widget.post.conteudo);
  late final _tags = TextEditingController(
    text: widget.post.hashTags.join(' '),
  );
  bool _busy = false, _exit = false;
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _back() async {
    if (_busy) return;
    final changed =
        _text.text != widget.post.conteudo ||
        _tags.text != widget.post.hashTags.join(' ');
    final discard =
        !changed ||
        await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Descartar alterações?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Continuar editando'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Descartar'),
                  ),
                ],
              ),
            ) ==
            true;
    if (mounted && discard) {
      setState(() => _exit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final post = await FeedRepository().editar(
        widget.post,
        _text.text,
        _tags.text
            .trim()
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty)
            .toList(),
      );
      if (mounted) {
        setState(() => _exit = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, post);
        });
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Não foi possível salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _exit,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Editar publicação'),
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: _busy ? null : _back,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _text,
              enabled: !_busy,
              minLines: 5,
              maxLines: 10,
              maxLength: 5000,
              decoration: const InputDecoration(
                labelText: 'Publicação',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Escreva algo para publicar.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tags,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Hashtags',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final tags = (v ?? '')
                    .trim()
                    .split(RegExp(r'\s+'))
                    .where((t) => t.isNotEmpty)
                    .toList();
                return tags.length > 10 ||
                        tags.any(
                          (t) =>
                              t.length > 60 ||
                              !RegExp(
                                r'^#[\p{L}\p{N}_]+$',
                                unicode: true,
                              ).hasMatch(t),
                        )
                    ? 'Use até 10 hashtags válidas.'
                    : null;
              },
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Salvando...' : 'Salvar alterações'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
