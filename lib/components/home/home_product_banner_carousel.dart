import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nhac/globals/app_constants.dart';
import 'package:nhac/models/produto/produtos.dart';
import 'package:nhac/pages/produto_detalhes_page.dart';

/// Destaques do catálogo real. Categorias têm um único dono: HomeCategoryChips.
class HomeProductBannerCarousel extends StatefulWidget {
  final List<ProdutosModel> products;
  final bool isActive;
  const HomeProductBannerCarousel({super.key, this.products = const [], this.isActive = true});
  @override
  State<HomeProductBannerCarousel> createState() => _HomeProductBannerCarouselState();
}

class _HomeProductBannerCarouselState extends State<HomeProductBannerCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.9);
  Timer? _timer;
  int _pagina = 0;
  List<ProdutosModel> get _produtos => widget.products.take(6).toList();
  @override
  void initState() { super.initState(); _iniciar(); }
  @override
  void didUpdateWidget(HomeProductBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final atual = oldWidget.products.take(6).map((p) => p.id).join('|');
    final novo = _produtos.map((p) => p.id).join('|');
    if (atual != novo) {
      _pagina = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(0);
      });
    }
    _iniciar();
  }
  void _iniciar() {
    _timer?.cancel();
    if (!widget.isActive || _produtos.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients || ModalRoute.of(context)?.isCurrent != true ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
          MediaQuery.of(context).disableAnimations) return;
      _controller.animateToPage((_pagina + 1) % _produtos.length,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic);
    });
  }
  @override
  void dispose() { _timer?.cancel(); _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final produtos = _produtos;
    if (produtos.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      SizedBox(height: 200.h, child: Listener(
        onPointerDown: (_) => _timer?.cancel(),
        onPointerUp: (_) => _iniciar(), onPointerCancel: (_) => _iniciar(),
        child: PageView.builder(controller: _controller, itemCount: produtos.length,
          onPageChanged: (value) => setState(() => _pagina = value),
          itemBuilder: (_, index) {
            final p = produtos[index];
            return Padding(padding: EdgeInsets.symmetric(horizontal: 4.w), child: Material(
              color: Colors.white, borderRadius: BorderRadius.circular(20.r), clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ProdutoDetalhesPage(produto: p))),
                child: Semantics(button: true, label: 'Ver ${p.nome}', child: Stack(fit: StackFit.expand, children: [
                  if (p.imagemUrl.isNotEmpty && !AppConstants.e2eMode)
                    CachedNetworkImage(imageUrl: p.imagemUrl, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Center(child: Icon(Icons.restaurant_menu)))
                  else const Center(child: Icon(Icons.restaurant_menu, color: Color(0xFF5D201C), size: 40)),
                  Align(alignment: Alignment.bottomCenter, child: Container(
                    width: double.infinity, color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.nome, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF5D201C), fontWeight: FontWeight.bold)),
                      Text('${p.lojaNome}${p.lojaAberta ? '' : ' • Loja fechada'}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF5D201C))),
                    ]),
                  )),
                ])),
              ),
            ));
          },
        ),
      )),
      if (produtos.length > 1) Padding(padding: const EdgeInsets.only(top: 8), child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(produtos.length, (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 3), width: i == _pagina ? 18 : 6, height: 6,
          decoration: BoxDecoration(color: i == _pagina ? const Color(0xFF5D201C) : Colors.grey,
            borderRadius: BorderRadius.circular(3)),
        )),
      )),
    ]);
  }
}
