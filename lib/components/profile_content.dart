import 'dart:io';
import 'dart:ui';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/controllers/cart_provider.dart';
import 'package:nhac/controllers/endereco_provider.dart';
import 'package:nhac/controllers/user_provider.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/biometric_service.dart';
import 'package:provider/provider.dart';
import 'package:nhac/globals/ui_utils.dart';
import 'package:nhac/repositories/pedido_repository.dart';

class ProfileContent extends StatefulWidget {
  const ProfileContent({super.key});

  @override
  State<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  bool _isUploading = false;
  Map<String, dynamic> _estatisticas = {
    'totalPedidos': 0,
    'lojasFavoritadas': 0,
    'cuponsResgatados': 0
  };
  bool _carregandoEstatisticas = true;

  @override
  void initState() {
    super.initState();
    _carregarEstatisticas();
  }

  Future<void> _carregarEstatisticas() async {
    final auth = context.read<AuthService>();
    if (auth.usuarioId != null) {
      final repo = PedidoRepository();
      final stats = await repo.buscarEstatisticas(auth.usuarioId!);
      if (mounted) {
        setState(() {
          _estatisticas = stats;
          _carregandoEstatisticas = false;
        });
      }
    } else {
      if (mounted) setState(() => _carregandoEstatisticas = false);
    }
  }

  void _logoutUsuario(BuildContext context) async {
    final authService = context.read<AuthService>();
    final userProvider = context.read<UserProvider>();
    final carrinho = context.read<CartProvider>();
    Navigator.pop(context);
    userProvider.limparUsuario();
    carrinho.esvaziarCarrinho();
    await authService.signOut();
  }

  void _abrirNotificacoes(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 32.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: SizedBox(
                        width: 24.w,
                        height: 24.h,
                        child: Icon(Icons.close,
                            color: const Color(0xFF5D201C), size: 24.r),
                      ),
                    ),
                    SizedBox(height: 28.h),
                    Text(
                      'Notificações',
                      style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF5D201C)),
                    ),
                    SizedBox(height: 32.h),
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_off_outlined,
                                size: 64.r, color: Colors.grey.shade300),
                            SizedBox(height: 16.h),
                            Text(
                              'Você não tem novas notificações.',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 16.sp),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.fastOutSlowIn;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
              position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  void _mostrarOpcoesConta(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 32.h),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(40),
              topRight: Radius.circular(40),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Opções da Conta',
                  style:
                      TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 32.h),
              InkWell(
                onTap: () {},
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.help_outline, color: Colors.grey.shade700),
                          SizedBox(width: 12.w),
                          Text('Ajuda',
                              style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700)),
                        ],
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              InkWell(
                onTap: () => _logoutUsuario(context),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.logout, color: Colors.grey.shade700),
                          SizedBox(width: 12.w),
                          Text('Sair da conta',
                              style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700)),
                        ],
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 48.h),
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6961),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28.r)),
                    elevation: 0,
                  ),
                  child: Text('Voltar',
                      style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final usuario = userProvider.usuario;
    final enderecoProvider = context.watch<EnderecoProvider>();
    final enderecoisPadrao =
        enderecoProvider.enderecos.where((e) => e.isPadrao).firstOrNull;
    final String textoEndereco = enderecoisPadrao != null
        ? '${enderecoisPadrao.rua}, ${enderecoisPadrao.numero}${(enderecoisPadrao.complemento?.isNotEmpty ?? false) ? ' - ${enderecoisPadrao.complemento}' : ''}'
        : 'Nenhum endereço selecionado';

    if (usuario == null) {
      return Container(
        color: const Color(0xFFFFE7E5),
        child: Center(
          child: Lottie.asset('assets/animations/loading_nhac.json',
              width: 340.w, height: 340.h),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(color: Color(0xFFFFE7E5)),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            CupertinoSliverRefreshControl(
              refreshIndicatorExtent: 140.h,
              refreshTriggerPullDistance: 180.h,
              onRefresh: () async =>
                  await context.read<UserProvider>().carregarDadosUsuario(),
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
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  SizedBox(height: 16.h),
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _abrirNotificacoes(context),
                        child: Container(
                          width: 40.w,
                          height: 40.h,
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.6),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.notifications_none,
                              color: Color(0xFF5D201C)),
                        ),
                      ),
                      Text('Perfil',
                          style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF5D201C))),
                      GestureDetector(
                        onTap: () => _mostrarOpcoesConta(context),
                        child: Container(
                          width: 40.w,
                          height: 40.h,
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.6),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.more_horiz,
                              color: Color(0xFF5D201C)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 32.h),
                  Row(
                    children: [
                      Stack(
                        children: [
                          GestureDetector(
                            onLongPress: () =>
                                _mostrarPreviewFoto(context, usuario.imagemUrl),
                            onLongPressUp: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 80.w,
                              height: 80.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                      color: const Color(0xFF5D201C)
                                          .withValues(alpha: 0.1),
                                      blurRadius: 10.r,
                                      offset: Offset(0, 4.h))
                                ],
                              ),
                              child: _isUploading
                                  ? Center(
                                      child: Lottie.asset(
                                          'assets/animations/loading_nhac.json',
                                          width: 40.w,
                                          height: 40.h))
                                  : ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: usuario.imagemUrl ?? '',
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2)),
                                        errorWidget: (context, url, error) =>
                                            Icon(Icons.person,
                                                size: 48.r,
                                                color: Colors.grey.shade400),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _isUploading
                                  ? null
                                  : () async {
                                      final picker = ImagePicker();
                                      final pickedFile = await picker.pickImage(
                                          source: ImageSource.gallery);
                                      if (pickedFile != null && mounted) {
                                        setState(() => _isUploading = true);
                                        try {
                                          if (context.mounted) {
                                            await context
                                                .read<UserProvider>()
                                                .atualizarFotoPerfil(
                                                    File(pickedFile.path));
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            context.showError(
                                                'Erro ao carregar imagem: $e');
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(
                                                () => _isUploading = false);
                                          }
                                        }
                                      }
                                    },
                              child: Container(
                                padding: EdgeInsets.all(4.w),
                                decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle),
                                child: Container(
                                  padding: EdgeInsets.all(4.w),
                                  decoration: const BoxDecoration(
                                      color: Color(0xFF5D201C),
                                      shape: BoxShape.circle),
                                  child: _isUploading
                                      ? SizedBox(
                                          width: 12.w,
                                          height: 12.h,
                                          child: Lottie.asset(
                                              'assets/animations/loading_nhac.json'))
                                      : const Icon(Icons.edit,
                                          size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                                text: TextSpan(
                                    text: usuario.nome,
                                    style: TextStyle(
                                        fontSize: 22.sp,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF5D201C)))),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: 14.r, color: Colors.grey.shade600),
                                SizedBox(width: 4.w),
                                Expanded(
                                  child: Text(textoEndereco,
                                      style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 12.sp),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 32.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _carregandoEstatisticas
                          ? const CircularProgressIndicator()
                          : _buildStatItem(
                              '${_estatisticas['totalPedidos'] ?? 0}',
                              'Pedidos'),
                      Container(
                          height: 30.h,
                          width: 1.w,
                          color: Colors.grey.shade300),
                      _carregandoEstatisticas
                          ? const CircularProgressIndicator()
                          : _buildStatItem(
                              '${_estatisticas['lojasFavoritadas'] ?? 0}',
                              'Favoritos',
                            ),
                      Container(
                          height: 30.h,
                          width: 1.w,
                          color: Colors.grey.shade300),
                      _carregandoEstatisticas
                          ? const CircularProgressIndicator()
                          : _buildStatItem(
                              '${_estatisticas['cuponsResgatados'] ?? 0}',
                              'Cupons',
                            ),
                    ],
                  ),
                  SizedBox(height: 40.h),
                  Text('Sua Conta',
                      style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF5D201C))),
                  SizedBox(height: 16.h),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24.r),
                      boxShadow: [
                        BoxShadow(
                            color:
                                const Color(0xFF5D201C).withValues(alpha: 0.03),
                            blurRadius: 15.r,
                            offset: Offset(0, 5.h))
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildAccountRow(
                          icon: Icons.person_outline,
                          iconColor: const Color(0xFFFF6961),
                          title: 'Dados Pessoais',
                          subtitle: 'Nome, e-mail, telefone...',
                          onTap: () async {
                            final autenticado =
                                await BiometricService.authenticate();
                            if (!context.mounted) return;

                            if (!autenticado) {
                              context.showError(
                                  'Autenticação biométrica necessária');
                              return;
                            }
                            context.push('/dados-pessoais');
                          },
                        ),
                        Divider(
                            height: 1,
                            color: Colors.grey.shade100,
                            indent: 64.w),
                        _buildAccountRow(
                          icon: Icons.location_on_outlined,
                          iconColor: const Color(0xFFFF6961),
                          title: 'Endereços Salvos',
                          subtitle: 'Casa, Trabalho...',
                          onTap: () => context.push('/enderecos-salvos'),
                        ),
                        Divider(
                            height: 1,
                            color: Colors.grey.shade100,
                            indent: 64.w),
                        _buildAccountRow(
                          icon: Icons.credit_card_outlined,
                          iconColor: const Color(0xFFFF6961),
                          title: 'Formas de Pagamento',
                          subtitle: 'PIX, Cartões de Crédito...',
                          onTap: () => context.push('/formas-pagamento'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32.h),
                  Text('Preferências de Comida',
                      style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF5D201C))),
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                            color:
                                const Color(0xFF5D201C).withValues(alpha: 0.03),
                            blurRadius: 15.r,
                            offset: Offset(0, 5.h))
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildPreferenceItem(
                              Icons.local_pizza, 'Pizza', true),
                          SizedBox(width: 20.w),
                          _buildPreferenceItem(
                              Icons.ramen_dining, 'Vegetariana', false),
                          SizedBox(width: 20.w),
                          _buildPreferenceItem(
                              Icons.fastfood, 'Salgados', false),
                          SizedBox(width: 20.w),
                          _buildPreferenceItem(
                              Icons.bakery_dining, 'Padarias', false),
                          SizedBox(width: 20.w),
                          _buildPreferenceItem(
                              Icons.set_meal, 'Frutos do mar', false),
                          SizedBox(width: 20.w),
                          _buildPreferenceItem(Icons.cake, 'Doces', false),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 120.h),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 24.sp,
                color: const Color(0xFF5D201C),
                fontWeight: FontWeight.w300)),
        SizedBox(height: 4.h),
        Text(label,
            style: TextStyle(
                fontSize: 12.sp,
                color: const Color(0xFF5D201C),
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildAccountRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24.r),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15.sp,
                          color: const Color(0xFF5D201C))),
                  Text(subtitle,
                      style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceItem(IconData icon, String label, bool isSelected) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: isSelected
                ? Border.all(color: const Color(0xFFFF6961), width: 2)
                : Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: const Color(0xFFFF6961).withValues(alpha: 0.2),
                        blurRadius: 8.r,
                        offset: Offset(0, 4.h))
                  ]
                : null,
          ),
          child: Icon(icon,
              color: isSelected
                  ? const Color(0xFFFF6961)
                  : const Color(0xFF5D201C),
              size: 28.r),
        ),
        SizedBox(height: 8.h),
        Text(label,
            style: TextStyle(
                fontSize: 11.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: const Color(0xFF5D201C))),
      ],
    );
  }

  void _mostrarPreviewFoto(BuildContext context, String? fotoUrl) {
    showGeneralPage(
      context,
      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: const Color(0xFF5D201C).withValues(alpha: 0.4),
            child: Center(
              child: Container(
                width: 260.w,
                height: 260.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white, width: 4.w),
                  image: (fotoUrl != null && fotoUrl.isNotEmpty)
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(fotoUrl),
                          fit: BoxFit.cover)
                      : null,
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF5D201C).withValues(alpha: 0.3),
                        blurRadius: 30.r,
                        offset: Offset(0, 10.h))
                  ],
                ),
                child: (fotoUrl == null || fotoUrl.isEmpty)
                    ? Icon(Icons.person,
                        size: 160.r, color: Colors.grey.shade300)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void showGeneralPage(BuildContext context, Widget child) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 110),
        reverseTransitionDuration: const Duration(milliseconds: 110),
        pageBuilder: (context, _, __) => child,
        transitionsBuilder: (context, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}
