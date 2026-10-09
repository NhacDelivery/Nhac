import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/repositories/feed_repository.dart';
import 'package:nhac/pages/feed_post_detail_page.dart';
import 'package:nhac/components/estado_com_retry.dart';
import 'package:nhac/globals/router.dart';

class FeedLinkPage extends StatefulWidget {
  final String id;
  const FeedLinkPage({super.key, required this.id});
  @override
  State<FeedLinkPage> createState() => _FeedLinkPageState();
}

class _FeedLinkPageState extends State<FeedLinkPage> {
  Future<FeedPostModel>? _post;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (authServiceRoteador.isAuthenticated)
      _post ??= FeedRepository().buscarPost(widget.id);
  }

  @override
  void didUpdateWidget(covariant FeedLinkPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id)
      _post = authServiceRoteador.isAuthenticated
          ? FeedRepository().buscarPost(widget.id)
          : null;
  }

  @override
  Widget build(BuildContext context) {
    if (!authServiceRoteador.isAuthenticated)
      return Scaffold(
        appBar: AppBar(title: const Text('Publicação compartilhada')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/bem-vindo'),
            child: const Text('Entrar para ver publicação'),
          ),
        ),
      );
    _post ??= FeedRepository().buscarPost(widget.id);
    return FutureBuilder<FeedPostModel>(
      future: _post,
      builder: (context, snapshot) {
        if (snapshot.hasData) return FeedPostDetailPage(post: snapshot.data!);
        return Scaffold(
          appBar: AppBar(title: const Text('Publicação compartilhada')),
          body: snapshot.hasError
              ? BannerErroInline(
                  mensagem:
                      'Não foi possível abrir a publicação. Ela pode ter sido excluída.',
                  aoTentarNovamente: () async {
                    setState(() {
                      _post = FeedRepository().buscarPost(widget.id);
                    });
                    try {
                      await _post;
                    } catch (_) {}
                  },
                )
              : const LoadingNhac(telaCheia: true),
        );
      },
    );
  }
}
