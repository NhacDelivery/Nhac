import 'package:nhac/components/estado_com_retry.dart';
import 'package:nhac/components/nhac_filter_chip.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nhac/components/app_notification.dart';
import 'package:nhac/globals/ui_utils.dart';
import 'package:nhac/components/home/home_product_section.dart';
import 'package:nhac/controllers/cart_provider.dart';
import 'package:nhac/models/produto/produtos.dart';
import 'package:nhac/models/loja/lojas.dart';
import 'package:nhac/pages/loja_page.dart';
import 'package:nhac/repositories/produto_repository.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:nhac/repositories/avaliacao_repository.dart';
import 'package:nhac/models/produto/avaliacoes.dart';
import 'package:nhac/e2e/e2e_keys.dart';
import 'package:go_router/go_router.dart';

class _RelatedProducts {
  final List<ProdutosModel> products;
  final Map<String, bool> storesOpen;
  const _RelatedProducts(this.products, this.storesOpen);
}

class ProdutoDetalhesPage extends StatefulWidget {
  final ProdutosModel produto;

  const ProdutoDetalhesPage({super.key, required this.produto});

  @override
  State<ProdutoDetalhesPage> createState() => _ProdutoDetalhesPageState();
}

class _ProdutoDetalhesPageState extends State<ProdutoDetalhesPage> {
  int _quantidade = 1;

  late Future<_RelatedProducts> _produtosRelacionadosFuture;
  Future<LojasModel?>? _lojaFuture;
  Future<List<ProdutosModel>>? _produtosDaLojaFuture;

  final _produtoRepository = ProdutoRepository();
  final _lojaRepository = LojaRepository();
  final _avaliacaoRepository = AvaliacaoRepository();

  late Future<
          ({Map<String, dynamic>? resumo, List<AvaliacoesModel>? comentarios})>
      _avaliacoesFuture;

  @override
  void initState() {
    super.initState();

    _produtosRelacionadosFuture = _buscarRelacionados();

    _lojaFuture = widget.produto.lojaId.isNotEmpty
        ? _lojaRepository.buscarLoja(widget.produto.lojaId)
        : Future.value(null);
    _produtosDaLojaFuture = null;

    _avaliacoesFuture = _carregarAvaliacoes();
  }

  Future<({Map<String, dynamic>? resumo, List<AvaliacoesModel>? comentarios})>
      _carregarAvaliacoes() async {
    Map<String, dynamic>? resumo;
    List<AvaliacoesModel>? comentarios;
    await Future.wait([
      () async {
        try {
          resumo = await _avaliacaoRepository
              .buscarResumoAvaliacoes(widget.produto.id);
        } catch (_) {}
      }(),
      () async {
        try {
          comentarios = await _avaliacaoRepository
              .buscarAvaliacoes(widget.produto.lojaId);
        } catch (_) {}
      }(),
    ]);
    return (resumo: resumo, comentarios: comentarios);
  }

  Future<_RelatedProducts> _buscarRelacionados() async {
    final products = await _produtoRepository.buscarPorCategoria(
      widget.produto.categoriaMenu,
    );
    final stores = [
      for (final p in products) MapEntry(p.lojaId, p.lojaAberta),
    ];
    return _RelatedProducts(
      products
          .where(
            (p) => p.id != widget.produto.id && p.lojaAberta,
          )
          .toList(),
      Map.fromEntries(stores),
    );
  }

  void _mostrarMaisOpcoes() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copiar link do produto'),
              onTap: () async {
                Navigator.pop(ctx);
                await Clipboard.setData(
                  ClipboardData(
                    text: 'https://nhac.app/produto/${widget.produto.id}',
                  ),
                );
                if (mounted) context.showSuccess('Link copiado.');
              },
            ),
            if (widget.produto.lojaId.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Perguntar à loja sobre este produto'),
                onTap: () {
                  Navigator.pop(ctx);
                  _abrirChat();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirChat() async {
    if (widget.produto.lojaId.isEmpty) return;
    try {
      final loja = await _lojaFuture;
      if (!mounted) return;
      if (loja == null) {
        context.showError('Não foi possível abrir a conversa com esta loja.');
        return;
      }
      context.push(
        '/chat-loja',
        extra: {
          'lojaId': loja.id,
          'lojaNome': loja.nome,
          'produto': widget.produto,
        },
      );
    } catch (_) {
      if (mounted) {
        context.showError('Não foi possível abrir a conversa com esta loja.');
      }
    }
  }

  void _incrementarQuantidade() {
    setState(() {
      _quantidade++;
    });
  }

  void _decrementarQuantidade() {
    if (_quantidade > 1) {
      setState(() {
        _quantidade--;
      });
    }
  }

  bool _isNavigatingToLoja = false;

  void _abrirLojaProfile() async {
    if (_isNavigatingToLoja || _lojaFuture == null) return;

    dynamic loja;
    try {
      loja = await _lojaFuture;
    } catch (e) {
      if (mounted) {
        context.showError('Não foi possível carregar os dados da loja.');
      }
      return;
    }

    if (loja == null) return;

    setState(() {
      _isNavigatingToLoja = true;
    });

    if (!mounted) return;

    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            LojaPage(loja: loja),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );

    if (mounted) {
      setState(() {
        _isNavigatingToLoja = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.height * 0.45,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                leading: Padding(
                  padding: EdgeInsets.all(8.w),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: const Color(0xFF5D201C),
                        size: 20.r,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: EdgeInsets.all(8.w),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.share_outlined,
                          color: const Color(0xFF5D201C),
                          size: 20.r,
                        ),
                        onPressed: () {
                          // Mudou de uid para id
                          final link =
                              'https://nhac.app/produto/${widget.produto.id}';
                          Share.share(
                            'Confira este produto no Nhac!\n\n'
                            '${widget.produto.nome}\n'
                            'Por R\$ ${widget.produto.preco.toStringAsFixed(2).replaceAll('.', ',')}\n\n'
                            '$link',
                            subject: widget.produto.nome,
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.w),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.more_horiz,
                          color: const Color(0xFF5D201C),
                          size: 20.r,
                        ),
                        onPressed: _mostrarMaisOpcoes,
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Hero(
                    tag: 'produto_${widget.produto.id}', // Mudou de uid para id
                    child: widget.produto.imagemUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.produto.imagemUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFFF5F5F5),
                              child: const Center(
                                child: LoadingNhac(
                                  telaCheia: false,
                                  tamanho: 40,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFFF5F5F5),
                              child: Icon(
                                Icons.fastfood,
                                size: 80.r,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFF5F5F5),
                            child: Icon(
                              Icons.fastfood,
                              size: 80.r,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24.r),
                      topRight: Radius.circular(24.r),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 10.h),
                        child: Text(
                          widget.produto.nome,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF5D201C),
                            height: 1.3,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.end,
                          alignment: WrapAlignment.center,
                          spacing: 8.w,
                          runSpacing: 4.h,
                          children: [
                            Text(
                              currencyFormat.format(widget.produto.preco),
                              style: TextStyle(
                                fontSize: 42.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFFF6961),
                                letterSpacing: -1.5,
                                shadows: const [
                                  Shadow(
                                    offset: Offset(-0.8, -0.8),
                                    color: Color(0xFFFF6961),
                                  ),
                                  Shadow(
                                    offset: Offset(0.8, -0.8),
                                    color: Color(0xFFFF6961),
                                  ),
                                  Shadow(
                                    offset: Offset(0.8, 0.8),
                                    color: Color(0xFFFF6961),
                                  ),
                                  Shadow(
                                    offset: Offset(-0.8, 0.8),
                                    color: Color(0xFFFF6961),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9F9),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Column(
                            children: [
                              _buildServiceRow(
                                Icons.bolt,
                                'Envio imediato após a compra',
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: const Divider(
                                  height: 1,
                                  color: Color(0xFFEEEEEE),
                                ),
                              ),
                              _buildServiceRow(
                                Icons.check_circle_outline,
                                'Garantia de reembolso em caso de problemas',
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: const Divider(
                                  height: 1,
                                  color: Color(0xFFEEEEEE),
                                ),
                              ),
                              FutureBuilder<LojasModel?>(
                                future: _lojaFuture,
                                builder: (context, snapshot) {
                                  String nomeLoja = 'Loja Parceira';
                                  if (snapshot.connectionState ==
                                      ConnectionState.done) {
                                    if (snapshot.hasData &&
                                        snapshot.data != null) {
                                      nomeLoja = snapshot.data!.nome;
                                    } else {
                                      // Busca terminou sem retornar a loja
                                      // (ex.: indisponível/fechada no
                                      // backend). Deixamos isso explícito em
                                      // vez de manter o placeholder genérico
                                      // indefinidamente.
                                      nomeLoja = 'indisponível no momento';
                                    }
                                  }
                                  return _buildServiceRow(
                                    Icons.storefront_outlined,
                                    'Vendido por: $nomeLoja',
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Detalhes do Produto',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF5D201C),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Text(
                          widget.produto.descricao.isNotEmpty
                              ? widget.produto.descricao
                              : 'Este produto é preparado com ingredientes frescos e selecionados. Perfeito para qualquer momento do dia.',
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: Colors.black54,
                            height: 1.5,
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      _buildReviewsSection(),
                      _buildStoreProfileSection(),
                      SizedBox(height: 24.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Quantidade',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF5D201C),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(30.r),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: _decrementarQuantidade,
                                    icon: Icon(
                                      Icons.remove,
                                      size: 20.r,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 40.w,
                                    child: Text(
                                      '$_quantidade',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _incrementarQuantidade,
                                    icon: Icon(
                                      Icons.add,
                                      size: 20.r,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: FutureBuilder<_RelatedProducts>(
                          future: _produtosRelacionadosFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox.shrink();
                            }

                            if (snapshot.hasError) {
                              return BannerErroInline(
                                mensagem: 'Não foi possível carregar os produtos relacionados.',
                                aoTentarNovamente: () async {
                                  setState(() => _produtosRelacionadosFuture = _buscarRelacionados());
                                  try { await _produtosRelacionadosFuture; } catch (_) {}
                                },
                              );
                            }
                            if (!snapshot.hasData ||
                                snapshot.data!.products.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            final produtosRelacionados =
                                snapshot.data!.products.take(5).toList();

                            if (produtosRelacionados.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return HomeProductSection(
                              title: 'Produtos Relacionados',
                              products: produtosRelacionados,
                              lojaAberta: snapshot.data!.storesOpen,
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 100.w + bottomPadding),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 16.w,
                right: 16.w,
                top: 12.h,
                bottom: bottomPadding > 0 ? bottomPadding : 12.h,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5D201C).withValues(alpha: 0.05),
                    blurRadius: 10.r,
                    offset: Offset(0, -5.h),
                  ),
                ],
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: _abrirChat,
                    child: _buildIconAction(
                      Icons.chat_bubble_outline,
                      'Chat',
                      '',
                    ),
                  ),
                  SizedBox(width: 24.w),
                  Expanded(
                    child: FutureBuilder<LojasModel?>(
                      future: _lojaFuture,
                      builder: (context, lojaSnapshot) {
                        final loja = lojaSnapshot.data;
                        final aindaCarregando = lojaSnapshot.connectionState !=
                            ConnectionState.done;
                        final erroLoja = !aindaCarregando &&
                            (lojaSnapshot.hasError || loja == null);
                        final lojaFechada = loja != null && !loja.isAberto;
                        return ElevatedButton(
                          key: E2EKeys.productAdd,
                          onPressed: aindaCarregando
                              ? null
                              : erroLoja
                                  ? () => setState(() {
                                        _lojaFuture = _lojaRepository
                                            .buscarLoja(widget.produto.lojaId);
                                      })
                                  : lojaFechada
                                      ? () {
                                          context.showError(
                                            'Esta loja está fechada no momento.',
                                          );
                                        }
                                      : () async {
                                          try {
                                            final cartProvider =
                                                Provider.of<CartProvider>(
                                              context,
                                              listen: false,
                                            );
                                            await cartProvider
                                                .adicionarItemComQuantidade(
                                              idProduto: widget.produto.id,
                                              nome: widget.produto.nome,
                                              preco: widget.produto.preco,
                                              imagemUrl:
                                                  widget.produto.imagemUrl,
                                              lojaId: widget.produto.lojaId,
                                              quantidade: _quantidade,
                                            );
                                            if (context.mounted) {
                                              showAppNotification(
                                                context,
                                                type: NotificationType.success,
                                                imageUrl:
                                                    widget.produto.imagemUrl,
                                                message:
                                                    '$_quantidade x ${widget.produto.nome}',
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              context.showError(
                                                e.toString().replaceAll(
                                                      'Exception: ',
                                                      '',
                                                    ),
                                              );
                                            }
                                          }
                                        },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: lojaFechada
                                ? Colors.grey.shade400
                                : const Color(0xFFFF6961),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50.r),
                            ),
                          ),
                          child: Text(
                            aindaCarregando
                                ? 'Carregando...'
                                : erroLoja
                                    ? 'Loja indisponível. Tentar novamente'
                                    : lojaFechada
                                        ? 'Loja fechada'
                                        : 'Adicionar  ${currencyFormat.format(widget.produto.preco * _quantidade)}',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 25.w,
            top: 0,
            bottom: 0,
            width: 150.w,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! < -300) {
                  _abrirLojaProfile();
                }
              },
              onHorizontalDragUpdate: (details) {
                if (details.delta.dx < -8) {
                  _abrirLojaProfile();
                }
              },
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20.r, color: const Color(0xFF888888)),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFF555555)),
          ),
        ),
        Icon(Icons.chevron_right, size: 20.r, color: const Color(0xFFCCCCCC)),
      ],
    );
  }

  Widget _buildIconAction(
    IconData icon,
    String label,
    String count, {
    Color? iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24.r, color: iconColor ?? const Color(0xFF666666)),
        SizedBox(height: 4.h),
        Text(
          count.isNotEmpty ? count : label,
          style: TextStyle(fontSize: 11.sp, color: const Color(0xFF888888)),
        ),
      ],
    );
  }

  Widget _buildReviewHeading(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0EE),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(icon, color: const Color(0xFFFF6961), size: 20.r),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF5D201C),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCaption(String text) => Padding(
        padding: EdgeInsets.only(top: 8.h, bottom: 12.h),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.sp,
            height: 1.5,
            color: const Color(0xFF80635F),
          ),
        ),
      );

  Widget _buildReviewsSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: FutureBuilder<
          ({Map<String, dynamic>? resumo, List<AvaliacoesModel>? comentarios})>(
        future: _avaliacoesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingNhac(telaCheia: false, tamanho: 40);
          }
          final resumo = snapshot.data?.resumo;
          final comentarios = snapshot.data?.comentarios;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReviewHeading(
                'Avaliações do produto',
                Icons.star_outline_rounded,
              ),
              SizedBox(height: 12.h),
              if (resumo == null)
                BannerErroInline(
                  mensagem: 'Não foi possível consultar a nota deste produto.',
                  aoTentarNovamente: () => setState(
                    () => _avaliacoesFuture = _carregarAvaliacoes(),
                  ),
                )
              else if ((resumo['total'] as num) == 0)
                _buildReviewCaption(
                  'Este produto ainda não recebeu avaliações.',
                )
              else
                _buildRatingSummary(
                  (resumo['media'] as num).toDouble(),
                  (resumo['total'] as num).toInt(),
                ),
              Wrap(
                spacing: 8.w,
                runSpacing: 4.h,
                children: [
                  NhacFilterChip(
                    label: 'Tudo',
                    selected: true,
                    onSelected: () {},
                  ),
                  const NhacFilterChip(
                    label: 'Com fotos',
                    unavailableReason:
                        'Fotos das avaliações ainda não estão disponíveis.',
                  ),
                  const NhacFilterChip(
                    label: 'Positivas',
                    unavailableReason:
                        'O filtro por avaliações do produto ainda não está disponível.',
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              _buildReviewHeading(
                'Comentários recentes da loja',
                Icons.chat_bubble_outline_rounded,
              ),
              _buildReviewCaption('Experiências em pedidos desta loja.'),
              if (comentarios == null)
                BannerErroInline(
                  mensagem: 'Não foi possível carregar os comentários da loja.',
                  aoTentarNovamente: () => setState(
                    () => _avaliacoesFuture = _carregarAvaliacoes(),
                  ),
                )
              else if (comentarios.isEmpty)
                _buildReviewCaption('A loja ainda não recebeu comentários.')
              else
                ...comentarios.take(3).map(
                      (avaliacao) => _buildReviewItem(
                        name: avaliacao.nomeUsuario.trim().isNotEmpty
                            ? avaliacao.nomeUsuario
                            : 'Anônimo',
                        review: avaliacao.comentario,
                        date: avaliacao.criadoEm ?? '',
                        positive: avaliacao.nota >= 4,
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReviewItem({
    required String name,
    required String review,
    required String date,
    required bool positive,
  }) {
    final parsedDate = DateTime.tryParse(date);
    final formattedDate = parsedDate == null
        ? ''
        : DateFormat('dd/MM/yyyy').format(parsedDate.toLocal());
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFFFE7E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16.r,
                backgroundColor: const Color(0xFFFFF0EE),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 20.r,
                  color: const Color(0xFFFF6961),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5D201C),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EE),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  positive ? 'Positiva' : 'Feedback',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5D201C),
                  ),
                ),
              ),
            ],
          ),
          if (review.trim().isNotEmpty) ...[
            SizedBox(height: 12.h),
            Text(
              review,
              style: TextStyle(
                fontSize: 14.sp,
                height: 1.5,
                color: const Color(0xFF5D201C),
              ),
            ),
          ],
          if (formattedDate.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              formattedDate,
              style: TextStyle(fontSize: 11.sp, color: const Color(0xFF80635F)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStoreProfileSection() {
    if (_lojaFuture == null) return const SizedBox.shrink();

    return FutureBuilder<LojasModel?>(
      future: _lojaFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final loja = snapshot.data!;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5D201C).withValues(alpha: 0.05),
                blurRadius: 10.r,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LojaPage(loja: loja),
                    ),
                  );
                },
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24.r),
                      child: loja.imagemUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: loja.imagemUrl,
                              width: 48.r,
                              height: 48.r,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 48.r,
                              height: 48.r,
                              color: Colors.grey.shade200,
                              child: Icon(Icons.store, color: Colors.grey),
                            ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loja.nome,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF5D201C),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            loja.categoria,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Icon(Icons.star, size: 14.r, color: const Color(0xFF5D201C)),
                  SizedBox(width: 4.w),
                  Text(
                    '${(loja.dadosOperacionais?.avaliacaoMedia ?? 0.0).toStringAsFixed(1)} • Total de avaliações: ${loja.dadosOperacionais?.totalAvaliacoes ?? 0}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF5D201C),
                    ),
                  ),
                ],
              ),
              if (_produtosDaLojaFuture != null) ...[
                SizedBox(height: 16.h),
                FutureBuilder<List<ProdutosModel>>(
                  future: _produtosDaLojaFuture,
                  builder: (context, prodSnapshot) {
                    if (!prodSnapshot.hasData || prodSnapshot.data!.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final produtosLoja = prodSnapshot.data!
                        .where((p) => p.id != widget.produto.id)
                        .take(10)
                        .toList();

                    if (produtosLoja.isEmpty) return const SizedBox.shrink();

                    return SizedBox(
                      height: 140.h,
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        itemCount: produtosLoja.length,
                        separatorBuilder: (_, __) => SizedBox(width: 12.w),
                        itemBuilder: (context, index) {
                          final prod = produtosLoja[index];
                          final currencyFormat = NumberFormat.currency(
                            locale: 'pt_BR',
                            symbol: 'R\$',
                          );
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ProdutoDetalhesPage(produto: prod),
                                ),
                              );
                            },
                            child: SizedBox(
                              width: 100.w,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12.r),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          prod.imagemUrl.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: prod.imagemUrl,
                                                  fit: BoxFit.cover,
                                                )
                                              : Container(
                                                  color: Colors.grey.shade200,
                                                  child: Icon(
                                                    Icons.fastfood,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 6.w,
                                                vertical: 4.h,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [
                                                    Colors.black.withValues(
                                                      alpha: 0.7,
                                                    ),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                              child: Text(
                                                currencyFormat.format(
                                                  prod.preco,
                                                ),
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11.sp,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    prod.nome,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF5D201C),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRatingSummary(double avaliacao, int total) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFFFE7E5)),
      ),
      child: Row(
        children: [
          Text(
            avaliacao.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 36.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF5D201C),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 2.w,
                  children: List.generate(
                    5,
                    (index) => Icon(
                      avaliacao >= index + 1
                          ? Icons.star_rounded
                          : avaliacao >= index + 0.5
                              ? Icons.star_half_rounded
                              : Icons.star_outline_rounded,
                      size: 20.r,
                      color: const Color(0xFFFF6961),
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  '$total ${total == 1 ? "avaliação" : "avaliações"} do produto',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF80635F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
