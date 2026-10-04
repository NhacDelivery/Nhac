import 'dart:async';
import 'package:nhac/components/estado_com_retry.dart';
import 'package:nhac/repositories/avaliacao_repository.dart';
import 'package:nhac/models/produto/avaliacoes.dart';
import 'package:flutter/material.dart';
import 'package:nhac/components/loading_nhac.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/loja/lojas.dart';
import '../models/produto/produtos.dart';
import '../components/product_card.dart';
import '../components/nhac_filter_chip.dart';
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late LojasModel _loja;
  Timer? _atualizacaoLoja;
  bool _consultandoLoja = false;
  bool _lojaConfirmada = false;
  bool _erroLoja = false;
  final _avaliacoes = <AvaliacoesModel>[];
  int _paginaAvaliacoes = 0;
  bool _maisAvaliacoes = true;
  bool _carregandoAvaliacoes = false;
  bool _erroAvaliacoes = false;

  late TabController _tabController;

  final List<ProdutosModel> _produtos = [];
  int _pagina = 0;
  bool _temMais = true;
  bool _carregandoProdutos = false;
  Object? _erroProdutos;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _atualizarLoja();
      _atualizacaoLoja ??= Timer.periodic(const Duration(seconds: 30), (_) => _atualizarLoja());
    } else {
      _atualizacaoLoja?.cancel();
      _atualizacaoLoja = null;
    }
  }

  Future<void> _atualizarLoja() async {
    if (_consultandoLoja) return;
    _consultandoLoja = true;
    try {
      final loja = await _lojaRepository.buscarLoja(_loja.id, atualizar: true);
      if (!mounted) return;
      setState(() {
        if (loja != null) _loja = loja;
        _lojaConfirmada = loja != null;
        _erroLoja = loja == null;
      });
    } catch (_) {
      if (mounted) setState(() { _erroLoja = true; _lojaConfirmada = false; });
    } finally {
      _consultandoLoja = false;
    }
  }

  Future<void> _carregarAvaliacoes() async {
    if (_carregandoAvaliacoes || !_maisAvaliacoes) return;
    setState(() { _carregandoAvaliacoes = true; _erroAvaliacoes = false; });
    try {
      final novas = await AvaliacaoRepository().buscarAvaliacoes(_loja.id, page: _paginaAvaliacoes);
      if (!mounted) return;
      setState(() {
        final ids = _avaliacoes.map((a) => a.id).toSet();
        _avaliacoes.addAll(novas.where((a) => ids.add(a.id)));
        _paginaAvaliacoes++;
        _maisAvaliacoes = novas.length == 10;
      });
    } catch (_) {
      if (mounted) setState(() => _erroAvaliacoes = true);
    } finally {
      if (mounted) setState(() => _carregandoAvaliacoes = false);
    }
  }

  Widget _buildAvaliacoesTab() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      if (_erroAvaliacoes) BannerErroInline(
        mensagem: 'Não foi possível carregar as avaliações.',
        aoTentarNovamente: _carregarAvaliacoes,
      ),
      if (_avaliacoes.isEmpty && !_carregandoAvaliacoes && !_erroAvaliacoes)
        const Text('Esta loja ainda não recebeu avaliações.'),
      for (final avaliacao in _avaliacoes) ListTile(
        title: Text(avaliacao.nomeUsuario),
        subtitle: Text(avaliacao.comentario.isEmpty ? 'Sem comentário' : avaliacao.comentario),
        trailing: Text('★ ${avaliacao.nota.toStringAsFixed(1)}'),
      ),
      if (_carregandoAvaliacoes) const LoadingNhac(telaCheia: false),
      if (_maisAvaliacoes && !_carregandoAvaliacoes && !_erroAvaliacoes)
        TextButton(onPressed: _carregarAvaliacoes, child: const Text('Carregar mais avaliações')),
    ],
  );

  Widget _buildEspacoTab() {
    final endereco = _loja.endereco;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(_loja.nome, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Text(_loja.descricao.isEmpty ? 'A loja ainda não informou uma descrição.' : _loja.descricao),
      if (endereco != null) ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: Text('${endereco.rua}, ${endereco.numero}'),
        subtitle: Text('${endereco.cidade} - ${endereco.estado}'),
      ),
    ]);
  }

  Widget _buildDinamicaTab() {
    final horarios = _loja.horarios;
    final dias = horarios == null ? <String, String>{} : {
      'Segunda': horarios.segunda, 'Terça': horarios.terca,
      'Quarta': horarios.quarta, 'Quinta': horarios.quinta,
      'Sexta': horarios.sexta, 'Sábado': horarios.sabado, 'Domingo': horarios.domingo,
    };
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(!_lojaConfirmada ? 'Conferindo disponibilidade da loja' : _loja.isAberto ? 'Loja aberta' : 'Loja fechada'),
      if (_erroLoja) BannerErroInline(mensagem: 'Não foi possível conferir a disponibilidade.', aoTentarNovamente: _atualizarLoja),
      const SizedBox(height: 16),
      const Text('Horários de funcionamento', style: TextStyle(fontWeight: FontWeight.bold)),
      if (dias.isEmpty) const Text('A loja ainda não informou os horários.'),
      for (final dia in dias.entries) ListTile(title: Text(dia.key), trailing: Text(dia.value)),
    ]);
  }

  Future<void> _carregarProdutos() async {
    if (_carregandoProdutos || !_temMais) return;
    setState(() {
      _carregandoProdutos = true;
      _erroProdutos = null;
    });
    try {
      final pagina = await _produtoRepository.buscarPaginaPorLoja(
        _loja.id,
        page: _pagina,
      );
      if (!mounted) return;
      setState(() {
        final ids = _produtos.map((p) => p.id).toSet();
        _produtos.addAll(pagina.produtos.where((p) => ids.add(p.id)));
        _pagina++;
        _temMais = pagina.temMais;
      });
    } catch (e) {
      if (mounted) setState(() => _erroProdutos = e);
    } finally {
      if (mounted) setState(() => _carregandoProdutos = false);
    }
  }

  final ProdutoRepository _produtoRepository = ProdutoRepository();
  final LojaRepository _lojaRepository = LojaRepository();

  bool _isSeguindo = false;
  int _seguidores = 0;
  bool _carregandoSeguidores = false;
  bool _erroSeguidores = false;
  bool _alterandoSeguir = false;

  @override
  void initState() {
    super.initState();
    _loja = widget.loja;
    WidgetsBinding.instance.addObserver(this);
    _atualizarLoja();
    _carregarAvaliacoes();
    _atualizacaoLoja = Timer.periodic(const Duration(seconds: 30), (_) => _atualizarLoja());
    _tabController = TabController(length: 4, vsync: this);

    _carregarProdutos();
    _carregarSeguidores();
  }

  Future<void> _carregarSeguidores() async {
    if (_carregandoSeguidores) return;
    setState(() {
      _carregandoSeguidores = true;
      _erroSeguidores = false;
    });
    try {
      final auth = context.read<AuthService>();
      final resultado = await Future.wait<Object>([
        _lojaRepository.contarSeguidores(_loja.id),
        if (auth.usuarioId != null)
          _lojaRepository.estaSeguindo(auth.usuarioId!, _loja.id)
        else
          Future.value(false),
      ]);
      if (mounted) {
        setState(() {
          _seguidores = resultado[0] as int;
          _isSeguindo = resultado[1] as bool;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _erroSeguidores = true);
    } finally {
      if (mounted) setState(() => _carregandoSeguidores = false);
    }
  }

  Future<void> _toggleSeguir() async {
    if (_alterandoSeguir || _carregandoSeguidores || _erroSeguidores) return;
    final auth = context.read<AuthService>();
    if (auth.usuarioId == null) {
      context.showError('Faça login para seguir a loja.');
      return;
    }

    setState(() => _alterandoSeguir = true);
    try {
      if (_isSeguindo) {
        await _lojaRepository.deixarDeSeguir(auth.usuarioId!, _loja.id);
        if (mounted) {
          setState(() {
            _isSeguindo = false;
            _seguidores = (_seguidores > 0) ? _seguidores - 1 : 0;
          });
        }
      } else {
        await _lojaRepository.seguirLoja(auth.usuarioId!, _loja.id);
        if (mounted) {
          setState(() {
            _isSeguindo = true;
            _seguidores++;
          });
        }
      }
    } catch (e) {
      if (mounted) context.showError(e.toString());
    } finally {
      if (mounted) setState(() => _alterandoSeguir = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _atualizacaoLoja?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      body: NestedScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
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
                      if (_erroLoja) BannerErroInline(
                        mensagem: 'Não foi possível atualizar a disponibilidade da loja.',
                        aoTentarNovamente: _atualizarLoja,
                      ),
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
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                    unselectedLabelColor: Colors.grey.shade600,
                    unselectedLabelStyle: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 16.sp,
                    ),
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
              _buildEspacoTab(),
              _buildAvaliacoesTab(),
              _buildDinamicaTab(),
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
                      offset: Offset(0, 4.h),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: _loja.imagemUrl.isNotEmpty
                      ? CachedNetworkImageProvider(_loja.imagemUrl)
                      : null,
                  child: _loja.imagemUrl.isEmpty
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
                      _loja.nome,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black45, blurRadius: 4),
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
                          _loja.categoria,
                          const Color(0xFF5D201C),
                        ),
                        Text(
                          _carregandoSeguidores
                              ? "Carregando..."
                              : _erroSeguidores
                                  ? "Seguidores indisponíveis"
                                  : "$_seguidores seguidores",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            shadows: const [
                              Shadow(color: Colors.black45, blurRadius: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _carregandoSeguidores || _alterandoSeguir
                    ? null
                    : _erroSeguidores
                        ? _carregarSeguidores
                        : _toggleSeguir,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isSeguindo ? Colors.white : const Color(0xFFFF6961),
                  foregroundColor:
                      _isSeguindo ? const Color(0xFFFF6961) : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 6.h,
                  ),
                ),
                child: Text(
                  _carregandoSeguidores || _alterandoSeguir
                      ? "..."
                      : _erroSeguidores
                          ? "Tentar novamente"
                          : _isSeguindo
                              ? "Seguindo"
                              : "Seguir",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            _loja.descricao.isNotEmpty
                ? _loja.descricao
                : "Bem-vindo à nossa loja! Confira nossos produtos.",
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
            ),
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
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
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
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(
              "Avaliação",
              (_loja.dadosOperacionais?.avaliacaoMedia ?? 0.0)
                  .toStringAsFixed(1),
              "Média",
              const Color(0xFF5D201C),
            ),
            Container(width: 1, height: 40.h, color: Colors.grey.shade200),
            _buildStatItem(
              "Avaliações",
              "${_loja.dadosOperacionais?.totalAvaliacoes ?? 0}",
              "Total",
              const Color(0xFFFF6961),
            ),
            Container(width: 1, height: 40.h, color: Colors.grey.shade200),
            Tooltip(
              message: 'Percentual positivo dos produtos ainda indisponível.',
              child: _buildStatItem(
                'Produtos',
                '—',
                'Positivo',
                const Color(0xFF5D201C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    String subtitle,
    Color valueColor,
  ) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.sp),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10.sp),
        ),
      ],
    );
  }

  Widget _buildProdutosTab() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Wrap(
              spacing: 8.w,
              runSpacing: 4.h,
              children: [
                NhacFilterChip(
                  label: 'Todos',
                  selected: true,
                  onSelected: () {},
                ),
                const NhacFilterChip(
                  label: 'Em destaque',
                  unavailableReason:
                      'A loja ainda não disponibiliza os destaques.',
                ),
                const NhacFilterChip(
                  label: 'Vendidos',
                  unavailableReason:
                      'A ordenação por vendas ainda não está disponível.',
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          sliver: Builder(
            builder: (context) {
              if (_carregandoProdutos && _produtos.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: LoadingNhac(telaCheia: false, tamanho: 40),
                  ),
                );
              }
              if (_erroProdutos != null && _produtos.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32.w),
                    child: Column(
                      children: [
                        const Text('Não foi possível carregar os produtos.'),
                        TextButton(
                          onPressed: _carregarProdutos,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (_produtos.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.w),
                      child: Text(
                        'Nenhum produto disponível no momento 😥',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                );
              }

              final produtos = _produtos;

              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                  childAspectRatio: 0.70,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final produto = produtos[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            ProdutoDetalhesPage(produto: produto),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          const begin = Offset(0.0, 1.0);
                          const end = Offset.zero;
                          const curve = Curves.easeOutCubic;

                          var tween = Tween(
                            begin: begin,
                            end: end,
                          ).chain(CurveTween(curve: curve));

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
                      lojaFechada: !_lojaConfirmada || !_loja.isAberto,
                    ),
                  );
                }, childCount: produtos.length),
              );
            },
          ),
        ),
        if (_produtos.isNotEmpty && (_temMais || _erroProdutos != null))
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(children: [
                if (_erroProdutos != null)
                  const Text('Não foi possível carregar mais produtos.'),
                TextButton(
                  key: const ValueKey('loja-carregar-mais'),
                  style: ButtonStyle(
                    minimumSize: const WidgetStatePropertyAll(Size(220, 48)),
                    foregroundColor:
                        const WidgetStatePropertyAll(Color(0xFF5D201C)),
                    overlayColor: WidgetStateProperty.resolveWith((states) =>
                        states.contains(WidgetState.focused) ||
                                states.contains(WidgetState.hovered)
                            ? const Color(0x155D201C)
                            : null),
                    side: WidgetStateProperty.resolveWith((states) => states
                            .contains(WidgetState.focused)
                        ? const BorderSide(color: Color(0xFF5D201C), width: 2)
                        : BorderSide.none),
                  ),
                  onPressed: _carregandoProdutos ? null : _carregarProdutos,
                  child: _carregandoProdutos
                      ? Semantics(
                          liveRegion: true,
                          label: 'Carregando mais produtos',
                          child:
                              const LoadingNhac(telaCheia: false, tamanho: 24),
                        )
                      : Text(_erroProdutos != null
                          ? 'Tentar novamente'
                          : 'Carregar mais produtos'),
                ),
              ]),
            ),
          ),
        SliverToBoxAdapter(child: SizedBox(height: 100.h)),
      ],
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
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
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
