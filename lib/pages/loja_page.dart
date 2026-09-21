import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/loja/lojas.dart';
import '../models/produto/produtos.dart';
import '../components/product_card.dart';
import '../components/seta_voltar.dart';
import '../pages/produto_detalhes_page.dart';
import '../repositories/produto_repository.dart';
import '../repositories/loja_repository.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../globals/ui_utils.dart';
import '../e2e/e2e_keys.dart';
import '../globals/app_constants.dart';

class LojaPage extends StatefulWidget {
  final LojasModel loja;
  const LojaPage({super.key, required this.loja});

  @override
  State<LojaPage> createState() => _LojaPageState();
}

class _LojaPageState extends State<LojaPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late Future<List<ProdutosModel>> _produtosFuture;

  final ProdutoRepository _produtoRepository = ProdutoRepository();
  final LojaRepository _lojaRepository = LojaRepository();

  bool _isSeguindo = false;
  int _seguidores = 0;
  bool _carregandoSeguidores = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _produtosFuture = _produtoRepository.buscarPorLoja(widget.loja.id);
    _carregarSeguidores();
  }

  Future<void> _carregarSeguidores() async {
    try {
      final count = await _lojaRepository.contarSeguidores(widget.loja.id);
      if (mounted) setState(() => _seguidores = count);

      if (!mounted) return;

      final auth = context.read<AuthService>();
      if (auth.usuarioId != null) {
        final seguindo =
            await _lojaRepository.estaSeguindo(auth.usuarioId!, widget.loja.id);
        if (mounted) setState(() => _isSeguindo = seguindo);
      }
    } finally {
      if (mounted) setState(() => _carregandoSeguidores = false);
    }
  }

  Future<void> _toggleSeguir() async {
    final auth = context.read<AuthService>();
    if (auth.usuarioId == null) {
      context.showError('Faça login para seguir a loja.');
      return;
    }

    try {
      if (_isSeguindo) {
        await _lojaRepository.deixarDeSeguir(auth.usuarioId!, widget.loja.id);
        if (mounted) {
          setState(() {
            _isSeguindo = false;
            _seguidores = (_seguidores > 0) ? _seguidores - 1 : 0;
          });
        }
      } else {
        await _lojaRepository.seguirLoja(auth.usuarioId!, widget.loja.id);
        if (mounted) {
          setState(() {
            _isSeguindo = true;
            _seguidores++;
          });
        }
      }
    } catch (e) {
      if (mounted) context.showError(e.toString());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      body: NestedScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildHeaderCover(),
                  Positioned(
                    top: 48.h,
                    left: 16.w,
                    child: const SetaVoltar(cor: Colors.white),
                  ),
                  Positioned(
                    top: 48.h,
                    right: 16.w,
                    child: const Icon(Icons.more_horiz, color: Colors.white),
                  ),
                  Column(
                    children: [
                      SizedBox(height: 85.h),
                      _buildProfileInfo(),
                      SizedBox(height: 16.h),
                      _buildStatsCards(),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.black87,
                    labelStyle:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
                    unselectedLabelColor: Colors.grey.shade600,
                    unselectedLabelStyle: TextStyle(
                        fontWeight: FontWeight.normal, fontSize: 16.sp),
                    indicatorColor: const Color(0xFFFF6961),
                    indicatorSize: TabBarIndicatorSize.label,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: "Produtos"),
                      Tab(text: "Espaço"),
                      Tab(text: "Avaliações"),
                      Tab(text: "Dinâmica"),
                    ],
                  ),
                ),
                MediaQuery.of(context).padding.top,
              ),
            ),
          ];
        },
        body: Container(
          color: Colors.white,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildProdutosTab(),
              const Center(child: Text("Espaço (Em Breve)")),
              const Center(child: Text("Avaliações (Em Breve)")),
              const Center(child: Text("Dinâmica (Em Breve)")),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCover() {
    return Container(
      height: 220.h,
      width: double.infinity,
      color: Colors.grey.shade300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppConstants.e2eMode
              ? Container(color: const Color(0xFF42567A))
              : CachedNetworkImage(
            imageUrl: "https://picsum.photos/seed/picsum/800/400",
            fit: BoxFit.cover,
            errorWidget: (context, url, error) =>
                Container(color: const Color(0xFF42567A)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 80.w,
                height: 80.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3.w),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF5D201C).withValues(alpha: 0.1),
                        blurRadius: 10.r,
                        offset: Offset(0, 4.h))
                  ],
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: widget.loja.imagemUrl.isNotEmpty
                      ? CachedNetworkImageProvider(widget.loja.imagemUrl)
                      : null,
                  child: widget.loja.imagemUrl.isEmpty
                      ? Icon(Icons.store, size: 36.r, color: Colors.grey)
                      : null,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.loja.nome,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black45, blurRadius: 4)
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8.w,
                      runSpacing: 4.h,
                      children: [
                        _buildBadge(
                            widget.loja.categoria, const Color(0xFF5D201C)),
                        Text(
                          _carregandoSeguidores
                              ? "Carregando..."
                              : "$_seguidores seguidores",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              shadows: const [
                                Shadow(color: Colors.black45, blurRadius: 4)
                              ]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _carregandoSeguidores ? null : _toggleSeguir,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isSeguindo ? Colors.white : const Color(0xFFFF6961),
                  foregroundColor:
                      _isSeguindo ? const Color(0xFFFF6961) : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                ),
                child: Text(
                    _carregandoSeguidores
                        ? "..."
                        : _isSeguindo
                            ? "Seguindo"
                            : "Seguir",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12.sp)),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            widget.loja.descricao.isNotEmpty
                ? widget.loja.descricao
                : "Bem-vindo à nossa loja! Confira nossos produtos.",
            style: TextStyle(
                color: Colors.white,
                fontSize: 11.sp,
                shadows: const [Shadow(color: Colors.black45, blurRadius: 2)]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              color: Colors.white,
              fontSize: 10.sp,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatsCards() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(
                "Avaliação",
                (widget.loja.dadosOperacionais?.avaliacaoMedia ?? 0.0)
                    .toStringAsFixed(1),
                "Excelente",
                const Color(0xFF5D201C)),
            Container(width: 1, height: 40.h, color: Colors.grey.shade200),
            _buildStatItem(
                "Avaliações",
                "${widget.loja.dadosOperacionais?.totalAvaliacoes ?? 0}",
                "Total",
                const Color(0xFFFF6961)),
            Container(width: 1, height: 40.h, color: Colors.grey.shade200),
            _buildStatItem("Produtos", "100%", "Positivo", Colors.black87),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String title, String value, String subtitle, Color valueColor) {
    return Column(
      children: [
        Text(title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.sp)),
        SizedBox(height: 4.h),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold)),
        SizedBox(height: 4.h),
        Text(subtitle,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 10.sp)),
      ],
    );
  }

  Widget _buildProdutosTab() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                _buildFilterChip("Todos", true),
                SizedBox(width: 8.w),
                _buildFilterChip("Em destaque", false),
                SizedBox(width: 8.w),
                _buildFilterChip("Vendidos", false),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          sliver: FutureBuilder<List<ProdutosModel>>(
            future: _produtosFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFFF6961))));
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.w),
                      child: Text('Nenhum produto disponível no momento 😥',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  ),
                );
              }

              final produtos = snapshot.data!;

              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                  childAspectRatio: 0.70,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final produto = produtos[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  ProdutoDetalhesPage(produto: produto),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            const begin = Offset(0.0, 1.0);
                            const end = Offset.zero;
                            const curve = Curves.easeOutCubic;

                            var tween = Tween(begin: begin, end: end)
                                .chain(CurveTween(curve: curve));

                            return SlideTransition(
                              position: animation.drive(tween),
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 300),
                        ),
                      ),
                      child: ProductCard(
                        key: E2EKeys.storeProduct(produto.id),
                        produto: produto,
                        lojaFechada: !widget.loja.isAberto,
                      ),
                    );
                  },
                  childCount: produtos.length,
                ),
              );
            },
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 100.h)),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFF6961) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey.shade600,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13.sp,
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;
  final double safeAreaTop;

  _SliverAppBarDelegate(this.tabBar, this.safeAreaTop);

  @override
  double get minExtent => 48.0 + safeAreaTop;
  @override
  double get maxExtent => 48.0 + safeAreaTop;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(top: safeAreaTop),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return safeAreaTop != oldDelegate.safeAreaTop ||
        tabBar != oldDelegate.tabBar;
  }
}
