import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nhac/components/seta_voltar.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:shimmer/shimmer.dart';
import 'package:nhac/repositories/feed_repository.dart';
import 'package:nhac/models/feed/feed_comment_model.dart';
import 'package:nhac/utils/error_ui_helper.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:nhac/pages/loja_page.dart';

class FeedPostDetailPage extends StatefulWidget {
  final FeedPostModel post;

  const FeedPostDetailPage({super.key, required this.post});

  @override
  State<FeedPostDetailPage> createState() => _FeedPostDetailPageState();
}

class _FeedPostDetailPageState extends State<FeedPostDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();

  final FeedRepository _repository = FeedRepository();
  List<FeedCommentModel> _comments = [];
  late FeedPostModel _post;
  bool _loadingComments = true;
  bool _sending = false;
  bool _interacting = false;
  bool _hasMoreComments = false;
  int _commentPage = 0;
  int _commentRequestId = 0;
  int _postRequestId = 0;
  bool _openingStore = false;
  String? _commentError;

  List<FeedCommentModel> get _visibleComments {
    if (_tabController.index == 2) return _comments.where((c) => c.isAuthor).toList();
    if (_tabController.index == 1) return _comments.reversed.toList();
    return _comments;
  }

  static const List<String> _tabs = ['Padrão', 'Recentes', 'Autor'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _post = widget.post;
    _tabController.addListener(() { if (mounted) setState(() {}); });
    _carregarComentarios();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _carregarComentarios({bool mais = false}) async {
    if (mais && _loadingComments) return;
    final requestId = ++_commentRequestId;
    final postRequestId = ++_postRequestId;
    setState(() { _loadingComments = true; _commentError = null; });
    try {
      final page = mais ? _commentPage + 1 : 0;
      final comments = await _repository.buscarComentarios(_post.id, page: page);
      final post = await _repository.buscarPost(_post.id);
      if (!mounted || requestId != _commentRequestId) return;
      setState(() {
        _comments = mais ? [..._comments, ...comments] : comments;
        _commentPage = page;
        _hasMoreComments = comments.length == 20;
        if (postRequestId == _postRequestId) _post = post;
      });
    } catch (_) {
      if (mounted && requestId == _commentRequestId) setState(() => _commentError = 'Não foi possível carregar os comentários.');
    } finally {
      if (mounted && requestId == _commentRequestId) setState(() => _loadingComments = false);
    }
  }

  Future<void> _enviarComentario() async {
    final text = _commentController.text.trim();
    if (_sending || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _repository.comentar(_post.id, text);
      if (!mounted) return;
      if (_commentController.text.trim() == text) _commentController.clear();
      _commentFocus.unfocus();
      await _carregarComentarios();
    } catch (e) {
      if (mounted) ErrorUIHelper.handle(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _interagir({bool salvar = false}) async {
    if (_interacting) return;
    final postRequestId = ++_postRequestId;
    setState(() => _interacting = true);
    try {
      final post = await _repository.interagir(_post.id,
          ativo: salvar ? !_post.salvo : !_post.curtido, salvar: salvar);
      if (mounted && postRequestId == _postRequestId) setState(() => _post = post);
    } catch (e) {
      if (mounted) ErrorUIHelper.handle(context, e);
    } finally {
      if (mounted) setState(() => _interacting = false);
    }
  }

  Future<void> _abrirLoja(MentionedStoreModel store) async {
    if (_openingStore || store.id == null) return;
    setState(() => _openingStore = true);
    try {
      final loja = await LojaRepository().buscarLoja(store.id!);
      if (!mounted) return;
      if (loja == null) {
        throw StateError('Loja não encontrada');
      }
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => LojaPage(loja: loja),
      ));
    } catch (e) {
      if (mounted) ErrorUIHelper.handle(context, e);
    } finally {
      if (mounted) setState(() => _openingStore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final comments = _visibleComments;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Hero(
        tag: 'post_hero_${post.id}',
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            color: Colors.white,
            child: Stack(
              children: [
                // Scrollable content
                Positioned.fill(
                  child: CustomScrollView(
              slivers: [
                // ── AppBar ─────────────────────────────────
                SliverAppBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  pinned: true,
                  leading: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Center(child: SetaVoltar()),
                  ),
                  title: Row(
                    children: [
                      _buildAvatar(post.avatarUrl, 32.w),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.nomeUsuario,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15.sp,
                                color: const Color(0xFF5D201C),
                              ),
                            ),
                            if (post.badge != null)
                              Text(
                                post.badge!,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    Container(
                      margin: EdgeInsets.only(right: 16.w),
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF6961),
                          side: const BorderSide(color: Color(0xFFFF6961)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.w, vertical: 4.h),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Seguir',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Post Images ────────────────────────────
                if (post.imagens.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildPostImages(post.imagens),
                  ),

                // ── Post Content ───────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRichText(post.conteudo, post.hashTags),
                        if (post.mentionedStore != null)
                          _buildMentionedStore(post.mentionedStore!),
                        SizedBox(height: 16.h),

                        // Actions row (like, comment, share)
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _buildActionChip(
                                  icon: Icons.thumb_up_alt_outlined,
                                  label: _formatCount(post.curtidas),
                                ),
                              ),
                            ),
                            SizedBox(width: 40.w),
                            _buildActionChip(
                              icon: Icons.chat_bubble_outline,
                              label: _formatCount(post.comentarios),
                            ),
                            SizedBox(width: 40.w),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _buildActionChip(
                                  icon: Icons.share_outlined,
                                  label: '',
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16.h),
                        Divider(color: Colors.grey.shade200, height: 1),
                      ],
                    ),
                  ),
                ),

                // ── Comments Header + Tabs ─────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 0),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 18.r, color: const Color(0xFF5D201C)),
                        SizedBox(width: 6.w),
                        Text(
                          '${post.comentarios} comentários',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                            color: const Color(0xFF5D201C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabDelegate(
                    child: Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: const Color(0xFFFF6961),
                        unselectedLabelColor: Colors.grey,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 13.sp,
                        ),
                        indicator: UnderlineTabIndicator(
                          borderSide: BorderSide(
                            color: const Color(0xFFFF6961),
                            width: 2.5,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        indicatorSize: TabBarIndicatorSize.label,
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        tabs: _tabs.map((t) => Tab(text: t)).toList(),
                      ),
                    ),
                  ),
                ),

                // ── Comments List ──────────────────────────
                if (_loadingComments)
                  const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                if (_commentError != null)
                  SliverToBoxAdapter(child: Column(children: [
                    Text(_commentError!, textAlign: TextAlign.center),
                    TextButton(onPressed: () => _carregarComentarios(), child: const Text('Tentar novamente')),
                  ])),
                if (!_loadingComments && _commentError == null && comments.isEmpty)
                  const SliverToBoxAdapter(child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum comentário por aqui ainda.', textAlign: TextAlign.center),
                  )),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildCommentCard(comments[index]),
                    childCount: comments.length,
                  ),
                ),
                if (!_loadingComments && _hasMoreComments)
                  SliverToBoxAdapter(child: TextButton(
                    onPressed: () => _carregarComentarios(mais: true),
                    child: const Text('Carregar mais comentários'),
                  )),

                SliverToBoxAdapter(child: SizedBox(height: 100.h + bottomPadding)),
              ],
            ),
          ),

          // ── Bottom Floating Bar ───────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h + bottomPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Left Pill (Input)
                Expanded(
                  child: Container(
                    height: 52.h,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20.r, color: const Color(0xFFFF6961)),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            focusNode: _commentFocus,
                            style: TextStyle(fontSize: 14.sp),
                            decoration: InputDecoration(
                              hintText: 'Escreva...',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14.sp,
                              ),
                              border: InputBorder.none,
                            ),
                            maxLength: 2000,
                            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                            onSubmitted: (_) => _enviarComentario(),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Enviar comentário',
                          onPressed: _sending ? null : _enviarComentario,
                          icon: Icon(_sending ? Icons.hourglass_empty : Icons.send),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                // Right Pill (Actions)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildFloatingAction(Icons.chat_bubble_outline, _formatCount(post.comentarios)),
                      SizedBox(width: 8.w),
                      _buildFloatingAction(post.curtido ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined, _formatCount(post.curtidas), label: 'Curtir', onPressed: _interacting ? null : () => _interagir()),
                      SizedBox(width: 8.w),
                      _buildFloatingAction(post.salvo ? Icons.star_rounded : Icons.star_border_rounded, _formatCount(post.salvos), label: 'Salvar', onPressed: _interacting ? null : () => _interagir(salvar: true)),

                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        ],
      ),
          ),
        ),
      ),
    );
  }

  // ─── Post Images ──────────────────────────────────────────────────────────

  Widget _buildPostImages(List<String> imagens) {
    if (imagens.length == 1) {
      return _buildNetworkImage(imagens[0], height: 300.h);
    }

    return SizedBox(
      height: 300.h,
      child: PageView.builder(
        itemCount: imagens.length,
        itemBuilder: (context, index) {
          return _buildNetworkImage(imagens[index], height: 300.h);
        },
      ),
    );
  }

  Widget _buildNetworkImage(String url, {required double height}) {
    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        child: Container(
            color: Colors.white, height: height, width: double.infinity),
      ),
      errorWidget: (_, __, ___) => Container(
        height: height,
        color: const Color(0xFFFFF0EE),
        child: Icon(Icons.image_not_supported_outlined,
            color: Colors.grey.shade300),
      ),
    );
  }

  // ─── Comment Card ─────────────────────────────────────────────────────────

  Widget _buildCommentCard(FeedCommentModel comment) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(comment.avatarUrl, 34.w),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.nome,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp,
                        color: const Color(0xFF5D201C),
                      ),
                    ),
                    if (comment.isAuthor) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6961),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          'Autor',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  comment.conteudo,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: const Color(0xFF333333),
                    height: 1.4,
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildAvatar(String? url, double size) {
    return ClipOval(
      child: url != null && url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(width: size, height: size, color: Colors.grey.shade200),
              errorWidget: (_, __, ___) => _defaultAvatar(size),
            )
          : _defaultAvatar(size),
    );
  }

  Widget _defaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFFFE7E5),
      child: Icon(Icons.person, color: const Color(0xFF5D201C), size: size * 0.55),
    );
  }

  Widget _buildRichText(String conteudo, List<String> hashTags) {
    final spans = <TextSpan>[];
    final words = conteudo.split(' ');

    for (final word in words) {
      final isHash = hashTags.contains(word);
      spans.add(TextSpan(
        text: '$word ',
        style: TextStyle(
          color: isHash ? const Color(0xFFFF6961) : const Color(0xFF5D201C),
          fontWeight: isHash ? FontWeight.w600 : FontWeight.normal,
          fontSize: 15.sp,
          height: 1.6,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildMentionedStore(MentionedStoreModel store) {
    return Container(
      margin: EdgeInsets.only(top: 16.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: CachedNetworkImage(
                  imageUrl: store.imageUrl,
                  width: 48.w,
                  height: 48.w,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey.shade300),
                  errorWidget: (_, __, ___) => Container(color: Colors.grey.shade300, child: const Icon(Icons.store)),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE7E5),
                            borderRadius: BorderRadius.circular(4.r),
                            border: Border.all(color: const Color(0xFFFF6961)),
                          ),
                          child: Text(
                            'Loja',
                            style: TextStyle(fontSize: 10.sp, color: const Color(0xFFFF6961), fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            store.nome,
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: const Color(0xFF5D201C)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Icon(Icons.local_fire_department_rounded, size: 14.r, color: Colors.orange),
                        SizedBox(width: 4.w),
                        Text(
                          store.avaliacoes,
                          style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    store.rating.toStringAsFixed(1),
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: const Color(0xFF5D201C)),
                  ),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < store.rating.floor() ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 12.r,
                        color: Colors.amber,
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _openingStore || store.id == null ? null : () => _abrirLoja(store),
              child: Text(_openingStore ? 'Carregando...' : 'Ver loja e fazer pedido'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22.r, color: Colors.grey.shade500),
        if (label.isNotEmpty) ...[
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  Widget _buildFloatingAction(IconData icon, String count, {String? label, VoidCallback? onPressed}) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22.r, color: const Color(0xFFFF6961)),
        SizedBox(height: 2.h),
        Text(
          count,
          style: TextStyle(fontSize: 10.sp, color: const Color(0xFF5D201C)),
        ),
      ],
    );
    return label == null ? content : Semantics(
      label: label,
      button: true,
      child: InkWell(onTap: onPressed, child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
        child: content,
      )),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}

// ─── Sticky Tab Delegate ─────────────────────────────────────────────────────

class _StickyTabDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabDelegate({required this.child});
  final Widget child;

  @override
  double get minExtent => 46;
  @override
  double get maxExtent => 46;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyTabDelegate oldDelegate) =>
      oldDelegate.child != child;
}
