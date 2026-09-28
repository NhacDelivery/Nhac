import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nhac/components/seta_voltar.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:shimmer/shimmer.dart';
import 'package:nhac/components/botoes/botao_nhac.dart';

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

  // Mock comment replies
  late final List<_CommentData> _comments;

  static const List<String> _tabs = ['Padrão', 'Recentes', 'Autor'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _comments = _buildMockComments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  List<_CommentData> _buildMockComments() {
    final post = widget.post;
    final List<_CommentData> list = [];

    // Add the topComment as first if available
    if (post.topComment != null) {
      list.add(_CommentData(
        nome: post.topComment!.nomeUsuario,
        avatarUrl: null,
        conteudo: post.topComment!.conteudo,
        curtidas: post.topComment!.curtidas,
        isAuthor: false,
      ));
    }

    // Additional mock comments
    list.addAll([
      _CommentData(
        nome: 'Usuário Inicial',
        avatarUrl: 'https://i.pravatar.cc/150?img=20',
        conteudo: 'Que delícia! Vou pedir hoje mesmo 🤤',
        curtidas: 42,
        isAuthor: false,
      ),
      _CommentData(
        nome: post.nomeUsuario,
        avatarUrl: post.avatarUrl,
        conteudo: 'Obrigado pessoal! Recomendo muito mesmo 😊',
        curtidas: 18,
        isAuthor: true,
      ),
      _CommentData(
        nome: 'Maria Silva',
        avatarUrl: 'https://i.pravatar.cc/150?img=23',
        conteudo: 'Qual restaurante é esse? Preciso saber!',
        curtidas: 33,
        isAuthor: false,
      ),
      _CommentData(
        nome: 'João Pedro',
        avatarUrl: 'https://i.pravatar.cc/150?img=60',
        conteudo: 'Pedi ontem e realmente é muito bom! A entrega foi super rápida.',
        curtidas: 27,
        isAuthor: false,
      ),
      _CommentData(
        nome: 'Camila R.',
        avatarUrl: 'https://i.pravatar.cc/150?img=44',
        conteudo: 'Alguém sabe se entrega na zona sul? 🙏',
        curtidas: 8,
        isAuthor: false,
      ),
    ]);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
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
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildCommentCard(_comments[index]),
                    childCount: _comments.length,
                  ),
                ),

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
                            onSubmitted: (_) {
                              if (_commentController.text.trim().isNotEmpty) {
                                _commentController.clear();
                                _commentFocus.unfocus();
                              }
                            },
                          ),
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
                      SizedBox(width: 16.w),
                      _buildFloatingAction(Icons.thumb_up_alt_outlined, _formatCount(post.curtidas)),
                      SizedBox(width: 16.w),
                      _buildFloatingAction(Icons.star_border_rounded, '42'),
                      SizedBox(width: 16.w),
                      _buildFloatingAction(Icons.share_outlined, '36'),
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

  Widget _buildCommentCard(_CommentData comment) {
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
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(Icons.thumb_up_alt_outlined,
                        size: 14.r, color: Colors.grey.shade400),
                    SizedBox(width: 4.w),
                    Text(
                      _formatCount(comment.curtidas),
                      style: TextStyle(
                          fontSize: 12.sp, color: Colors.grey.shade500),
                    ),
                    SizedBox(width: 20.w),
                    Icon(Icons.chat_bubble_outline,
                        size: 14.r, color: Colors.grey.shade400),
                    SizedBox(width: 4.w),
                    Text(
                      'Responder',
                      style: TextStyle(
                          fontSize: 12.sp, color: Colors.grey.shade500),
                    ),
                  ],
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6961),
                    side: const BorderSide(color: Color(0xFFFF6961)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                  ),
                  child: Text('Seguir', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: BotaoNhac(
                  label: 'Fazer Pedido',
                  fontSize: 13.0,
                  onPressed: () {},
                ),
              ),
            ],
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

  Widget _buildFloatingAction(IconData icon, String count) {
    return Column(
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
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}

// ─── Comment Data ────────────────────────────────────────────────────────────

class _CommentData {
  final String nome;
  final String? avatarUrl;
  final String conteudo;
  final int curtidas;
  final bool isAuthor;

  const _CommentData({
    required this.nome,
    this.avatarUrl,
    required this.conteudo,
    required this.curtidas,
    required this.isAuthor,
  });
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
