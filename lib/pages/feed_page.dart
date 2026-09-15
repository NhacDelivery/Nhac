import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:nhac/components/home/home_banner_carousel.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/pages/search_page.dart';
import 'package:nhac/repositories/feed_repository.dart';
import 'package:shimmer/shimmer.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FeedRepository _repository = FeedRepository();
  List<FeedPostModel> _posts = [];
  bool _isLoading = true;

  static const List<String> _categorias = [
    'Destaques',
    'Em Alta',
    'Promoções',
    'Novidades',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categorias.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      _carregarPosts(_categorias[_tabController.index]);
    });
    _carregarPosts('Destaques');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregarPosts(String categoria) async {
    if (mounted) setState(() => _isLoading = true);
    final posts = await _repository.buscarPosts(categoria: categoria);
    if (mounted) {
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // ── Pull-to-refresh ──────────────────────────────────────────────────
          CupertinoSliverRefreshControl(
            refreshIndicatorExtent: 120.h,
            refreshTriggerPullDistance: 160.h,
            onRefresh: () => _carregarPosts(_categorias[_tabController.index]),
            builder: (context, refreshState, pulledExtent,
                refreshTriggerPullDistance, refreshIndicatorExtent) {
              return Center(
                child: Opacity(
                  opacity:
                      (pulledExtent / refreshIndicatorExtent).clamp(0.0, 1.0),
                  child: Lottie.asset(
                    'assets/animations/loading_nhac.json',
                    width: 180.w,
                    height: 180.h,
                    animate: refreshState == RefreshIndicatorMode.refresh ||
                        refreshState == RefreshIndicatorMode.armed,
                  ),
                ),
              );
            },
          ),

          // ── Header: localização + search bar + carrossel ──────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título + ícone de notificação
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Feed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 26.sp,
                          color: const Color(0xFF5D201C),
                        ),
                      ),
                      Icon(Icons.notifications_none_outlined,
                          color: const Color(0xFF5D201C), size: 26.r),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Search bar — igual à Home
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation,
                                  secondaryAnimation) =>
                              const SearchPage(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                                opacity: animation, child: child);
                          },
                          transitionDuration:
                              const Duration(milliseconds: 300),
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50.r),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF5D201C).withValues(alpha: 0.05),
                            blurRadius: 10.r,
                            offset: const Offset(0.0, 4.0),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Colors.grey, size: 22.r),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'Procurar',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 16.sp),
                            ),
                          ),
                          Icon(Icons.tune, color: Colors.grey, size: 22.r),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // Carrossel de banners — o mesmo componente da Home
                  const HomeBannerCarousel(),

                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ),

          // ── TabBar de categorias ──────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              child: Container(
                color: const Color(0xFFFFE7E5),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: const Color(0xFFFF6961),
                  unselectedLabelColor: Colors.grey,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14.sp,
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
                  tabs: _categorias.map((c) => Tab(text: c)).toList(),
                ),
              ),
            ),
          ),

          // ── Conteúdo: skeleton / vazio / posts ───────────────────────────
          if (_isLoading)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  child: _buildSkeletonCard(),
                ),
                childCount: 4,
              ),
            )
          else if (_posts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.newspaper_outlined,
                        size: 56.r, color: Colors.grey.shade300),
                    SizedBox(height: 12.h),
                    Text(
                      'Nenhum post por aqui ainda.',
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 15.sp),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 12.h : 0),
                    child: _buildPostCard(_posts[index]),
                  ),
                  childCount: _posts.length,
                ),
              ),
            ),

          SliverToBoxAdapter(child: SizedBox(height: 120.h)),
        ],
      ),
    );
  }

  // ─── Post Card ────────────────────────────────────────────────────────────

  Widget _buildPostCard(FeedPostModel post) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5D201C).withValues(alpha: 0.05),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 8.h),
              child: Row(
                children: [
                  _buildAvatar(post.avatarUrl),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.nomeUsuario,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        if (post.badge != null) ...[
                          SizedBox(height: 2.h),
                          Text(
                            post.badge!,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down,
                      color: Colors.grey.shade400, size: 20.r),
                ],
              ),
            ),

            // Sponsor badge
            if (post.isPatrocinado && post.sponsorLabel != null)
              Padding(
                padding: EdgeInsets.only(left: 14.w, bottom: 8.h),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFFF6961).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    post.sponsorLabel!,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFF6961),
                    ),
                  ),
                ),
              ),

            // Content text
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: _buildRichText(post.conteudo, post.hashTags),
            ),

          // Images
            if (post.imagens.isNotEmpty) ...[
              SizedBox(height: 10.h),
              _buildImagesGrid(post.imagens),
            ],

            // Top Comment
            if (post.topComment != null) _buildTopComment(post.topComment!),

            // Footer (likes, comments, share)
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFooterAction(
                    icon: Icons.thumb_up_alt_outlined,
                    label: _formatCount(post.curtidas),
                  ),
                  SizedBox(width: 32.w),
                  _buildFooterAction(
                    icon: Icons.chat_bubble_outline,
                    label: _formatCount(post.comentarios),
                  ),
                  SizedBox(width: 32.w),
                  _buildFooterAction(
                    icon: Icons.share_outlined,
                    label: '',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopComment(TopCommentModel comment) {
    return Container(
      margin: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 0),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6961),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4.r),
                topRight: Radius.circular(4.r),
                bottomRight: Radius.circular(4.r),
              ),
            ),
            child: Text(
              '${comment.curtidas} curtidas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 6.h),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${comment.nomeUsuario}: ',
                  style: TextStyle(
                    color: const Color(0xFFFF6961),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: comment.conteudo,
                  style: TextStyle(
                    color: const Color(0xFF1A1A1A),
                    fontSize: 13.sp,
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

  Widget _buildAvatar(String? url) {
    return ClipOval(
      child: url != null && url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              width: 40.w,
              height: 40.w,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 40.w,
                height: 40.w,
                color: Colors.grey.shade200,
              ),
              errorWidget: (_, __, ___) => _defaultAvatar(),
            )
          : _defaultAvatar(),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 40.w,
      height: 40.w,
      color: const Color(0xFFFFE7E5),
      child: Icon(Icons.person, color: const Color(0xFF5D201C), size: 22.r),
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
          color: isHash
              ? const Color(0xFFFF6961)
              : const Color(0xFF1A1A1A),
          fontWeight:
              isHash ? FontWeight.w600 : FontWeight.normal,
          fontSize: 14.sp,
          height: 1.5,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildImagesGrid(List<String> imagens) {
    if (imagens.length == 1) {
      return _buildNetworkImage(imagens[0],
          height: 220.h, width: double.infinity);
    }

    return SizedBox(
      height: 190.h,
      child: Row(
        children: List.generate(imagens.take(2).length, (i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 0 : 2.w,
                right: i == imagens.take(2).length - 1 ? 0 : 2.w,
              ),
              child: _buildNetworkImage(imagens[i],
                  height: 190.h, width: double.infinity),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNetworkImage(String url,
      {required double height, required double width}) {
    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: width,
      fit: BoxFit.cover,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        child:
            Container(color: Colors.white, height: height, width: width),
      ),
      errorWidget: (_, __, ___) => Container(
        height: height,
        color: const Color(0xFFFFF0EE),
        child: Icon(Icons.image_not_supported_outlined,
            color: Colors.grey.shade300),
      ),
    );
  }

  Widget _buildFooterAction(
      {required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20.r, color: Colors.grey.shade500),
        if (label.isNotEmpty) ...[
          SizedBox(width: 5.w),
          Text(
            label,
            style: TextStyle(
                fontSize: 13.sp, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  // ─── Skeleton ─────────────────────────────────────────────────────────────

  Widget _buildSkeletonCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
        ),
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(
                  child: Container(
                      width: 40.w, height: 40.w, color: Colors.white),
                ),
                SizedBox(width: 10.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: 120.w, height: 12.h, color: Colors.white),
                    SizedBox(height: 6.h),
                    Container(
                        width: 80.w, height: 10.h, color: Colors.white),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Container(
                width: double.infinity, height: 12.h, color: Colors.white),
            SizedBox(height: 6.h),
            Container(width: 240.w, height: 12.h, color: Colors.white),
            SizedBox(height: 12.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                width: double.infinity,
                height: 180.h,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 50.w, height: 14.h, color: Colors.white),
                SizedBox(width: 32.w),
                Container(width: 50.w, height: 14.h, color: Colors.white),
                SizedBox(width: 32.w),
                Container(width: 20.w, height: 14.h, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}

// ─── Sticky TabBar Delegate ───────────────────────────────────────────────────

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabBarDelegate({required this.child});
  final Widget child;

  @override
  double get minExtent => 46;
  @override
  double get maxExtent => 46;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) =>
      oldDelegate.child != child;
}
