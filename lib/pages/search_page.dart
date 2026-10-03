import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/produto/produtos.dart';
import '../models/loja/lojas.dart';
import '../components/product_card.dart';
import '../components/estado_com_retry.dart';
import '../repositories/produto_repository.dart';
import '../repositories/loja_repository.dart';
import '../services/local_cache_service.dart';
import 'produto_detalhes_page.dart';
import 'loja_page.dart';

// Paleta oficial do app (ver globals/themes.dart e product_card.dart)
const Color _corPrimaria = Color(0xFFFF6961);
const Color _corTexto = Color(0xFF5D201C);
const Color _corAccentClaro = Color(0xFFFFF0EE);

enum _FiltroBusca { tudo, produtos, lojas }

class _ResultadoBusca {
  final List<ProdutosModel> produtos;
  final List<LojasModel> lojas;
  final Map<String, bool> lojaAberta; // lojaId -> está aberta?
  _ResultadoBusca({
    required this.produtos,
    required this.lojas,
    this.lojaAberta = const {},
  });

  bool get vazio => produtos.isEmpty && lojas.isEmpty;
}

class SearchPage extends StatefulWidget {
  final String? initialCategory;
  final ProdutoRepository? produtoRepository;
  final LojaRepository? lojaRepository;

  const SearchPage({
    super.key,
    this.initialCategory,
    this.produtoRepository,
    this.lojaRepository,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // Valores devem bater exatamente com a coluna `categoria_menu` do banco,
  // já que o backend filtra produtos/lojas por valor exato.
  static const _categoriasSugeridas = [
    {'nome': 'Combos', 'icon': Icons.fastfood_rounded},
    {'nome': 'Pratos Executivos', 'icon': Icons.restaurant_rounded},
    {'nome': 'Acompanhamentos', 'icon': Icons.rice_bowl_rounded},
    {'nome': 'Sobremesas', 'icon': Icons.icecream_rounded},
    {'nome': 'Bebidas', 'icon': Icons.local_drink_rounded},
  ];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late final ProdutoRepository _produtoRepository;
  late final LojaRepository _lojaRepository;

  _FiltroBusca _filtro = _FiltroBusca.tudo;
  List<String> _historico = [];
  bool _temTexto = false;

  // Estado para stale-while-revalidate
  _ResultadoBusca? _ultimoResultado;
  EstadoConteudo _estadoBusca = EstadoConteudo.conteudo;
  String? _ultimoErro;
  String? _termoAtual;
  Timer? _debounce;
  int _versaoBusca = 0;
  bool _buscaCategoria = false;

  @override
  void initState() {
    super.initState();
    _produtoRepository = widget.produtoRepository ?? ProdutoRepository();
    _lojaRepository = widget.lojaRepository ?? LojaRepository();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();

    _carregarHistorico();
    _searchController.addListener(() {
      final temTexto = _searchController.text.isNotEmpty;
      if (temTexto != _temTexto) setState(() => _temTexto = temTexto);
    });
    _searchFocus.addListener(() => setState(() {}));
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _searchController.text = widget.initialCategory!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _buscarPorCategoriaInicial(widget.initialCategory!);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _searchFocus.requestFocus();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animationController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Widget _buildAnimatedItem(Widget child, int index) {
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          (index * 0.1).clamp(0.0, 1.0),
          (index * 0.1 + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  Future<void> _carregarHistorico() async {
    final historico = await LocalCacheService.carregarHistoricoPesquisa();
    if (mounted) setState(() => _historico = historico);
  }

  Future<void> _salvarNoHistorico(String termo) async {
    final atualizado = List<String>.from(_historico)
      ..removeWhere((t) => t.toLowerCase() == termo.toLowerCase())
      ..insert(0, termo);
    final limitado = atualizado.take(8).toList();
    setState(() => _historico = limitado);
    await LocalCacheService.salvarHistoricoPesquisa(limitado);
  }

  void _buscarPorCategoriaInicial(String categoria) {
    if (categoria.isEmpty) return;
    _debounce?.cancel();
    _versaoBusca++;
    _buscaCategoria = true;
    _ultimoResultado = null;
    _animationController.forward(from: 0.0);
    setState(() {
      _filtro = _FiltroBusca.tudo;
      _termoAtual = categoria;
      _estadoBusca = EstadoConteudo.loading;
    });
    _buscarCategoriaComCache(categoria);
  }

  /// Busca por categoria com suporte a stale-while-revalidate
  Future<void> _buscarCategoriaComCache(String categoria) async {
    final versao = _versaoBusca;
    final cache = await LocalCacheService.carregarResultadosBusca(
      'categoria:$categoria',
    );
    if (!mounted || versao != _versaoBusca) return;
    if (cache != null) {
      final produtos = (cache['produtos'] as List)
          .map(
            (p) => ProdutosModel.fromMap(Map<String, dynamic>.from(p as Map)),
          )
          .toList();

      if (!mounted || versao != _versaoBusca) return;
      _ultimoResultado = _ResultadoBusca(
        produtos: produtos,
        lojas: const [],
        lojaAberta: _statusDasLojas(produtos),
      );
      _estadoBusca = _ultimoResultado!.vazio
          ? EstadoConteudo.vazio
          : EstadoConteudo.conteudo;
      setState(() {});
    }

    try {
      final produtos = await _produtoRepository.buscarPorCategoria(categoria);
      if (!mounted || versao != _versaoBusca) return;

      _ultimoResultado = _ResultadoBusca(
        produtos: produtos,
        lojas: const [],
        lojaAberta: _statusDasLojas(produtos),
      );
      _estadoBusca = _ultimoResultado!.vazio
          ? EstadoConteudo.vazio
          : EstadoConteudo.conteudo;
      setState(() {});
      _ultimoErro = null;
      LocalCacheService.salvarResultadosBusca(
        'categoria:$categoria',
        produtos: produtos,
        lojas: const [],
        lojaAberta: _statusDasLojas(produtos),
      ).catchError(
          (Object e) => debugPrint('Falha ao salvar categoria local: $e'));
    } catch (e) {
      if (!mounted || versao != _versaoBusca) return;
      if (_ultimoResultado != null) {
        _estadoBusca = EstadoConteudo.erro;
      } else {
        _estadoBusca = EstadoConteudo.erro;
        _ultimoResultado = null;
      }
      _ultimoErro = 'Não foi possível carregar a pesquisa. Tente novamente.';
      setState(() {});
    }
  }

  /// Constrói o mapa de status aberta/fechada a partir do campo `lojaAberta`
  /// que já vem em cada produto na resposta de `/produtos`.
  /// Substitui a versão anterior que fazia N chamadas `GET /lojas/{id}`.
  Map<String, bool> _statusDasLojas(List<ProdutosModel> produtos) {
    return {
      for (final p in produtos)
        if (p.lojaId.isNotEmpty) p.lojaId: p.lojaAberta,
    };
  }

  /// Busca unificada: produtos por NOME + produtos por CATEGORIA (mesclados,
  /// sem duplicar) + lojas por NOME — tudo a partir do mesmo termo digitado.
  void _iniciarBusca(String termo, {bool fecharTeclado = true}) {
    _debounce?.cancel();
    _versaoBusca++;
    _buscaCategoria = false;
    final termoLimpo = termo.trim();
    if (termoLimpo.isEmpty) return;
    if (fecharTeclado) {
      _searchController.text = termoLimpo;
      _searchFocus.unfocus();
    }
    _salvarNoHistorico(termoLimpo);
    _animationController.forward(from: 0.0);
    setState(() {
      _filtro = _FiltroBusca.tudo;
      _termoAtual = termoLimpo;
      _ultimoResultado = null;
      _ultimoErro = null;
      _estadoBusca = EstadoConteudo.loading;
    });
    _buscarComCache(termoLimpo);
  }

  /// Busca com suporte a stale-while-revalidate:
  /// 1. Tenta carregar cache imediatamente
  /// 2. Faz fetch em background
  /// 3. Se fetch falhar, mantém cache (stale) com banner de retry
  Future<void> _buscarComCache(String termo) async {
    final versao = _versaoBusca;
    // 1. Carrega cache imediatamente se existir
    final cache = await LocalCacheService.carregarResultadosBusca(termo);
    if (!mounted || versao != _versaoBusca) return;
    if (cache != null) {
      final produtos = (cache['produtos'] as List)
          .map(
            (p) => ProdutosModel.fromMap(Map<String, dynamic>.from(p as Map)),
          )
          .toList();
      final lojas = (cache['lojas'] as List)
          .map((l) => LojasModel.fromMap(Map<String, dynamic>.from(l as Map)))
          .toList();
      final lojaAberta = Map<String, bool>.from(cache['lojaAberta'] as Map);

      _ultimoResultado = _ResultadoBusca(
        produtos: produtos,
        lojas: lojas,
        lojaAberta: lojaAberta,
      );
      _estadoBusca = _ultimoResultado!.vazio
          ? EstadoConteudo.vazio
          : EstadoConteudo.conteudo;
      setState(() {});
    }

    // 2. Faz fetch em background
    try {
      final resultado = await _buscarTudo(termo);
      if (!mounted || versao != _versaoBusca) return;

      _ultimoResultado = resultado;
      _estadoBusca =
          resultado.vazio ? EstadoConteudo.vazio : EstadoConteudo.conteudo;
      _ultimoErro = null;
      setState(() {});
      LocalCacheService.salvarResultadosBusca(
        termo,
        produtos: resultado.produtos,
        lojas: resultado.lojas,
        lojaAberta: resultado.lojaAberta,
      ).catchError((Object e) {
        debugPrint('Não foi possível salvar a busca local: $e');
      });
    } catch (e) {
      if (!mounted || versao != _versaoBusca) return;

      // Se temos cache, mantém (stale) com estado de erro para banner
      if (_ultimoResultado != null) {
        _estadoBusca = EstadoConteudo.erro;
      } else {
        _estadoBusca = EstadoConteudo.erro;
        _ultimoResultado = null;
      }
      _ultimoErro = 'Não foi possível carregar a pesquisa. Tente novamente.';
      setState(() {});
    }
  }

  /// Busca real que propaga exceções (sem catchError que engole erros)
  Future<_ResultadoBusca> _buscarTudo(String termo) async {
    // O filtro de categoria no backend é por valor exato (ex: "Pizza"), então
    // digitar "pizza" (minúsculo) batia só na busca por nome. Aqui a gente
    // resolve o termo digitado pro nome exato da categoria quando ele
    // corresponde a uma das categorias conhecidas, senão manda como veio.
    final categoriaParaBuscar = _resolverCategoria(termo);

    final resultados = await Future.wait([
      _produtoRepository.buscarProdutosPorNome(termo),
      if (categoriaParaBuscar != null)
        _produtoRepository.buscarPorCategoria(categoriaParaBuscar)
      else
        Future.value(<ProdutosModel>[]),
      _lojaRepository.buscarLojasPorNome(termo),
    ]);

    final produtosPorNome = resultados[0] as List<ProdutosModel>;
    final produtosPorCategoria = resultados[1] as List<ProdutosModel>;
    final lojas = resultados[2] as List<LojasModel>;

    final produtosUnicos = <String, ProdutosModel>{};
    for (final p in [...produtosPorNome, ...produtosPorCategoria]) {
      produtosUnicos[p.id] = p;
    }

    final produtosFinais = produtosUnicos.values.toList();
    return _ResultadoBusca(
      produtos: produtosFinais,
      lojas: lojas,
      lojaAberta: _statusDasLojas(produtosFinais),
    );
  }

  static final Map<String, String> _categoriasConhecidas = {
    for (final cat in _categoriasSugeridas)
      _normalizarTexto(cat['nome'] as String): cat['nome'] as String,
  };

  static String _normalizarTexto(String texto) {
    const comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const semAcento = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    var resultado = texto.trim().toLowerCase();
    for (var i = 0; i < comAcento.length; i++) {
      resultado = resultado.replaceAll(
        comAcento[i].toLowerCase(),
        semAcento[i].toLowerCase(),
      );
    }
    return resultado;
  }

  /// Retorna o nome exato da categoria (como o backend espera) se [termo]
  /// corresponder a alguma categoria conhecida, ignorando maiúsculas/acentos.
  String? _resolverCategoria(String termo) {
    return _categoriasConhecidas[_normalizarTexto(termo)];
  }

  void _limparBusca() {
    _debounce?.cancel();
    _versaoBusca++;
    setState(() {
      _searchController.clear();
      _termoAtual = null;
      _ultimoResultado = null;
      _ultimoErro = null;
      _filtro = _FiltroBusca.tudo;
    });
  }

  void _abrirProduto(ProdutosModel produto) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ProdutoDetalhesPage(produto: produto),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
    );
  }

  void _abrirLoja(LojasModel loja) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            LojaPage(loja: loja),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildBarraBusca(),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _termoAtual != null
                  ? _buildFiltros()
                  : const SizedBox(width: double.infinity),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.03),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _termoAtual == null
                    ? _buildEstadoInicial()
                    : _buildResultadosComEstado(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultadosComEstado() {
    final resultadoAnterior = _ultimoResultado;
    if (_estadoBusca == EstadoConteudo.erro &&
        resultadoAnterior != null &&
        !resultadoAnterior.vazio) {
      return Column(
        children: [
          BannerErroInline(
            mensagem: _ultimoErro ?? 'Exibindo resultados anteriores.',
            aoTentarNovamente: () => _buscaCategoria
                ? _buscarCategoriaComCache(_termoAtual!)
                : _buscarComCache(_termoAtual!),
          ),
          Expanded(child: _buildResultados(resultadoAnterior)),
        ],
      );
    }
    return EstadoComRetry<_ResultadoBusca>(
      estado: _estadoBusca,
      dados: _estadoBusca == EstadoConteudo.erro ? null : _ultimoResultado,
      mensagemErro: _ultimoErro,
      aoTentarNovamente: _termoAtual != null
          ? () => _buscaCategoria
              ? _buscarCategoriaComCache(_termoAtual!)
              : _buscarComCache(_termoAtual!)
          : null,
      builderErro: (mensagem, tentarNovamente) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFFF6961),
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(mensagem, textAlign: TextAlign.center),
              TextButton(
                onPressed: tentarNovamente,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      builderVazio: () => _buildMensagemEstado(
        key: const ValueKey('vazio'),
        icone: Icons.search_off_rounded,
        titulo: 'Nada encontrado',
        subtitulo: 'Tente pesquisar com outras palavras.',
      ),
      builderConteudo: (resultado) => KeyedSubtree(
        key: const ValueKey('resultados'),
        child: _buildResultados(resultado),
      ),
    );
  }

  Widget _buildBarraBusca() {
    return Padding(
      padding: EdgeInsets.only(top: 8.h, left: 24.w, right: 24.w, bottom: 24.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFCDABB).withValues(alpha: 0.4),
                    blurRadius: 10.r,
                    offset: Offset(0, 4.h),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back,
                color: const Color(0xFF5D201C),
                size: 20.sp,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Hero(
              tag: 'search_bar',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFCDABB).withValues(alpha: 0.4),
                        blurRadius: 10.r,
                        offset: Offset(0, 4.h),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: Colors.grey),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _iniciarBusca,
                          onChanged: (texto) {
                            _debounce?.cancel();
                            if (texto.trim().isEmpty) {
                              _limparBusca();
                              return;
                            }
                            _debounce = Timer(
                              const Duration(milliseconds: 400),
                              () => _iniciarBusca(texto, fecharTeclado: false),
                            );
                          },
                          style: TextStyle(
                            color: _corTexto,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Procurar',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _temTexto
                            ? GestureDetector(
                                key: const ValueKey('clear'),
                                onTap: _limparBusca,
                                child: Icon(
                                  Icons.close_rounded,
                                  color: _corTexto.withValues(alpha: 0.5),
                                  size: 18.r,
                                ),
                              )
                            : const Icon(Icons.tune, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Row(
        children: [
          _chipFiltro('Tudo', _FiltroBusca.tudo),
          SizedBox(width: 8.w),
          _chipFiltro('Produtos', _FiltroBusca.produtos),
          SizedBox(width: 8.w),
          _chipFiltro('Lojas', _FiltroBusca.lojas),
        ],
      ),
    );
  }

  Widget _chipFiltro(String label, _FiltroBusca valor) {
    final selecionado = _filtro == valor;
    return GestureDetector(
      onTap: () => setState(() => _filtro = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selecionado ? _corPrimaria : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(50.r),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: selecionado ? Colors.white : _corTexto,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(
    IconData icon,
    String text, {
    bool isTrending = false,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: isTrending
              ? const Color(0xFFFF6961).withValues(alpha: 0.1)
              : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isTrending ? const Color(0xFFFF6961) : Colors.grey,
          size: 20.sp,
        ),
      ),
      title: Text(
        text,
        style: TextStyle(
          color: isTrending ? const Color(0xFF5D201C) : Colors.black87,
          fontWeight: isTrending ? FontWeight.w600 : FontWeight.normal,
          fontSize: 15.sp,
        ),
      ),
      trailing: Icon(Icons.north_west, color: Colors.grey, size: 16.sp),
      contentPadding: EdgeInsets.only(bottom: 8.h),
      onTap: () {
        _searchController.text = text;
        _iniciarBusca(text);
      },
    );
  }

  Widget _buildEstadoInicial() {
    return ListView(
      key: const ValueKey('inicial'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      children: [
        if (_historico.isNotEmpty) ...[
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAnimatedItem(
                Text(
                  'Sugestões',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF5D201C),
                  ),
                ),
                0,
              ),
              _buildAnimatedItem(
                GestureDetector(
                  onTap: () async {
                    setState(() => _historico = []);
                    await LocalCacheService.salvarHistoricoPesquisa([]);
                  },
                  child: Text(
                    'Limpar',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFFFF6961),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                0,
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ..._historico.asMap().entries.map(
                (entry) => _buildAnimatedItem(
                  _buildSuggestionItem(Icons.history, entry.value),
                  entry.key + 1,
                ),
              ),
          SizedBox(height: 24.h),
        ],
        _buildAnimatedItem(
          Text(
            'Em alta',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF5D201C),
            ),
          ),
          3,
        ),
        SizedBox(height: 16.h),
        _buildAnimatedItem(
          _buildSuggestionItem(
            Icons.trending_up,
            'Refrigerante Viver',
            isTrending: true,
          ),
          4,
        ),
        _buildAnimatedItem(
          _buildSuggestionItem(Icons.trending_up, 'Carne', isTrending: true),
          5,
        ),
        SizedBox(height: 24.h),
        _buildAnimatedItem(
          Text(
            'Categorias',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF5D201C),
            ),
          ),
          6,
        ),
        SizedBox(height: 16.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 2.6,
          ),
          itemCount: _categoriasSugeridas.length,
          itemBuilder: (context, i) {
            final cat = _categoriasSugeridas[i];
            return _buildAnimatedItem(
              GestureDetector(
                onTap: () => _buscarPorCategoriaInicial(cat['nome'] as String),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFCDABB).withValues(alpha: 0.4),
                        blurRadius: 10.r,
                        offset: Offset(0, 4.h),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34.w,
                        height: 34.w,
                        decoration: const BoxDecoration(
                          color: _corAccentClaro,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          cat['icon'] as IconData,
                          color: _corPrimaria,
                          size: 18.r,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          cat['nome'] as String,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: _corTexto,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              i + 7,
            );
          },
        ),
        SizedBox(height: 32.h),
      ],
    );
  }

  Widget _buildMensagemEstado({
    required Key key,
    required IconData icone,
    required String titulo,
    required String subtitulo,
  }) {
    return Center(
      key: key,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.w,
              height: 72.w,
              decoration: const BoxDecoration(
                color: _corAccentClaro,
                shape: BoxShape.circle,
              ),
              child: Icon(icone, color: _corPrimaria, size: 34.r),
            ),
            SizedBox(height: 16.h),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: _corTexto,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: _corTexto.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultados(_ResultadoBusca resultado) {
    final mostrarLojas =
        _filtro != _FiltroBusca.produtos && resultado.lojas.isNotEmpty;
    final mostrarProdutos =
        _filtro != _FiltroBusca.lojas && resultado.produtos.isNotEmpty;

    if (!mostrarLojas && !mostrarProdutos) {
      return _buildMensagemEstado(
        key: const ValueKey('filtro-vazio'),
        icone: Icons.search_off_rounded,
        titulo: _filtro == _FiltroBusca.lojas
            ? 'Nenhuma loja encontrada'
            : 'Nenhum produto encontrado',
        subtitulo: 'Tente outro filtro ou outra palavra-chave.',
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      children: [
        if (mostrarLojas) ...[
          Text(
            'Lojas',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: _corTexto,
            ),
          ),
          SizedBox(height: 10.h),
          ...List.generate(resultado.lojas.length, (i) {
            return _buildAnimatedItem(_buildLojaTile(resultado.lojas[i]), i);
          }),
          SizedBox(height: 20.h),
        ],
        if (mostrarProdutos) ...[
          Text(
            'Produtos',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: _corTexto,
            ),
          ),
          SizedBox(height: 10.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 0.70,
            ),
            itemCount: resultado.produtos.length,
            itemBuilder: (context, index) {
              final produto = resultado.produtos[index];
              return _buildAnimatedItem(
                GestureDetector(
                  onTap: () => _abrirProduto(produto),
                  child: ProductCard(
                    produto: produto,
                    lojaFechada: resultado.lojaAberta[produto.lojaId] != true,
                  ),
                ),
                index,
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildLojaTile(LojasModel loja) {
    return GestureDetector(
      onTap: () => _abrirLoja(loja),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: _corTexto.withValues(alpha: 0.05),
              blurRadius: 10.r,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: CachedNetworkImage(
                imageUrl: loja.imagemUrl,
                width: 52.w,
                height: 52.w,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    width: 52.w,
                    height: 52.w,
                    color: Colors.white,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 52.w,
                  height: 52.w,
                  color: _corAccentClaro,
                  child: Icon(
                    Icons.storefront_rounded,
                    color: _corPrimaria,
                    size: 24.r,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loja.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: _corTexto,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Container(
                        width: 7.w,
                        height: 7.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: loja.isAberto
                              ? const Color(0xFF4CAF50)
                              : Colors.grey.shade400,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        loja.isAberto ? loja.categoria : 'Fechada no momento',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: _corTexto.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _corTexto.withValues(alpha: 0.3),
              size: 22.r,
            ),
          ],
        ),
      ),
    );
  }
}
