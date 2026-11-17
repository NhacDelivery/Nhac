import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/models/feed/feed_post_model.dart';

class FeedAutorLink extends StatelessWidget {
  const FeedAutorLink({super.key, required this.post, required this.child});

  final FeedPostModel post;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final id = post.usuarioId;
    if (id == null || id.isEmpty) return child;
    return Semantics(
      link: true,
      label: 'Ver perfil de ${post.nomeUsuario}',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/feed/perfil/${Uri.encodeComponent(id)}'),
        child: child,
      ),
    );
  }
}
