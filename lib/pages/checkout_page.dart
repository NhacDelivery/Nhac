import 'package:flutter/material.dart';
import 'package:nhac/models/usuario/cupom_model.dart';
import 'package:nhac/repositories/cupom_repository.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nhac/pages/qrcode_pix_page.dart';
import 'package:go_router/go_router.dart';
import 'package:geocoding/geocoding.dart';
import 'package:nhac/models/pedido/criar_pedido_request.dart';
import 'package:uuid/uuid.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:nhac/controllers/cart_provider.dart';
import 'package:nhac/controllers/endereco_provider.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/components/botoes/botao_largo_nhac.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:nhac/globals/ui_utils.dart';
import 'package:nhac/e2e/e2e_keys.dart';
import 'package:nhac/globals/app_constants.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  CupomModel? _cupom;
  double? _subtotalValidado;
  String _formaPagamento = 'Dinheiro';
  final TextEditingController _trocoController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();

  bool _mostrarCampoTroco = true;
  final NumberFormat currencyFormat =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  bool _isLoading = true;
  bool _isSubmitting = false;

  double _taxaFrete = 0.0;
  int? _tempoEstimadoMinutos;
  String? _checkoutIdempotencyKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarDadosIniciais();
    });
  }

  Future<void> _carregarDadosIniciais() async {
    await _verificarNumeroEndereco();
    if (!mounted) return;

    final cartProvider = context.read<CartProvider>();
    final enderecoProvider = context.read<EnderecoProvider>();
    if (cartProvider.lojaId.isNotEmpty &&
        enderecoProvider.enderecos.isNotEmpty) {
      final endereco = enderecoProvider.enderecos.firstWhere(
        (e) => e.isPadrao,
        orElse: () => enderecoProvider.enderecos.first,
      );
      await _recalcularFrete(endereco);
    }
  }

  Future<void> _recalcularFrete(EnderecoModel endereco) async {
    final cartProvider = context.read<CartProvider>();
    if (cartProvider.lojaId.isEmpty) return;

    try {
      double latitude;
      double longitude;
      if (AppConstants.e2eMode) {
        latitude = AppConstants.e2eLatitude;
        longitude = AppConstants.e2eLongitude;
      } else {
        final enderecoCompleto = [
          endereco.rua,
          endereco.numero,
          endereco.bairro,
          endereco.cidade,
          endereco.estado,
          endereco.cep,
        ].where((v) => v.trim().isNotEmpty).join(', ');
        final locais = await locationFromAddress(enderecoCompleto);
        if (locais.isEmpty) return;
        latitude = locais.first.latitude;
        longitude = locais.first.longitude;
      }
      final resposta = await LojaRepository().calcularFrete(
        cartProvider.lojaId,
        lat: latitude,
        lng: longitude,
      );
      if (!mounted) return;
      setState(() {
        _taxaFrete = resposta.valor;
        _tempoEstimadoMinutos = resposta.tempoEstimadoMinutos;
      });
    } catch (e) {
      debugPrint('Não foi possível recalcular o frete: $e');
      final loja = await LojaRepository().buscarLoja(cartProvider.lojaId);
      if (loja != null && mounted) {
        setState(() {
          _taxaFrete = loja.dadosOperacionais?.taxaEntregaBase ?? 0.0;
          _tempoEstimadoMinutos = loja.dadosOperacionais?.tempoEntregaMax;
        });
      }
    }
  }

  Future<void> _verificarNumeroEndereco() async {
    if (!mounted) return;
    final enderecoProvider = context.read<EnderecoProvider>();
    final EnderecoModel? enderecoisPadrao = enderecoProvider.enderecos.isEmpty
        ? null
        : enderecoProvider.enderecos.firstWhere(
            (e) => e.isPadrao,
            orElse: () => EnderecoModel(
              id: '',
              bairro: '',
              cep: '',
              cidade: '',
              estado: '',
              numero: '',
              rua: '',
            ),
          );
    if (enderecoisPadrao != null &&
        enderecoisPadrao.id.isNotEmpty &&
        enderecoisPadrao.numero.isEmpty) {
      await _pedirNumeroEndereco(enderecoisPadrao);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pedirNumeroEndereco(EnderecoModel endereco) async {
    final TextEditingController numeroController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.home, color: const Color(0xFFFF6961), size: 28.r),
            SizedBox(width: 12.w),
            Text(
              'Número da casa',
              style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF5D201C)),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Para completar seu endereço, informe o número da casa.',
                style:
                    TextStyle(fontSize: 14.sp, color: const Color(0xFF5D201C)),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: numeroController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Número (ex: 123, S/N)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Campo obrigatório'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Cancelar', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final numero = numeroController.text.trim();
                final enderecoAtualizado = endereco.copyWith(numero: numero);

                await context.read<EnderecoProvider>().atualizarEndereco(
                    enderecoAtualizado.id, enderecoAtualizado);

                if (!mounted) return;
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFE645C),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50.r)),
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _trocoController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final enderecoProvider = Provider.of<EnderecoProvider>(context);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFE7E5),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final EnderecoModel? enderecoisPadrao = enderecoProvider.enderecos.isEmpty
        ? null
        : enderecoProvider.enderecos.firstWhere(
            (e) => e.isPadrao,
            orElse: () => enderecoProvider.enderecos.first,
          );

    final subtotal = cartProvider.valorTotal;
    final frete = _taxaFrete;

    final desconto = _subtotalValidado == subtotal ? (_cupom?.descontoAplicado ?? 0) : 0.0;
    final total = subtotal + frete - desconto;
    final tempoEntrega = _tempoEstimadoMinutos == null
        ? 'Tempo calculado no fechamento'
        : 'Até $_tempoEstimadoMinutos min';
    final podeFinalizar =
        enderecoisPadrao != null && enderecoisPadrao.numero.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE7E5),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: const Color(0xFF5D201C), size: 20.r),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Finalizar Pedido',
          style: TextStyle(
            color: const Color(0xFF5D201C),
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Endereço de entrega'),
            SizedBox(height: 8.h),
            Container(
              key: E2EKeys.checkoutAddress,
              padding: EdgeInsets.all(16.w),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6961).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.location_on_outlined,
                        color: const Color(0xFFFF6961), size: 20.r),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          enderecoisPadrao != null
                              ? '${enderecoisPadrao.rua}, ${enderecoisPadrao.numero}'
                              : 'Nenhum endereço selecionado',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                            color: const Color(0xFF5D201C),
                          ),
                        ),
                        if (enderecoisPadrao != null) ...[
                          SizedBox(height: 4.h),
                          Text(
                            '${enderecoisPadrao.bairro} - ${enderecoisPadrao.cidade}/${enderecoisPadrao.estado}',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12.sp),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _selecionarEndereco(context),
                    child: Text(
                      'Alterar',
                      style: TextStyle(
                          color: const Color(0xFFFF6961),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            _buildSectionTitle('Forma de pagamento'),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  _buildPaymentOption('Dinheiro', Icons.money),
                  _buildPaymentOption('Cartão de crédito', Icons.credit_card),
                  _buildPaymentOption('PIX', Icons.pix),
                ],
              ),
            ),
            if (_formaPagamento == 'PIX') ...[
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CPF para pagamento PIX',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                          color: const Color(0xFF5D201C)),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _cpfController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Digite seu CPF (obrigatório)',
                        hintStyle: TextStyle(
                            color: Colors.grey.shade400, fontSize: 14.sp),
                        prefixIcon: Icon(Icons.person,
                            size: 20.r, color: Colors.grey.shade600),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_mostrarCampoTroco) ...[
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Precisa de troco?',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                          color: const Color(0xFF5D201C)),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _trocoController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Valor para troco (ex: 50,00)',
                        hintStyle: TextStyle(
                            color: Colors.grey.shade400, fontSize: 14.sp),
                        prefixIcon: Icon(Icons.money,
                            size: 20.r, color: Colors.grey.shade600),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 24.h),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_offer_outlined),
              title: Text(_cupom == null ? 'Adicionar cupom' : _cupom!.titulo),
              subtitle: _cupom == null ? null : Text(
                _subtotalValidado == subtotal
                    ? 'Desconto de ${currencyFormat.format(desconto)}'
                    : 'Carrinho alterado. Selecione o cupom novamente.',
              ),
              onTap: _isSubmitting ? null : () async {
                final cupom = await context.push<CupomModel>('/cupons', extra: subtotal);
                if (!mounted || cupom == null) return;
                setState(() {
                  _cupom = cupom;
                  _subtotalValidado = subtotal;
                });
              },
              trailing: _cupom == null ? const Icon(Icons.chevron_right) : IconButton(
                tooltip: 'Remover cupom',
                onPressed: _isSubmitting ? null : () => setState(() {
                  _cupom = null;
                  _subtotalValidado = null;
                }),
                icon: const Icon(Icons.close),
              ),
            ),
            SizedBox(height: 16.h),
            _buildSectionTitle('Resumo do pedido'),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  ...cartProvider.itens.values.map((item) => Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: Row(
                          children: [
                            Text(
                              '${item.quantidade}x',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14.sp),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                item.nome,
                                style: TextStyle(
                                    fontSize: 14.sp, color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              currencyFormat
                                  .format(item.preco * item.quantidade),
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14.sp),
                            ),
                          ],
                        ),
                      )),
                  if (cartProvider.observacao.isNotEmpty) ...[
                    Divider(height: 24.h, color: Colors.grey.shade200),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note_outlined,
                            size: 18.r, color: Colors.grey.shade600),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Observações: ${cartProvider.observacao}',
                            style: TextStyle(
                                fontSize: 13.sp, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ],
                  Divider(height: 24.h, color: Colors.grey.shade200),
                  MergeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal',
                            style: TextStyle(
                                color: Colors.grey.shade700, fontSize: 14.sp)),
                        Text(currencyFormat.format(subtotal),
                            style: TextStyle(fontSize: 14.sp)),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  if (desconto > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Desconto do cupom'),
                          Text('- ${currencyFormat.format(desconto)}'),
                        ],
                      ),
                    ),
                  MergeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Frete',
                            style: TextStyle(
                                color: Colors.grey.shade700, fontSize: 14.sp)),
                        Text(
                          currencyFormat.format(frete),
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  MergeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.sp,
                              color: const Color(0xFF5D201C)),
                        ),
                        Semantics(
                          key: E2EKeys.checkoutTotal,
                          value: total.toStringAsFixed(2),
                          child: Text(
                            currencyFormat.format(total),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18.sp,
                                color: const Color(0xFFFF6961)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            _buildSectionTitle('Previsão de entrega'),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined,
                      color: const Color(0xFFFF6961), size: 24.r),
                  SizedBox(width: 12.w),
                  Text(
                    tempoEntrega,
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF5D201C)),
                  ),
                ],
              ),
            ),
            SizedBox(height: 40.h),
            BotaoLargoNhac(
              key: E2EKeys.checkoutConfirm,
              texto: _isSubmitting ? 'Enviando pedido...' : 'Confirmar pedido',
              onPressed: (podeFinalizar && !_isSubmitting)
                  ? () => _confirmarPedido(context, total, cartProvider)
                  : null,
            ),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18.sp,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF5D201C),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 10.r,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildPaymentOption(String title, IconData icon) {
    final isSelected = _formaPagamento == title;
    return Semantics(
      key: title == 'Dinheiro' ? E2EKeys.checkoutCash : null,
      button: true,
      label:
          'Forma de pagamento $title. ${isSelected ? "Selecionada" : "Toque para selecionar"}',
      child: GestureDetector(
        onTap: () {
          setState(() {
            _formaPagamento = title;
            _mostrarCampoTroco = (title == 'Dinheiro');
            if (!_mostrarCampoTroco) _trocoController.clear();
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Row(
            children: [
              Icon(icon,
                  size: 24.r,
                  color: isSelected
                      ? const Color(0xFFFF6961)
                      : Colors.grey.shade500),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color:
                        isSelected ? const Color(0xFFFF6961) : Colors.black87,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle,
                    color: const Color(0xFFFF6961), size: 20.r),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selecionarEndereco(BuildContext context) async {
    final enderecoProvider = context.read<EnderecoProvider>();
    final enderecos = enderecoProvider.enderecos;

    if (enderecos.isEmpty) {
      _mostrarDialogEnderecoVazio(context);
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddressSelectionSheet(enderecos: enderecos),
    );
    await enderecoProvider.buscarEnderecos();
    if (!mounted) return;
    final atualizado = enderecoProvider.enderecos.firstWhere(
      (e) => e.isPadrao,
      orElse: () => enderecoProvider.enderecos.first,
    );
    await _recalcularFrete(atualizado);
    if (mounted) setState(() {});
  }

  void _mostrarDialogEnderecoVazio(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.location_off_outlined,
                color: const Color(0xFFFF6961), size: 28.r),
            SizedBox(width: 12.w),
            Text(
              'Sem endereço',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5D201C),
              ),
            ),
          ],
        ),
        content: Text(
          'Você precisa adicionar um endereço de entrega antes de finalizar o pedido.',
          style: TextStyle(fontSize: 14.sp, color: const Color(0xFF5D201C)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                  color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/enderecos-salvos');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFE645C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50.r)),
            ),
            child: const Text('Adicionar endereço'),
          ),
        ],
      ),
    );
  }

  String _formaPagamentoApi() {
    switch (_formaPagamento) {
      case 'Cartão de crédito':
        return 'CARTAO';
      case 'PIX':
        return 'PIX';
      case 'Dinheiro':
      default:
        return 'DINHEIRO';
    }
  }

  Future<void> _confirmarPedido(
      BuildContext context, double total, CartProvider cartProvider) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final enderecoProvider = context.read<EnderecoProvider>();
    if (enderecoProvider.enderecos.isEmpty) {
      setState(() => _isSubmitting = false);
      context.showError('Adicione um endereço de entrega.');
      return;
    }
    final enderecoisPadrao = enderecoProvider.enderecos.firstWhere(
      (e) => e.isPadrao,
      orElse: () => enderecoProvider.enderecos.first,
    );

    final authService = context.read<AuthService>();
    final uid = authService.usuarioId;
    if (uid == null) {
      setState(() => _isSubmitting = false);
      context.showError('Sessão expirada. Faça login novamente.');
      context.go('/bem-vindo');
      return;
    }

    final trocoText = _trocoController.text
        .replaceAll(RegExp(r'[^0-9,]'), '')
        .replaceAll(',', '.');
    final trocoPara = (_formaPagamento == 'Dinheiro' && trocoText.isNotEmpty)
        ? double.tryParse(trocoText)
        : null;

    final cpfPagador = _cpfController.text.replaceAll(RegExp(r'\D'), '');
    if (_formaPagamento == 'PIX' && cpfPagador.isEmpty) {
      setState(() => _isSubmitting = false);
      context.showError('CPF é obrigatório para pagamento via PIX.');
      return;
    }

    if (_cupom != null) {
      try {
        final validado = await CupomRepository().validarCupom(_cupom!.id, cartProvider.valorTotal);
        if (!mounted) return;
        setState(() {
          _cupom = validado;
          _subtotalValidado = cartProvider.valorTotal;
        });
        total = cartProvider.valorTotal + _taxaFrete - validado.descontoAplicado;
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        context.showError(e.toString());
        return;
      }
    }

    final pedido = CriarPedidoRequest(
      lojaId: cartProvider.lojaId,
      cupomId: _cupom?.id,
      formaPagamento: _formaPagamentoApi(),
      trocoPara: trocoPara,
      cpfPagador: _formaPagamento == 'PIX' ? cpfPagador : null,
      observacao: cartProvider.observacao,
      enderecoEntrega: enderecoisPadrao,
      itens: cartProvider.itens.values
          .map(CriarPedidoItemRequest.fromCartItem)
          .toList(),
    );

    final navigator = Navigator.of(context, rootNavigator: true);

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6961))),
      );

      _checkoutIdempotencyKey ??= const Uuid().v4();
      final respostaPedido = await PedidoRepository().finalizarPedido(
        pedido,
        idempotencyKey: _checkoutIdempotencyKey!,
      );
      final idGerado = respostaPedido.pedidoId;
      final clientSecret = respostaPedido.clientSecret;
      final pixCopiaECola = respostaPedido.pixCopiaECola;
      final qrCodeUrl = respostaPedido.qrCodeUrl;

      navigator.pop(); // Close loading

      if (!context.mounted) return;

      final pagamentoEletronico =
          _formaPagamento == 'Cartão de crédito' || _formaPagamento == 'PIX';
      final artefatoPagamentoAusente =
          (_formaPagamento == 'Cartão de crédito' &&
                  (clientSecret == null || clientSecret.isEmpty)) ||
              (_formaPagamento == 'PIX' &&
                  (pixCopiaECola == null || pixCopiaECola.isEmpty));

      if (respostaPedido.replay &&
          pagamentoEletronico &&
          artefatoPagamentoAusente) {
        await cartProvider.esvaziarCarrinho();
        if (!context.mounted) return;
        context.showSuccess(
          'Esse pedido já havia sido criado. Acompanhe o status no rastreio.',
        );
        context.go('/rastreio?pedidoId=$idGerado');
        return;
      }

      if (_formaPagamento == 'Cartão de crédito' &&
          clientSecret != null &&
          clientSecret.isNotEmpty) {
        try {
          await Stripe.instance.initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
              paymentIntentClientSecret: clientSecret,
              merchantDisplayName: 'Nhac Delivery',
            ),
          );
          await Stripe.instance.presentPaymentSheet();

          if (!context.mounted) return;

          // Polling curto: verifica o status real do pedido no backend.
          // Se o webhook ainda não tiver sido processado, o app segue para o
          // rastreio exibindo "aguardando confirmação", sem afirmar que o
          // pagamento já foi confirmado pelo servidor.
          final pedidoRepo = PedidoRepository();
          bool statusConfirmado = false;

          for (int i = 0; i < 3; i++) {
            try {
              await Future.delayed(const Duration(seconds: 2));
              if (!context.mounted) return;
              final pedidoAtual =
                  await pedidoRepo.buscarPedidoPorId(idGerado.toString());
              if (pedidoAtual.status.pagamentoConfirmado) {
                statusConfirmado = true;
                break;
              }
            } catch (_) {
              // O rastreio continuará acompanhando o status pelo backend.
            }
          }

          if (!context.mounted) return;
          if (statusConfirmado) {
            _exibirSucessoEVoltar(idGerado.toString(), cartProvider);
          } else {
            await cartProvider.esvaziarCarrinho();
            if (!context.mounted) return;
            context.showSuccess(
              'Pagamento enviado. Estamos aguardando a confirmação do backend.',
            );
            context.go('/rastreio?pedidoId=$idGerado');
          }
        } on StripeException {
          await cartProvider.esvaziarCarrinho();
          _checkoutIdempotencyKey = null;
          if (!context.mounted) return;
          context.showError(
            'O pedido foi criado, mas o pagamento não foi confirmado. '
            'Acompanhe o pedido antes de tentar uma nova compra.',
          );
          context.go('/rastreio?pedidoId=$idGerado');
          return;
        }
      } else if (_formaPagamento == 'PIX') {
        // Esvaziar carrinho — o pedido já foi criado no backend com sucesso,
        // independentemente de o PIX ter sido pago ou não.
        await cartProvider.esvaziarCarrinho();
        if (!context.mounted) return;
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QrCodePixPage(
                pixQrCode: qrCodeUrl ?? pixCopiaECola ?? '',
                pixCopiaECola: pixCopiaECola,
                paymentId: idGerado.toString(),
                valor: total,
              ),
            ));
      } else {
        // Dinheiro
        _exibirSucessoEVoltar(idGerado.toString(), cartProvider);
      }
    } on CustomCheckoutException catch (e) {
      // Resposta de negócio é definitiva; a próxima tentativa pode gerar uma
      // nova chave (por exemplo, após um conflito 409 de payload alterado).
      _checkoutIdempotencyKey = null;
      navigator.pop(); // Close loading
      if (!context.mounted) return;
      setState(() => _isSubmitting = false);

      if (e.produtoId != null) {
        cartProvider.marcarItemComoEsgotado(e.produtoId!);
      }

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text(e.title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.message),
              if (e.suggestions != null && e.suggestions!.isNotEmpty) ...[
                SizedBox(height: 16.h),
                const Text('Sugestões:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...e.suggestions!.map((s) => Text('• $s')),
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
    } catch (e) {
      navigator.pop(); // Close loading
      if (!context.mounted) return;
      setState(() => _isSubmitting = false);
      context.showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _exibirSucessoEVoltar(String idGerado, CartProvider cartProvider) {
    _checkoutIdempotencyKey = null;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: E2EKeys.checkoutSuccess,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        backgroundColor: Colors.white,
        title: Text(
          'Pedido confirmado!',
          style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF5D201C)),
        ),
        content: Semantics(
          key: E2EKeys.checkoutSuccessOrderId,
          value: idGerado,
          child: Text(
            'O seu pedido foi recebido com sucesso!\n\nID do Pedido: $idGerado',
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFF5D201C)),
          ),
        ),
        actions: [
          ElevatedButton(
            key: E2EKeys.checkoutSuccessContinue,
            onPressed: () {
              cartProvider.esvaziarCarrinho();
              Navigator.of(dialogContext).pop();
              if (context.mounted) context.go('/rastreio?pedidoId=$idGerado');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFE645C),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50.r)),
            ),
            child: const Text('Voltar ao Início',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
                  ),
                  subtitle: Text(
                    '${endereco.bairro}${(endereco.complemento?.isNotEmpty ?? false) ? ' - ${endereco.complemento}' : ''}',
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
              child: Container(
                constraints: BoxConstraints(minHeight: 48.h),
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
                    Text(
                      'Adicionar novo endereço',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15.sp,
                          color: Colors.grey),
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
