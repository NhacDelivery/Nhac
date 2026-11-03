import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/repositories/feed_repository.dart';

class ProfilePublicationsSection extends StatefulWidget {
  const ProfilePublicationsSection({
    super.key,
    required this.usuarioId,
    this.isActive = true,
    this.refreshVersion = 0,
    this.repository,
  });

  final String usuarioId;
  final bool isActive;
  final int refreshVersion;
  final FeedRepository? repository;

  @override
  State<ProfilePublicationsSection> createState() =>
      _ProfilePublicationsSectionState();
}

class _ProfilePublicationsSectionState
    extends State<ProfilePublicationsSection> {
  static const int _pageSize = 20;

  late final FeedRepository _repository =
      widget.repository ?? FeedRepository();

  final List<FeedPostModel> _posts = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _started = false;
  String? _error;
  String? _paginationError;
  int _page = 0;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _carregar();
  }

  @override
  void didUpdateWidget(covariant ProfilePublicationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.usuarioId != widget.usuarioId) {
      _requestVersion++;
      _posts.clear();
      _page = 0;
      _hasMore = false;
      _error = null;
      _paginationError = null;
      _started = false;
      _loading = false;
      _loadingMore = false;
    }
    final atualizar = oldWidget.refreshVersion != widget.refreshVersion;
    if (atualizar) {
      _requestVersion++;
      _loading = false;
      _loadingMore = false;
    }
    if (widget.isActive &&
        (atualizar || !oldWidget.isActive || !_started)) {
      _carregar();
    }
  }

  Future<void> _carregar({bool append = false}) async {
    if (!widget.isActive || _loading || _loadingMore) return;

    final requestVersion = ++_requestVersion;
    final page = append ? _page + 1 : 0;
    setState(() {
      if (append) {
        _loadingMore = true;
        _paginationError = null;
      } else {
        _loading = true;
        _error = null;
      }
    });

    try {
      final posts = await _repository.buscarMinhasPublicacoes(page: page);
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        if (append) {
          final ids = _posts.map((post) => post.id).toSet();
          _posts.addAll(posts.where((post) => ids.add(post.id)));
        } else {
          _posts
            ..clear()
            ..addAll(posts);
        }
        _page = page;
        _hasMore = posts.length == _pageSize;
        _started = true;
        _error = null;
        _paginationError = null;
      });
    } catch (_) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        if (append) {
          _paginationError = 'Não foi possível carregar mais publicações.';
        } else {
          _error = 'Não foi possível carregar suas publicações.';
        }
      });
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _abrirPost(FeedPostModel post) async {
    final removido = await context.push<bool>('/feed-post', extra: post);
    if (!mounted) return;
    if (removido == true) {
      setState(() => _posts.removeWhere((item) => item.id == post.id));
      return;
    }
    await _carregar();
  }

  Future<void> _publicar() async {
    final post = await context.push<FeedPostModel>('/feed-publicar');
    if (!mounted || post == null) return;
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Row(
            children: [
              Icon(
                Icons.grid_on_outlined,
                color: const Color(0xFF5D201C),
                size: 18.r,
              ),
              SizedBox(width: 8.w),
              Text(
                'Publicações',
                style: TextStyle(
                  color: const Color(0xFF5D201C),
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_posts.isNotEmpty)
                Text(
                  '${_posts.length}${_hasMore ? '+' : ''}',
                  style: TextStyle(
                    color: const Color(0xFF8D625F),
                    fontSize: 12.sp,
                  ),
                ),
            ],
          ),
        ),
        if (_loading && _posts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator.adaptive()),
          )
        else if (_error != null && _posts.isEmpty)
          _buildMensagem(
            _error!,
            acao: 'Tentar novamente',
            onPressed: _carregar,
          )
        else if (_posts.isEmpty)
          _buildMensagem(
            'Suas publicações aparecerão aqui.',
            acao: 'Compartilhar experiência',
            onPressed: _publicar,
          )
        else ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _posts.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 3.w,
              mainAxisSpacing: 3.w,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, index) {
              final post = _posts[index];
              return _PostGridTile(
                post: post,
                onTap: () => _abrirPost(post),
              );
            },
          ),
          if (_paginationError != null)
            TextButton(
              onPressed: _loadingMore ? null : () => _carregar(append: true),
              child: Text('$_paginationError Tentar novamente'),
            ),
          if (_hasMore)
            Center(
              child: TextButton.icon(
                onPressed:
                    _loadingMore ? null : () => _carregar(append: true),
                icon: _loadingMore
                    ? SizedBox(
                        width: 16.r,
                        height: 16.r,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(_loadingMore ? 'Carregando...' : 'Carregar mais'),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildMensagem(
    String mensagem, {
    required String acao,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        children: [
          Icon(
            _error == null ? Icons.photo_library_outlined : Icons.cloud_off,
            color: const Color(0xFF8D625F),
            size: 28.r,
          ),
          SizedBox(height: 8.h),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF5D201C),
              fontSize: 13.sp,
            ),
          ),
          TextButton(onPressed: onPressed, child: Text(acao)),
        ],
      ),
    );
  }
}

class _PostGridTile extends StatelessWidget {
  const _PostGridTile({required this.post, required this.onTap});

  final FeedPostModel post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imagem = post.imagens.isNotEmpty ? post.imagens.first : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(9.r),
      child: Material(
        color: const Color(0xFFFFF0EE),
        child: InkWell(
          onTap: onTap,
          child: Semantics(
            button: true,
            label: 'Abrir publicação: ${post.conteudo}',
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imagem != null)
                  CachedNetworkImage(
                    imageUrl: imagem,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const ColoredBox(color: Color(0xFFFFE7E5)),
                    errorWidget: (_, __, ___) => _textoPost(),
                  )
                else
                  _textoPost(),
                if (post.imagens.length > 1)
                  Positioned(
                    top: 7.h,
                    right: 7.w,
                    child: Icon(
                      Icons.collections_outlined,
                      color: Colors.white,
                      size: 18.r,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 5),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _textoPost() {
    return Container(
      padding: EdgeInsets.all(9.w),
      color: const Color(0xFFFFE7E5),
      alignment: Alignment.center,
      child: Text(
        post.conteudo,
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: const Color(0xFF5D201C),
          fontSize: 11.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
