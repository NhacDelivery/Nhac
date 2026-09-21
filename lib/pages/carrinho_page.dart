import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/controllers/cart_provider.dart';
import 'package:nhac/controllers/endereco_provider.dart';
import 'package:nhac/globals/ui_utils.dart';
import 'package:nhac/models/usuario/carrinho_model.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:nhac/e2e/e2e_keys.dart';

class CarrinhoPage extends StatefulWidget {
  final bool isActive;
  const CarrinhoPage({super.key, this.isActive = true});

  @override
  State<CarrinhoPage> createState() => _CarrinhoPageState();
}

class _CarrinhoPageState extends State<CarrinhoPage> {
  final Color primaryColor = const Color(0xFFFF6961);
  final NumberFormat currencyFormat =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  late final TextEditingController _observacaoController;

  @override
  void initState() {
    super.initState();
    _observacaoController = TextEditingController();
  }

  @override
  void dispose() {
    _observacaoController.dispose();
    super.dispose();
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE7E5),
        elevation: 0,
        title: Text(
          'Carrinho',
          style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18.sp),
        ),
        centerTitle: true,
      ),
      body: Consumer2<CartProvider, EnderecoProvider>(
        builder: (context, cartProvider, enderecoProvider, child) {
          if (cartProvider.itens.isEmpty) {
            return _buildEmptyCart();
          }

          if (_observacaoController.text != cartProvider.observacao) {
            _observacaoController.text = cartProvider.observacao;
          }

          final defaultAddress = enderecoProvider.enderecos.isEmpty
              ? null
              : enderecoProvider.enderecos.firstWhere(
                  (e) => e.isPadrao,
                  orElse: () => enderecoProvider.enderecos.first,
                );

          // Esta página fica dentro de um Stack (home_page.dart) com a barra
          // flutuante "Continuar" e a navbar sobrepostas por cima do
          // conteúdo. Sem esse respiro extra no final, elas cobrem o campo
          // de observações.
          final espacoParaBarraFlutuante =
              MediaQuery.of(context).padding.bottom + 220.h;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  padding: EdgeInsets.fromLTRB(
                      16.w, 0, 16.w, espacoParaBarraFlutuante),
                  children: [
                    SizedBox(height: 8.h),
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
                      child: _buildAddressSection(context, defaultAddress),
                    ),
                    SizedBox(height: 24.h),
                    ...cartProvider.itens.values
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return TweenAnimationBuilder<double>(
                        key: ValueKey('anim_${item.produtoId}'),
                        duration: const Duration(milliseconds: 800),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Interval(
                          (index * 0.1).clamp(0.0, 0.5),
                          1.0,
                          curve: Curves.easeOutCubic,
                        ),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(50 * (1 - value), 0),
                              child: child,
                            ),
                          );
                        },
                        child: _buildCartItem(item, cartProvider),
                      );
                    }),
                    _buildObservacaoField(cartProvider),
                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 80.r, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text(
            'Seu carrinho está vazio',
            style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey),
          ),
        ],
      ),
    );
  }

  

  Widget _buildAddressSection(BuildContext context, EnderecoModel? address) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6961).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_on_outlined,
                color: primaryColor, size: 20.r),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Endereço de entrega',
                    style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
                SizedBox(height: 4.h),
                Text(
                  address != null
                      ? '${address.rua}, ${address.numero} - ${address.bairro}'
                      : 'Nenhum endereço selecionado',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                      color: const Color(0xFF5D201C)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _mostrarSelecaoEndereco(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey[100],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r)),
              padding: EdgeInsets.symmetric(horizontal: 16.w),
            ),
            child: Text('Alterar',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp)),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarSelecaoEndereco(BuildContext context) async {
    final enderecoProvider = context.read<EnderecoProvider>();
    final enderecos = enderecoProvider.enderecos;
    if (enderecos.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
          title: const Text('Nenhum endereço salvo'),
          content: const Text(
              'Você ainda não possui endereços cadastrados. Deseja adicionar um agora?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                context.push('/enderecos-salvos');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFE645C),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r)),
              ),
              child: const Text('Adicionar'),
            ),
          ],
        ),
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddressSelectionSheet(enderecos: enderecos),
    );
    await enderecoProvider.buscarEnderecos();
    setState(() {});
  }

  Widget _buildObservacaoField(CartProvider cartProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16.h),
        Text(
          'Observações para o restaurante',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15.sp,
              color: const Color(0xFF5D201C)),
        ),
        SizedBox(height: 12.h),
        Semantics(
          label: 'Observações para o restaurante',
          child: TextField(
            controller: _observacaoController,
            maxLines: 3,
            maxLength: 200,
            decoration: InputDecoration(
              hintText:
                  'Ex: Tirar cebola, maionese à parte, troco para R\$ 50...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14.sp),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.all(16.w),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: BorderSide(color: Colors.white)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide:
                    BorderSide(color: primaryColor.withValues(alpha: 0.5)),
              ),
            ),
            onChanged: (value) => cartProvider.setObservacao(value),
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(CartItemModel item, CartProvider cartProvider) {
    double swipeProgress = 0.0;
    bool hasVibrated = false;
    bool isProgrammaticDeleting = false;

    return StatefulBuilder(
      key: E2EKeys.cartItem(item.produtoId),
      builder: (context, setState) {
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: isProgrammaticDeleting ? 500 : 0),
          curve: Curves.easeOutQuart,
          tween: Tween(begin: 0.0, end: isProgrammaticDeleting ? 1.0 : 0.0),
          onEnd: () {
            if (isProgrammaticDeleting) {
              cartProvider.excluirItemDoCarrinho(item.produtoId);
            }
          },
          builder: (context, t, child) {
            double slideValue = (t / 0.6).clamp(0.0, 1.0);
            double heightValue = 1.0 - ((t - 0.15) / 0.85).clamp(0.0, 1.0);
            double opacityValue = (1.0 - (t / 0.4)).clamp(0.0, 1.0);

            return ClipRect(
              child: Align(
                heightFactor: isProgrammaticDeleting ? heightValue : 1.0,
                alignment: Alignment.topCenter,
                child: Stack(
                  children: [
                    if (isProgrammaticDeleting)
                      Positioned.fill(
                        child: Container(
                          margin: EdgeInsets.only(bottom: 16.h),
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          decoration: BoxDecoration(
                            color:
                                primaryColor.withValues(alpha: 0.4 + (0.6 * t)),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          alignment: Alignment.centerRight,
                          child: Transform.scale(
                            scale: 0.8 + (0.6 * t),
                            child: Opacity(
                              opacity: (t * 2).clamp(0.0, 1.0),
                              child: Icon(Icons.delete_sweep_rounded,
                                  color: Colors.white, size: 28.r),
                            ),
                          ),
                        ),
                      ),
                    Transform.translate(
                      offset: Offset(
                          -slideValue * MediaQuery.of(context).size.width, 0),
                      child: Dismissible(
                        key: Key(item.produtoId),
                        direction: isProgrammaticDeleting
                            ? DismissDirection.none
                            : DismissDirection.endToStart,
                        resizeDuration: const Duration(milliseconds: 350),
                        movementDuration: const Duration(milliseconds: 350),
                        onUpdate: (details) {
                          setState(() => swipeProgress = details.progress);
                          if (details.reached && !hasVibrated) {
                            HapticFeedback.mediumImpact();
                            hasVibrated = true;
                            // ignore: curly_braces_in_flow_control_structures
                          } else if (!details.reached) hasVibrated = false;
                        },
                        onDismissed: (direction) {
                          if (!isProgrammaticDeleting) {
                            cartProvider.excluirItemDoCarrinho(item.produtoId);
                          }
                        },
                        background: Container(
                          margin: EdgeInsets.only(bottom: 16.h),
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(
                                alpha: 0.4 + (0.6 * swipeProgress)),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          alignment: Alignment.centerRight,
                          child: Transform.scale(
                            scale: 0.8 + (0.6 * swipeProgress),
                            child: Opacity(
                              opacity: (swipeProgress * 2).clamp(0.0, 1.0),
                              child: Icon(Icons.delete_sweep_rounded,
                                  color: Colors.white, size: 28.r),
                            ),
                          ),
                        ),
                        child: Transform.scale(
                          scale: isProgrammaticDeleting
                              ? (1.0 - (slideValue * 0.12)).clamp(0.88, 1.0)
                              : (1.0 - (swipeProgress * 0.1)).clamp(0.9, 1.0),
                          child: Opacity(
                            opacity: isProgrammaticDeleting
                                ? opacityValue
                                : (1.0 - (swipeProgress * 1.8)).clamp(0.0, 1.0),
                            child: Container(
                              margin: EdgeInsets.only(bottom: 16.h),
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10.r,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 80.w,
                                    height: 80.w,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12.r),
                                      child: item.esgotado
                                          ? ColorFiltered(
                                              colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                                              child: Image.network(
                                                item.imagemUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    Icon(Icons.image, color: Colors.grey, size: 24.r),
                                              ),
                                            )
                                          : Image.network(
                                              item.imagemUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  Icon(Icons.image, color: Colors.grey, size: 24.r),
                                            ),
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.nome,
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14.sp,
                                                        color: item.esgotado ? Colors.grey : Colors.black,
                                                        decoration: item.esgotado ? TextDecoration.lineThrough : null),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  if (item.esgotado)
                                                    Text(
                                                      'Esgotado',
                                                      style: TextStyle(color: Colors.red, fontSize: 12.sp, fontWeight: FontWeight.bold),
                                                    ),
                                                  SizedBox(height: 8.h),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        height: 32.h,
                                                        decoration:
                                                            BoxDecoration(
                                                          border: Border.all(
                                                              color: Colors
                                                                  .grey[300]!),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      16.r),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Semantics(
                                                              button: true,
                                                              label: 'Diminuir quantidade',
                                                              child: IconButton(
                                                                padding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                constraints:
                                                                    const BoxConstraints(
                                                                        minWidth:
                                                                            32),
                                                                icon: Icon(
                                                                    Icons.remove,
                                                                    size: 16.r),
                                                                onPressed: () async {
                                                                  try {
                                                                    await cartProvider.removerItem(item.produtoId);
                                                                  } catch (e) {
                                                                    if (context.mounted) context.showError(e.toString());
                                                                  }
                                                                },
                                                              ),
                                                            ),
                                                            Semantics(
                                                              key: E2EKeys
                                                                  .cartItemQuantity(
                                                                      item.produtoId),
                                                              value: item
                                                                  .quantidade
                                                                  .toString(),
                                                              child: Text(
                                                                item.quantidade
                                                                    .toString(),
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        14.sp),
                                                              ),
                                                            ),
                                                            Semantics(
                                                              button: true,
                                                              label: 'Aumentar quantidade',
                                                              child: IconButton(
                                                                padding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                constraints:
                                                                    const BoxConstraints(
                                                                        minWidth:
                                                                            32),
                                                                icon: Icon(
                                                                    Icons.add,
                                                                    size: 16.r),
                                                                onPressed: item.esgotado ? null : () async {
                                                                  try {
                                                                    await cartProvider.adicionarItemComQuantidade(
                                                                      idProduto: item.produtoId, 
                                                                      nome: item.nome,
                                                                      preco: item.preco,
                                                                      imagemUrl: item.imagemUrl,
                                                                      lojaId: item.lojaId,
                                                                      quantidade: 1, 
                                                                    );
                                                                  } catch (e) {
                                                                    if (context.mounted) context.showError(e.toString());
                                                                  }
                                                                },
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      SizedBox(width: 16.w),
                                                      GestureDetector(
                                                        onTap: () {
                                                          HapticFeedback
                                                              .lightImpact();
                                                          setState(() =>
                                                              isProgrammaticDeleting =
                                                                  true);
                                                        },
                                                        child: Icon(
                                                            Icons
                                                                .delete_outline,
                                                            color: primaryColor,
                                                            size: 22.r),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                item.esgotado 
                                                  ? ColorFiltered(
                                                      colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                                                      child: Text(
                                                        currencyFormat
                                                            .format(item.preco),
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 14.sp),
                                                      ),
                                                    )
                                                  : Text(
                                                      currencyFormat
                                                          .format(item.preco),
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14.sp),
                                                    ),
                                                SizedBox(height: 4.h),
                                                Semantics(
                                                  key: E2EKeys.cartStoreId,
                                                  value: item.lojaId,
                                                  child: Text(
                                                    '${item.quantidade} un',
                                                    style: TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 12.sp),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 16.h),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AddressSelectionSheet extends StatelessWidget {
  final List<EnderecoModel> enderecos;
  const _AddressSelectionSheet({required this.enderecos});

  @override
  Widget build(BuildContext context) {
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
                borderRadius: BorderRadius.circular(2.r)),
          ),
          SizedBox(height: 24.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Selecione o endereço de entrega',
                style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF5D201C)),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              itemCount: enderecos.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final endereco = enderecos[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () async {
                    await context
                        .read<EnderecoProvider>()
                        .definirComoPadrao(endereco.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  leading: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6961).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      endereco.bairro.toLowerCase().contains('trabalho') ||
                              endereco.complemento
                                  !.toLowerCase()
                                  .contains('trabalho')
                          ? Icons.work_outline
                          : Icons.home_outlined,
                      color: const Color(0xFFFF6961),
                      size: 20.r,
                    ),
                  ),
                  title: Text('${endereco.rua}, ${endereco.numero}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15.sp)),
                  subtitle: Text(
                    '${endereco.bairro}${endereco.complemento!.isNotEmpty ? ' - ${endereco.complemento}' : ''}',
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
              onTap: () => context.push('/enderecos-salvos'),
              borderRadius: BorderRadius.circular(12.r),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100, shape: BoxShape.circle),
                      child: Icon(Icons.add, color: Colors.grey, size: 20.r),
                    ),
                    SizedBox(width: 16.w),
                    Text('Adicionar novo endereço',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                            color: Colors.grey)),
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
