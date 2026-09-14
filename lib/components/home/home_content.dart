import 'dart:async';
import 'package:nhac/components/home/home_category_chips.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/loja/lojas.dart';
import 'package:nhac/models/produto/produtos.dart';
import 'package:nhac/utils/endereco_utils.dart';
import 'package:nhac/pages/loja_page.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:nhac/repositories/produto_repository.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/components/home/home_banner_carousel.dart';
import 'package:nhac/components/home/home_product_section.dart';
import 'package:nhac/pages/search_page.dart';
import 'package:nhac/controllers/endereco_provider.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/services/local_cache_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:nhac/globals/ui_utils.dart';
import 'package:geocoding/geocoding.dart';
import 'package:nhac/controllers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:nhac/components/fly_to_cart_overlay.dart';

@NowaGenerated()
class HomeContent extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  String _currentAddress = 'Buscando localização...';
  static bool _jaCarregouUmaVez = false;
  late bool _isLoading;
  Timer? _loadingTimer;

  final List<LojasModel> _lojas = [];
  int _currentPageLojas = 0;
  bool _isLoadingLojas = false;
  bool _hasMoreLojas = true;
  bool _errorLojas = false;
  String _mensagemErroLojas = 'Ocorreu um erro ao carregar os restaurantes.';

  final LojaRepository _lojaRepository = LojaRepository();
  final ProdutoRepository _produtoRepository = ProdutoRepository();

  final List<ProdutosModel> _produtosNecessidades = [];
  bool _isLoadingProdutosNecessidades = true;

  final List<ProdutosModel> _produtosPromocao = [];
  bool _isLoadingProdutosPromocao = true;

  Map<String, bool> _lojaAbertaMap = {};

  @override
  void initState() {
    super.initState();
    _isLoading = !_jaCarregouUmaVez;

    _carregarDadosIniciais();
    _carregarGpsComCache();

    if (_isLoading) {
      _loadingTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _jaCarregouUmaVez = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  Future<void> _carregarDadosIniciais() async {
    await Future.wait([
      _fetchProdutosNecessidades(),
      _fetchProdutosPromocao(),
      _fetchLojas(),
    ]);
    _aplicarStatusLojas();

    if (mounted) {
      _loadingTimer?.cancel();
      setState(() {
        _isLoadingProdutosNecessidades = false;
        _isLoadingProdutosPromocao = false;
        if (_isLoading) {
          _isLoading = false;
          _jaCarregouUmaVez = true;
        }
      });
    }
  }

  /// Constrói o mapa de status aberta/fechada a partir do campo `lojaAberta`
  /// que já vem em cada produto na resposta de `/produtos`.
  /// Substitui o antigo `_atualizarStatusLojas` que fazia N chamadas
  /// `GET /lojas/{id}` em paralelo.
  void _aplicarStatusLojas() {
    if (!mounted) return;

    setState(() {
      // Constrói o mapa a partir dos próprios produtos — sem requisição HTTP
      final todos = [..._produtosNecessidades, ..._produtosPromocao];
      _lojaAbertaMap = {
        for (final p in todos)
          if (p.lojaId.isNotEmpty) p.lojaId: p.lojaAberta,
      };

      _produtosNecessidades.removeWhere((p) {
        return !(_lojaAbertaMap[p.lojaId] ?? false);
      });

      _produtosPromocao.removeWhere((p) {
        return !(_lojaAbertaMap[p.lojaId] ?? false);
      });

      _produtosNecessidades.shuffle();
      _produtosPromocao.shuffle();

      // Limit the number of products to 10 to not overflow the UI and look nice
      if (_produtosNecessidades.length > 10) _produtosNecessidades.removeRange(10, _produtosNecessidades.length);
      if (_produtosPromocao.length > 10) _produtosPromocao.removeRange(10, _produtosPromocao.length);

      // Sort products to put open stores first.
      int compareLojas(ProdutosModel a, ProdutosModel b) {
        final aAberto = _lojaAbertaMap[a.lojaId] ?? false;
        final bAberto = _lojaAbertaMap[b.lojaId] ?? false;
        if (aAberto && !bAberto) return -1;
        if (!aAberto && bAberto) return 1;
        return 0;
      }

      _produtosNecessidades.sort(compareLojas);
      _produtosPromocao.sort(compareLojas);
    });
  }

  Future<void> _fetchProdutosNecessidades() async {
    if (LocalCacheService.produtosNecessidadesCache != null) {
      if (mounted) {
        setState(() {
          _produtosNecessidades.clear();
          _produtosNecessidades.addAll(LocalCacheService.produtosNecessidadesCache!.cast<ProdutosModel>());
        });
      }
      return;
    }

    try {
      final produtos = await _produtoRepository.buscarNecessidades();
      LocalCacheService.produtosNecessidadesCache = List.from(produtos);
      if (mounted) {
        setState(() {
          _produtosNecessidades.clear();
          _produtosNecessidades.addAll(produtos);
        });
      }
    } catch (e) {
      debugPrint("Erro ao buscar necessidades da API: $e");
    }
  }

  Future<void> _fetchProdutosPromocao() async {
    if (LocalCacheService.produtosPromocaoCache != null) {
      if (mounted) {
        setState(() {
          _produtosPromocao.clear();
          _produtosPromocao.addAll(LocalCacheService.produtosPromocaoCache!.cast<ProdutosModel>());
        });
      }
      return;
    }

    try {
      final promocoes = await _produtoRepository.buscarPromocoes();
      LocalCacheService.produtosPromocaoCache = List.from(promocoes);
      if (mounted) {
        setState(() {
          _produtosPromocao.clear();
          _produtosPromocao.addAll(promocoes);
        });
      }
    } catch (e) {
      debugPrint("Erro ao buscar promoções da API: $e");
    }
  }

  Future<void> _fetchLojas() async {
    if (_isLoadingLojas || !_hasMoreLojas || !mounted) return;

    if (LocalCacheService.lojasCache != null && _currentPageLojas == 0) {
      if (mounted) {
        setState(() {
          _lojas.clear();
          _lojas.addAll(LocalCacheService.lojasCache!.cast<LojasModel>());
          _currentPageLojas = LocalCacheService.currentPageLojasCache;
          _hasMoreLojas = LocalCacheService.hasMoreLojasCache;
        });
      }
      return;
    }

    setState(() {
      _isLoadingLojas = true;
      _errorLojas = false;
    });

    try {
      final novasLojas =
          await _lojaRepository.buscarLojas(page: _currentPageLojas, size: 10);

      if (novasLojas.isEmpty) {
        if (mounted) {
          setState(() {
            _hasMoreLojas = false;
            _isLoadingLojas = false;
            LocalCacheService.hasMoreLojasCache = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _lojas.addAll(novasLojas);
          _currentPageLojas++;

          if (novasLojas.length < 10) {
            _hasMoreLojas = false;
          }

          _isLoadingLojas = false;
          
          LocalCacheService.lojasCache = List.from(_lojas);
          LocalCacheService.currentPageLojasCache = _currentPageLojas;
          LocalCacheService.hasMoreLojasCache = _hasMoreLojas;
        });
      }
    } on NetworkException catch (e) {
      debugPrint("Erro de rede ao buscar lojas: $e");
      if (mounted) {
        setState(() {
          _isLoadingLojas = false;
          _errorLojas = true;
          _mensagemErroLojas = e.message;
          }
          );
      }
    }
  }

  Widget _buildListaDeLojas() {
    if (_errorLojas && _lojas.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline,
                color: const Color(0xFFFF6961), size: 48.r),
            SizedBox(height: 16.h),
            Text(
              _mensagemErroLojas,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14.sp),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _fetchLojas,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6961),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50.r),
                ),
              ),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_lojas.isEmpty && _isLoadingLojas) {
      return Column(
        children: List.generate(
            3,
            (index) => Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: _buildBoxSkeleton(
                      width: double.infinity, height: 90.h, borderRadius: 12.r),
                )),
      );
    }

    if (_lojas.isEmpty && !_isLoadingLojas) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: const Center(
          child: Text(
            'Nenhum restaurante encontrado na região.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _lojas.length,
          itemBuilder: (context, index) {
            final loja = _lojas[index];

            return Container(
                margin: EdgeInsets.only(bottom: 16.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5D201C).withValues(alpha: 0.05),
                      blurRadius: 10.r,
                      offset: const Offset(0.0, 4.0),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16.r),
                  onTap: () {
                    if (loja.isAberto) {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  LojaPage(loja: loja),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            var curvedAnimation = CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutQuart,
                              reverseCurve: Curves.easeInQuart,
                            );

                            var enterTween = Tween(
                                begin: const Offset(1.0, 0.0),
                                end: Offset.zero);

                            Widget page = SlideTransition(
                              position: enterTween.animate(curvedAnimation),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF5D201C)
                                          .withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: child,
                              ),
                            );

                            return page;
                          },
                          transitionDuration: const Duration(milliseconds: 400),
                          reverseTransitionDuration:
                              const Duration(milliseconds: 400),
                        ),
                      );
                    } else {
                      context.showError('${loja.nome} está fechado no momento.');
                    }
                  },
                  child: Opacity(
                    opacity: loja.isAberto ? 1.0 : 0.5,
                    child: Padding(
                      padding: EdgeInsets.all(12.w),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12.r),
                            child: CachedNetworkImage(
                              imageUrl: loja.imagemUrl,
                              width: 70.w,
                              height: 70.w,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: Colors.grey.shade300,
                                highlightColor: Colors.grey.shade100,
                                child: Container(
                                  width: 70.w,
                                  height: 70.w,
                                  color: Colors.white,
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 70.w,
                                height: 70.w,
                                color: Colors.grey.shade100,
                                child: Icon(Icons.store,
                                    color: Colors.grey, size: 24.r),
                              ),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        loja.nome,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16.sp,
                                          color: const Color(0xFF5D201C),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.star,
                                            color: Colors.amber, size: 16.r),
                                        SizedBox(width: 4.w),
                                        Text(
                                          (loja.dadosOperacionais?.avaliacaoMedia ?? 0.0)
                                              .toStringAsFixed(1),
                                          style: TextStyle(
                                            color: Colors.amber,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  loja.categoria,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13.sp),
                                ),
                                SizedBox(height: 8.h),
                                Row(
                                  children: [
                                    Text(
                                      '${loja.dadosOperacionais?.tempoEntregaMin}-${loja.dadosOperacionais?.tempoEntregaMax} min',
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12.sp),
                                    ),
                                    Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 6.w),
                                      child: Text('•',
                                          style: TextStyle(
                                              color: Colors.grey.shade400)),
                                    ),
                                    Text(
                                      loja.dadosOperacionais?.taxaEntregaBase ==
                                              0
                                          ? 'Entrega Grátis'
                                          : 'R\$ ${loja.dadosOperacionais?.taxaEntregaBase.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: loja.dadosOperacionais
                                                    ?.taxaEntregaBase ==
                                                0
                                            ? Colors.green
                                            : Colors.grey.shade600,
                                        fontWeight: loja.dadosOperacionais
                                                    ?.taxaEntregaBase ==
                                                0
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ));
          },
        ),
        if (_isLoadingLojas)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: const CircularProgressIndicator(color: Color(0xFFFF6961)),
          ),
      ],
    );
  }

  Future<void> _carregarGpsComCache() async {
    final cachedGps = await LocalCacheService.carregarLocalizacaoGps();
    if (cachedGps != null && mounted) {
      setState(() => _currentAddress = cachedGps);
    }
    _pegarLocalizacaoUsuario();
  }

  Future<void> _pegarLocalizacaoUsuario() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _currentAddress = 'GPS desativado');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _currentAddress = 'Permissão negada');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() => _currentAddress = 'Permissão negada permanentemente');
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));

      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        final endereco = '${place.street}, ${place.subLocality}';
        if (mounted) {
          setState(() => _currentAddress = endereco);
          LocalCacheService.salvarLocalizacaoGps(endereco);
          
          final authService = context.read<AuthService>();
          final enderecoProvider = context.read<EnderecoProvider>();
          
          if (authService.isAuthenticated && enderecoProvider.enderecos.isEmpty) {
            final novoEndereco = EnderecoModel(
              id: '',
              rua: place.street ?? 'Desconhecida',
              numero: place.subThoroughfare ?? 'S/N',
              bairro: place.subLocality ?? '',
              cidade: place.subAdministrativeArea ?? '',
              estado: EnderecoUtils.normalizarEstado(place.administrativeArea),
              cep: place.postalCode ?? '00000-000',
              isPadrao: true,
            );
            enderecoProvider.adicionarEndereco(novoEndereco).catchError((_) {});
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _currentAddress = 'Erro ao buscar endereço');
    }
  }

  Future<void> _onRefresh() async {
    _currentPageLojas = 0;
    _hasMoreLojas = true;
    _lojas.clear();
    LocalCacheService.limparCacheHome();
    await Future.wait([
      _pegarLocalizacaoUsuario(),
      context.read<UserProvider>().carregarDadosUsuario(),
      _carregarDadosIniciais(),
    ]);
  }

  void _abrirSelecaoEndereco(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _SelecaoEnderecoBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enderecoisPadrao = context.select<EnderecoProvider, EnderecoModel?>(
      (p) => p.enderecos.where((e) => e.isPadrao).firstOrNull,
    );

    String enderecoTopo = _currentAddress;
    if (enderecoisPadrao != null) {
      enderecoTopo = '${enderecoisPadrao.rua}, ${enderecoisPadrao.numero}';
      if ((enderecoisPadrao.complemento ?? '').isNotEmpty) {
        enderecoTopo += ' - ${enderecoisPadrao.complemento}';
      }
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
          _fetchLojas();
        }
        return false;
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(
            refreshIndicatorExtent: 140.h,
            refreshTriggerPullDistance: 180.h,
            onRefresh: _onRefresh,
            builder: (context, refreshState, pulledExtent,
                refreshTriggerPullDistance, refreshIndicatorExtent) {
              return Center(
                child: Opacity(
                  opacity:
                      (pulledExtent / refreshIndicatorExtent).clamp(0.0, 1.0),
                  child: Lottie.asset(
                    'assets/animations/loading_nhac.json',
                    width: 240.w,
                    height: 240.h,
                    animate: refreshState == RefreshIndicatorMode.refresh ||
                        refreshState == RefreshIndicatorMode.armed,
                  ),
                ),
              );
            },
          ),
          SliverPadding(
            padding: EdgeInsets.all(24.w),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SizedBox(height: 16.h),
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, -20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF5D201C)
                                            .withValues(alpha: 0.05),
                                        blurRadius: 10.r,
                                        offset: const Offset(0.0, 4.0),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.location_on_outlined,
                                    color: Colors.grey,
                                    size: 20.r,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Sua Localização',
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12.sp),
                                      ),
                                      Text(
                                        enderecoTopo,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.sp,
                                          color: const Color(0xFF5D201C),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16.w),
                          GestureDetector(
                            onTap: () => _abrirSelecaoEndereco(context),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(50.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF5D201C)
                                        .withValues(alpha: 0.05),
                                    blurRadius: 10.r,
                                    offset: const Offset(0.0, 4.0),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Mudar',
                                    style: TextStyle(
                                      color: const Color(0xFFFF6961),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                  Icon(Icons.chevron_right,
                                      color: const Color(0xFFFF6961),
                                      size: 18.r),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),
                      Hero(
                        tag: 'search_bar',
                        child: Material(
                          color: Colors.transparent,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation,
                                          secondaryAnimation) =>
                                      const SearchPage(),
                                  transitionsBuilder: (context, animation,
                                      secondaryAnimation, child) {
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
                                    color: const Color(0xFF5D201C)
                                        .withValues(alpha: 0.05),
                                    blurRadius: 10.r,
                                    offset: const Offset(0.0, 4.0),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.search,
                                      color: Colors.grey, size: 22.r),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      'Procurar',
                                      style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 16.sp),
                                    ),
                                  ),
                                  Icon(Icons.tune,
                                      color: Colors.grey, size: 22.r),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, -20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: _isLoading
                        ? SizedBox(
                            key: const ValueKey('carousel_skeleton'),
                            height: 180.h,
                            child: PageView(
                              controller: PageController(viewportFraction: 0.9),
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildBoxSkeleton(
                                    width: double.infinity,
                                    height: 180.h,
                                    borderRadius: 20.r),
                              ],
                            ),
                          )
                        : const HomeBannerCarousel(
                            key: ValueKey('carousel_content')),
                  ),
                ),
                SizedBox(height: 28.h),
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: const HomeCategoryChips(),
                ),
                SizedBox(height: 28.h),
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: _isLoadingProdutosNecessidades
                        ? _buildSectionSkeleton(
                            key: const ValueKey('section1_skeleton'))
                        : HomeProductSection(
                            key: const ValueKey('section1_content'),
                            title: 'Temos tudo que você precisa',
                            onSeeAll: () => context.push('/search'),
                            products: _produtosNecessidades,
                            lojaAberta: _lojaAbertaMap,
                            onFlyToCart: FlyToCartOverlay.of(context)?.fly,
                          ),
                  ),
                ),
                SizedBox(height: 28.h),
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: _isLoadingProdutosPromocao
                        ? _buildSectionSkeleton(
                            key: const ValueKey('section2_skeleton'))
                        : HomeProductSection(
                            key: const ValueKey('section2_content'),
                            title: 'Tudo abaixo de R\$ 20',
                            onSeeAll: () => context.push('/search'),
                            products: _produtosPromocao,
                            lojaAberta: _lojaAbertaMap,
                            onFlyToCart: FlyToCartOverlay.of(context)?.fly,
                          ),
                  ),
                ),
                SizedBox(height: 28.h),

                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: const Interval(0.8, 1.0, curve: Curves.easeOutCubic),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Restaurantes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20.sp,
                          color: const Color(0xFF5D201C),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _buildListaDeLojas(),
                    ],
                  ),
                ),
                SizedBox(height: 100.h),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoxSkeleton(
      {double? width, double? height, double borderRadius = 8}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  Widget _buildSectionSkeleton({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildBoxSkeleton(width: 180.w, height: 20.h),
            _buildBoxSkeleton(width: 60.w, height: 16.h),
          ],
        ),
        SizedBox(height: 16.h),
        SizedBox(
          height: 220.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            itemBuilder: (context, index) => _buildProductCardSkeleton(),
          ),
        ),
      ],
    );
  }

  Widget _buildProductCardSkeleton() {
    return Container(
      width: 160.w,
      margin: EdgeInsets.only(right: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildBoxSkeleton(
                width: 160.w, height: double.infinity, borderRadius: 16.r),
          ),
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBoxSkeleton(width: 100.w, height: 14.h),
                SizedBox(height: 4.h),
                _buildBoxSkeleton(width: 60.w, height: 12.h),
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBoxSkeleton(width: 50.w, height: 16.h),
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        width: 24.w,
                        height: 24.h,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
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
}

class _SelecaoEnderecoBottomSheet extends StatelessWidget {
  const _SelecaoEnderecoBottomSheet();

  @override
  Widget build(BuildContext context) {
    final enderecoProvider = context.watch<EnderecoProvider>();
    final enderecos = enderecoProvider.enderecos;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
      ),
      padding: EdgeInsets.only(top: 16.h, bottom: 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 24.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Onde você quer receber seu pedido?',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF5D201C),
                ),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              itemCount: enderecos.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final endereco = enderecos[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    context
                        .read<EnderecoProvider>()
                        .definirComoPadrao(endereco.id);
                    Navigator.pop(context);
                  },
                  leading: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6961).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      endereco.bairro.toLowerCase().contains('trabalho') ||
                              (endereco.complemento ?? '')
                                  .toLowerCase()
                                  .contains('trabalho')
                          ? Icons.work_outline
                          : Icons.home_outlined,
                      color: const Color(0xFFFF6961),
                      size: 20.r,
                    ),
                  ),
                  title: Text(
                    '${endereco.rua}, ${endereco.numero}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp,
                    ),
                  ),
                  subtitle: Text(
                    '${endereco.bairro}${(endereco.complemento ?? '').isNotEmpty ? ' - ${endereco.complemento}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.sp),
                  ),
                  trailing: endereco.isPadrao
                      ? Icon(Icons.check_circle,
                          color: const Color(0xFFFF6961), size: 22.r)
                      : null,
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: const Divider(height: 32),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                context.push('/enderecos-salvos');
              },
              borderRadius: BorderRadius.circular(12.r),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, color: Colors.grey, size: 20.r),
                    ),
                    SizedBox(width: 16.w),
                    Text(
                      'Adicionar novo endereço',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15.sp,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
