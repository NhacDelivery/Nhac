import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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

class ProdutoDetalhesPage extends StatefulWidget {
  final ProdutosModel produto;

  const ProdutoDetalhesPage({super.key, required this.produto});

  @override
  State<ProdutoDetalhesPage> createState() => _ProdutoDetalhesPageState();
}

class _ProdutoDetalhesPageState extends State<ProdutoDetalhesPage> {
  int _quantidade = 1;
  
  late Future<List<ProdutosModel>> _produtosRelacionadosFuture;
  Future<LojasModel?>? _lojaFuture;
  Future<List<ProdutosModel>>? _produtosDaLojaFuture;

  final _produtoRepository = ProdutoRepository();
  final _lojaRepository = LojaRepository();
  final _avaliacaoRepository = AvaliacaoRepository();

  late Future<Map<String, dynamic>> _resumoAvaliacoesFuture;
  late Future<List<AvaliacoesModel>> _avaliacoesFuture;

  @override
  void initState() {
    super.initState();
    
    _produtosRelacionadosFuture = _produtoRepository.buscarPorCategoria(widget.produto.categoriaMenu);

    _lojaFuture = widget.produto.lojaId.isNotEmpty
        ? _lojaRepository.buscarLoja(widget.produto.lojaId)
        : Future.value(null);
    _produtosDaLojaFuture = null;

    _resumoAvaliacoesFuture = _avaliacaoRepository.buscarResumoAvaliacoes(widget.produto.id);
    _avaliacoesFuture = _avaliacaoRepository.buscarAvaliacoes(widget.produto.lojaId);
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
        pageBuilder: (context, animation, secondaryAnimation) => LojaPage(loja: loja),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(position: animation.drive(tween), child: child);
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
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
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
                      icon: Icon(Icons.arrow_back_ios_new,
                          color: const Color(0xFF5D201C), size: 20.r),
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
                        icon: Icon(Icons.share_outlined,
                            color: const Color(0xFF5D201C), size: 20.r),
                        onPressed: () {
                          // Mudou de uid para id
                          final link = 'https://nhac.app/produto/${widget.produto.id}';
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
                        icon: Icon(Icons.more_horiz,
                            color: const Color(0xFF5D201C), size: 20.r),
                        onPressed: () {},
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
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFF6961)),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFFF5F5F5),
                              child: Icon(Icons.fastfood,
                                  size: 80.r, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFF5F5F5),
                            child: Icon(Icons.fastfood,
                                size: 80.r, color: Colors.grey),
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
                        padding:
                            EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 10.h),
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
                                  Shadow(offset: Offset(-0.8, -0.8),
                                      color: Color(0xFFFF6961)),
                                  Shadow(offset: Offset(0.8, -0.8),
                                      color: Color(0xFFFF6961)),
                                  Shadow(offset: Offset(0.8, 0.8),
                                      color: Color(0xFFFF6961)),
                                  Shadow(offset: Offset(-0.8, 0.8),
                                      color: Color(0xFFFF6961)),
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
                                  Icons.bolt, 'Envio imediato após a compra'),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: const Divider(
                                    height: 1, color: Color(0xFFEEEEEE)),
                              ),
                              _buildServiceRow(Icons.check_circle_outline,
                                  'Garantia de reembolso em caso de problemas'),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: const Divider(
                                    height: 1, color: Color(0xFFEEEEEE)),
                              ),
                              FutureBuilder<LojasModel?>(
                                future: _lojaFuture,
                                builder: (context, snapshot) {
                                  String nomeLoja = 'Loja Parceira';
                                  if (snapshot.connectionState == ConnectionState.done) {
                                    if (snapshot.hasData && snapshot.data != null) {
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
                                      'Vendido por: $nomeLoja');
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
                                border: Border.all(
                                    color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(30.r),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: _decrementarQuantidade,
                                    icon: Icon(Icons.remove,
                                        size: 20.r, color: Colors.black54),
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
                                    icon: Icon(Icons.add,
                                        size: 20.r, color: Colors.black54),
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
                        child: FutureBuilder<List<ProdutosModel>>(
                          future: _produtosRelacionadosFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                              return const SizedBox.shrink();
                            }

                            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            final produtosRelacionados = snapshot.data!
                                .where((p) => p.id != widget.produto.id)
                                .take(5)
                                .toList();

                            if (produtosRelacionados.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return HomeProductSection(
                              title: 'Produtos Relacionados',
                              products: produtosRelacionados,
                              onSeeAll: () {},
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

                  _buildIconAction(Icons.chat_bubble_outline, 'Chat', ''),
                  SizedBox(width: 24.w),
                  Expanded(
                    child: FutureBuilder<LojasModel?>(
                      future: _lojaFuture,
                      builder: (context, lojaSnapshot) {
                        final loja = lojaSnapshot.data;
                        final aindaCarregando =
                            lojaSnapshot.connectionState != ConnectionState.done;
                        final lojaFechada =
                            aindaCarregando || loja == null || !loja.isAberto;
                        return ElevatedButton(
                          key: E2EKeys.productAdd,
                      onPressed: aindaCarregando
                          ? null
                          : lojaFechada
                          ? () {
                              context.showError('Esta loja está fechada no momento.');
                            }
                          : () async {
                        try {
                          final cartProvider = Provider.of<CartProvider>(context, listen: false);
                          await cartProvider.adicionarItemComQuantidade(
                            idProduto: widget.produto.id, 
                            nome: widget.produto.nome,
                            preco: widget.produto.preco,
                            imagemUrl: widget.produto.imagemUrl,
                            lojaId: widget.produto.lojaId,
                            quantidade: _quantidade,
                          );
                          if (context.mounted) {
                            showAppNotification(
                              context,
                              type: NotificationType.success,
                              imageUrl: widget.produto.imagemUrl,
                              message: '$_quantidade x ${widget.produto.nome}',
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            context.showError(e.toString().replaceAll('Exception: ', ''));
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
                if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
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
            style: TextStyle(
              fontSize: 14.sp,
              color: const Color(0xFF555555),
            ),
          ),
        ),
        Icon(Icons.chevron_right, size: 20.r, color: const Color(0xFFCCCCCC)),
      ],
    );
  }

  Widget _buildIconAction(IconData icon, String label, String count, {Color? iconColor}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24.r, color: iconColor ?? const Color(0xFF666666)),
        SizedBox(height: 4.h),
        Text(
          count.isNotEmpty ? count : label,
          style: TextStyle(
            fontSize: 11.sp,
            color: const Color(0xFF888888),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FutureBuilder<Map<String, dynamic>>(
                future: _resumoAvaliacoesFuture,
                builder: (context, snapshot) {
                  final total = snapshot.data?['total'] ?? 0;
                  return Text(
                    'Avaliações do Produto ($total)',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5D201C),
                    ),
                  );
                }
              ),
              Row(
                children: [
                  Text(
                    'Ver todas',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.black54,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20.r, color: Colors.black54),
                ],
              ),
            ],
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _resumoAvaliacoesFuture,
            builder: (context, snapshot) {
              double rating = 0.0;
              int total = 0;
              if (snapshot.hasData && snapshot.data != null) {
                rating = (snapshot.data!['media'] ?? 0).toDouble();
                total = snapshot.data!['total'] ?? 0;
              }
              return _buildRatingSummary(rating, total);
            }
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _buildReviewFilterTag('Tudo', isSelected: true),
              SizedBox(width: 8.w),
              _buildReviewFilterTag('Com fotos 0'),
              SizedBox(width: 8.w),
              _buildReviewFilterTag('Positivas 0', icon: Icons.thumb_up_alt),
            ],
          ),
          SizedBox(height: 20.h),
          FutureBuilder<List<AvaliacoesModel>>(
            future: _avaliacoesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) return Text('Sem avaliações ainda.', style: TextStyle(color: Colors.grey.shade600));

              return Column(
                children: snapshot.data!.take(3).map((avaliacao) {
                  return _buildReviewItem(
                    name: avaliacao.nomeUsuario.trim().isNotEmpty
                        ? avaliacao.nomeUsuario
                        : 'Anônimo',
                    avatarColor: Colors.brown.shade200,
                    avatarIcon: Icons.person,
                    review: avaliacao.comentario,
                    date: avaliacao.criadoEm ?? '',
                    location: '',
                    tag: avaliacao.nota >= 4 ? 'Positiva' : 'Feedback',
                  );
                }).toList(),
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildReviewFilterTag(String text, {bool isSelected = false, IconData? icon}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFF6961) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14.r, color: isSelected ? Colors.white : Colors.black54),
            SizedBox(width: 4.w),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem({
    required String name,
    required Color avatarColor,
    required IconData avatarIcon,
    required String review,
    required String date,
    required String location,
    required String tag,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16.r,
                backgroundColor: avatarColor,
                child: Icon(avatarIcon, size: 20.r, color: Colors.white),
              ),
              SizedBox(width: 8.w),
              Text(
                name,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.black54,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5E5),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.thumb_up_alt, size: 12.r, color: Colors.orange),
                    SizedBox(width: 4.w),
                    Text(
                      tag,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            review,
            style: TextStyle(
              fontSize: 15.sp,
              color: const Color(0xFF5D201C),
              height: 1.4,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '$date  $location',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.black38,
            ),
          ),
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
                          final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProdutoDetalhesPage(produto: prod),
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
                                                  child: Icon(Icons.fastfood, color: Colors.grey),
                                                ),
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [
                                                    Colors.black.withValues(alpha: 0.7),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                              child: Text(
                                                currencyFormat.format(prod.preco),
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
      margin: EdgeInsets.symmetric(vertical: 16.h),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    avaliacao.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 42.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF5D201C),
                      height: 1,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(Icons.star, size: 24.r, color: const Color(0xFF5D201C)),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Text(
                    '$total Avaliações',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(Icons.info_outline, size: 14.r, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
          SizedBox(width: 24.w),
          Expanded(
            child: Column(
              children: [
                _buildRatingBarRow(5, 0.8),
                SizedBox(height: 4.h),
                _buildRatingBarRow(4, 0.4),
                SizedBox(height: 4.h),
                _buildRatingBarRow(3, 0.2),
                SizedBox(height: 4.h),
                _buildRatingBarRow(2, 0.05),
                SizedBox(height: 4.h),
                _buildRatingBarRow(1, 0.1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBarRow(int starCount, double percentage) {
    return Row(
      children: [
        SizedBox(
          width: 45.w,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: List.generate(
              5,
              (index) => Icon(
                Icons.star,
                size: 8.r,
                color: index < starCount ? const Color(0xFF5D201C) : Colors.transparent,
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Container(
            height: 6.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF5D201C),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
