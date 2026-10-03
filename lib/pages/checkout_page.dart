import 'package:nhac/components/selecionar_endereco_padrao.dart';
import 'package:flutter/material.dart';
import 'package:nhac/components/nota_fiscal_pedido.dart';
import 'package:nhac/models/usuario/cupom_model.dart';
import 'package:nhac/repositories/cupom_repository.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:geocoding/geocoding.dart';
import 'package:nhac/models/pedido/criar_pedido_request.dart';
import 'package:nhac/services/checkout_tentativa_service.dart';
import 'package:nhac/components/estado_com_retry.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:nhac/controllers/cart_provider.dart';
import 'package:nhac/controllers/endereco_provider.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/components/botoes/botao_largo_nhac.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:nhac/globals/ui_utils.dart';
import 'package:nhac/e2e/e2e_keys.dart';
import 'package:nhac/globals/app_constants.dart';
import 'package:nhac/services/local_cache_service.dart';

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
  final NumberFormat currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );
  bool _isLoading = true;
  bool _isSubmitting = false;

  double _taxaFrete = 0.0;
  bool _freteConfirmado = false;
  double? _entregaLatitude, _entregaLongitude;
  int _freteVersao = 0;
  int? _tempoEstimadoMinutos;
  final _tentativasCheckout = CheckoutTentativaService();
  Map<String, dynamic>? _tentativaPendente;
  String? _erroTentativa;
  bool _consultandoTentativa = true;

  Future<void> _consultarTentativa() async {
    final uid = context.read<AuthService>().usuarioId;
    if (uid == null) return;
    try {
      final tentativa = await _tentativasCheckout.carregar(uid);
      if (!mounted || context.read<AuthService>().usuarioId != uid) return;
      setState(() {
        _tentativaPendente = tentativa;
        _erroTentativa = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _erroTentativa =
            'Não foi possível conferir a tentativa anterior. Tente novamente antes de criar um pedido.');
      }
    } finally {
      if (mounted) setState(() => _consultandoTentativa = false);
    }
  }

  Future<void> _recuperarTentativa() async {
    if (_isSubmitting || _tentativaPendente == null) return;
    final auth = context.read<AuthService>();
    final uid = auth.usuarioId;
    if (uid == null) return;
    final pagamento = (_tentativaPendente!['payload'] as Map)['formaPagamento'];
    setState(() => _isSubmitting = true);
    try {
      final resposta = await _tentativasCheckout.recuperar(uid);
      if (!mounted || auth.usuarioId != uid) return;
      await LocalCacheService.salvarPedidoAtivo(uid, resposta.pedidoId);
      await _tentativasCheckout.concluir(uid);
      if (!mounted || auth.usuarioId != uid) return;
      context.go(pagamento == 'DINHEIRO'
          ? '/rastreio?pedidoId=${Uri.encodeQueryComponent(resposta.pedidoId)}'
          : '/pagamento?pedidoId=${Uri.encodeQueryComponent(resposta.pedidoId)}');
    } catch (e) {
      if (mounted && auth.usuarioId == uid) {
        context.showError(e.toString().replaceFirst('Exception: ', ''));
      }
      if (mounted && auth.usuarioId == uid) await _consultarTentativa();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consultarTentativa();
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
    final versao = ++_freteVersao;
    setState(() {
      _freteConfirmado = false;
      _entregaLatitude = null;
      _entregaLongitude = null;
    });

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
        if (locais.length != 1) {
          throw StateError(
              'Não foi possível identificar um único local. Revise rua, número, cidade e CEP do endereço.');
        }
        latitude = locais.first.latitude;
        longitude = locais.first.longitude;
      }
      if (!latitude.isFinite ||
          !longitude.isFinite ||
          latitude.abs() > 90 ||
          longitude.abs() > 180 ||
          (latitude == 0 && longitude == 0)) {
        throw StateError(
            'O serviço de endereço não retornou coordenadas válidas. Revise o endereço.');
      }
      final resposta = await LojaRepository().calcularFrete(
        cartProvider.lojaId,
        lat: latitude,
        lng: longitude,
      );
      if (!mounted || versao != _freteVersao) return;
      setState(() {
        _taxaFrete = resposta.valor;
        _tempoEstimadoMinutos = resposta.tempoEstimadoMinutos;
        _freteConfirmado = true;
        _entregaLatitude = latitude;
        _entregaLongitude = longitude;
      });
    } catch (e) {
      debugPrint('Não foi possível recalcular o frete: $e');
      if (!mounted || versao != _freteVersao) return;
      context.showError(
        'Não foi possível confirmar o endereço e o frete: ${e.toString().replaceFirst('Bad state: ', '')}',
      );
      // Não apresenta a taxa base como se fosse um frete calculado.
      setState(() {
        _taxaFrete = 0;
        _tempoEstimadoMinutos = null;
      });
    }
  }

  Future<void> _verificarNumeroEndereco() async {
    if (!mounted) return;
    setState(() => _isLoading = false);
    final enderecoProvider = context.read<EnderecoProvider>();
    final EnderecoModel? enderecoisPadrao = enderecoProvider.enderecos.isEmpty
        ? null
        : enderecoProvider.enderecos.firstWhere(
            (e) => e.isPadrao,
            orElse: () => enderecoProvider.enderecos.first,
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
    final provider = context.read<EnderecoProvider>();
    bool salvando = false;
    String? erro;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
          builder: (ctx, atualizar) => PopScope(
              canPop: !salvando,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
                backgroundColor: Colors.white,
                title: Row(
                  children: [
                    Icon(Icons.home,
                        color: const Color(0xFFFF6961), size: 28.r),
                    SizedBox(width: 12.w),
                    Expanded(
                        child: Text(
                      'Número da casa',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5D201C),
                      ),
                    )),
                  ],
                ),
                content: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Para completar seu endereço, informe o número da casa.',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: const Color(0xFF5D201C),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      if (erro != null)
                        Text(erro!, style: const TextStyle(color: Colors.red)),
                      TextFormField(
                        enabled: !salvando,
                        controller: numeroController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Número (ex: 123, S/N)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Campo obrigatório'
                                : null,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        salvando ? null : () => Navigator.pop(dialogContext),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: salvando
                        ? null
                        : () async {
                            if (salvando || !formKey.currentState!.validate()) {
                              return;
                            }
                            atualizar(() {
                              salvando = true;
                              erro = null;
                            });
                            try {
                              await provider.atualizarEndereco(
                                  endereco.id,
                                  endereco.copyWith(
                                      numero: numeroController.text.trim()));
                              if (!mounted || !dialogContext.mounted) return;
                              Navigator.pop(dialogContext);
                              if (provider.erro != null) {
                                context.showInfo(provider.erro!);
                              }
                            } catch (_) {
                              if (ctx.mounted) {
                                atualizar(() => erro =
                                    'Não foi possível salvar o número. Tente novamente.');
                              }
                            } finally {
                              if (ctx.mounted) {
                                atualizar(() => salvando = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFE645C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50.r),
                      ),
                    ),
                    child: Text(salvando ? 'Salvando...' : 'Salvar'),
                  ),
                ],
              ))),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    numeroController.dispose();
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
      return const LoadingNhac(telaCheia: true);
    }

    final EnderecoModel? enderecoisPadrao = enderecoProvider.enderecos.isEmpty
        ? null
        : enderecoProvider.enderecos.firstWhere(
            (e) => e.isPadrao,
            orElse: () => enderecoProvider.enderecos.first,
          );

    final subtotal = cartProvider.valorTotal;
    final frete = _taxaFrete;

    final desconto =
        _subtotalValidado == subtotal ? (_cupom?.descontoAplicado ?? 0) : 0.0;
    final total = subtotal + frete - desconto;
    final tempoEntrega = _tempoEstimadoMinutos == null
        ? 'Tempo calculado no fechamento'
        : 'Até $_tempoEstimadoMinutos min';
    final podeFinalizar = !_consultandoTentativa &&
        _tentativaPendente == null &&
        _erroTentativa == null &&
        enderecoisPadrao != null &&
        enderecoisPadrao.numero.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE7E5),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: const Color(0xFF5D201C),
            size: 20.r,
          ),
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
            if (_erroTentativa != null)
              BannerErroInline(
                  mensagem: _erroTentativa!,
                  aoTentarNovamente: _consultarTentativa),
            if (_tentativaPendente != null) ...[
              const Text(
                  'Há uma tentativa anterior sem confirmação. Verifique o resultado antes de criar outro pedido.'),
              TextButton(
                  onPressed: _isSubmitting ? null : _recuperarTentativa,
                  child: Text(_isSubmitting
                      ? 'Verificando...'
                      : 'Verificar tentativa anterior')),
            ],
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
                    child: Icon(
                      Icons.location_on_outlined,
                      color: const Color(0xFFFF6961),
                      size: 20.r,
                    ),
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
                              color: Colors.grey.shade600,
                              fontSize: 12.sp,
                            ),
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
                        fontWeight: FontWeight.w600,
                      ),
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
                        color: const Color(0xFF5D201C),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _cpfController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Digite seu CPF (obrigatório)',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14.sp,
                        ),
                        prefixIcon: Icon(
                          Icons.person,
                          size: 20.r,
                          color: Colors.grey.shade600,
                        ),
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
                        color: const Color(0xFF5D201C),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _trocoController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Valor para troco (ex: 50,00)',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14.sp,
                        ),
                        prefixIcon: Icon(
                          Icons.money,
                          size: 20.r,
                          color: Colors.grey.shade600,
                        ),
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
            InkWell(
              onTap: _isSubmitting
                  ? null
                  : () async {
                      final cupom = await context.push<CupomModel>(
                        '/cupons',
                        extra: subtotal,
                      );
                      if (!mounted || cupom == null) return;
                      setState(() {
                        _cupom = cupom;
                        _subtotalValidado = subtotal;
                      });
                    },
              borderRadius: BorderRadius.circular(18.r),
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: const Color(0xFFFF6961).withValues(alpha: 0.14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5D201C).withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44.r,
                      height: 44.r,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6961).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Icon(
                        Icons.local_offer_rounded,
                        color: const Color(0xFFFF6961),
                        size: 22.r,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _cupom == null ? 'Adicionar cupom' : _cupom!.titulo,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF5D201C),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            _cupom == null
                                ? 'Veja seus cupons e economize neste pedido'
                                : (_subtotalValidado == subtotal
                                    ? 'Desconto de ${currencyFormat.format(desconto)} aplicado'
                                    : 'Carrinho alterado. Selecione o cupom novamente.'),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(
                                0xFF5D201C,
                              ).withValues(alpha: 0.58),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_cupom == null)
                      Icon(
                        Icons.chevron_right_rounded,
                        color: const Color(0xFF5D201C).withValues(alpha: 0.45),
                      )
                    else
                      IconButton(
                        tooltip: 'Remover cupom',
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() {
                                  _cupom = null;
                                  _subtotalValidado = null;
                                }),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFFFF6961),
                        ),
                      ),
                  ],
                ),
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
                  ...cartProvider.itens.values.map(
                    (item) => Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: Row(
                        children: [
                          Text(
                            '${item.quantidade}x',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.sp,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              item.nome,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            currencyFormat.format(item.preco * item.quantidade),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (cartProvider.observacao.isNotEmpty) ...[
                    Divider(height: 24.h, color: Colors.grey.shade200),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.note_outlined,
                          size: 18.r,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Observações: ${cartProvider.observacao}',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.grey.shade700,
                            ),
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
                        Text(
                          'Subtotal',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14.sp,
                          ),
                        ),
                        Text(
                          currencyFormat.format(subtotal),
                          style: TextStyle(fontSize: 14.sp),
                        ),
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
                        Text(
                          _freteConfirmado
                              ? 'Frete confirmado'
                              : 'Frete estimado',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14.sp,
                          ),
                        ),
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
                  if (!_freteConfirmado)
                    TextButton(
                      onPressed: enderecoisPadrao == null
                          ? null
                          : () => _recalcularFrete(enderecoisPadrao),
                      child: const Text(
                        'Frete ainda não confirmado para este endereço. Tentar novamente',
                      ),
                    ),
                  MergeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                            color: const Color(0xFF5D201C),
                          ),
                        ),
                        Semantics(
                          key: E2EKeys.checkoutTotal,
                          value: total.toStringAsFixed(2),
                          child: Text(
                            currencyFormat.format(total),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18.sp,
                              color: const Color(0xFFFF6961),
                            ),
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
                  Icon(
                    Icons.timer_outlined,
                    color: const Color(0xFFFF6961),
                    size: 24.r,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(tempoEntrega,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF5D201C),
                        )),
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
              Icon(
                icon,
                size: 24.r,
                color:
                    isSelected ? const Color(0xFFFF6961) : Colors.grey.shade500,
              ),
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
                Icon(
                  Icons.check_circle,
                  color: const Color(0xFFFF6961),
                  size: 20.r,
                ),
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
    if (!mounted || !context.mounted) return;
    await _verificarNumeroEndereco();
    if (!mounted || !context.mounted) return;
    if (enderecoProvider.enderecos.isEmpty) {
      _freteVersao++;
      setState(() {
        _freteConfirmado = false;
        _entregaLatitude = null;
        _entregaLongitude = null;
      });
      _mostrarDialogEnderecoVazio(context);
      return;
    }
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.location_off_outlined,
              color: const Color(0xFFFF6961),
              size: 28.r,
            ),
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
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.push('/enderecos-salvos');
              if (!mounted) return;
              await _carregarDadosIniciais();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFE645C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50.r),
              ),
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
    BuildContext context,
    double total,
    CartProvider cartProvider,
  ) async {
    if (_isSubmitting ||
        _consultandoTentativa ||
        _tentativaPendente != null ||
        _erroTentativa != null) {
      return;
    }
    if (!_freteConfirmado ||
        _entregaLatitude == null ||
        _entregaLongitude == null) {
      context.showError(
        'Confirme o frete para este endereço antes de finalizar.',
      );
      return;
    }
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
        final validado = await CupomRepository().validarCupom(
          _cupom!.id,
          cartProvider.valorTotal,
        );
        if (!context.mounted) return;
        setState(() {
          _cupom = validado;
          _subtotalValidado = cartProvider.valorTotal;
        });
        total =
            cartProvider.valorTotal + _taxaFrete - validado.descontoAplicado;
      } catch (e) {
        if (!context.mounted) return;
        setState(() => _isSubmitting = false);
        context.showError(e.toString());
        return;
      }
    }

    if (!context.mounted) return;
    if (_formaPagamento == 'Cartão de crédito' &&
        !AppConstants.stripeConfigurado) {
      setState(() => _isSubmitting = false);
      context.showError(
        'Pagamento com cartão indisponível no momento. Escolha outra forma de pagamento.',
      );
      return;
    }

    final pedido = CriarPedidoRequest(
      lojaId: cartProvider.lojaId,
      cupomId: _cupom?.id,
      formaPagamento: _formaPagamentoApi(),
      trocoPara: trocoPara,
      cpfPagador: _formaPagamento == 'PIX' ? cpfPagador : null,
      observacao: cartProvider.observacao,
      enderecoEntrega: enderecoisPadrao,
      entregaLatitude: _entregaLatitude!,
      entregaLongitude: _entregaLongitude!,
      itens: cartProvider.itens.values
          .map(CriarPedidoItemRequest.fromCartItem)
          .toList(),
    );

    final navigator = Navigator.of(context, rootNavigator: true);
    bool loadingAberto = false;
    void fecharLoading() {
      if (loadingAberto && navigator.mounted) {
        navigator.pop();
        loadingAberto = false;
      }
    }

    try {
      loadingAberto = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const PopScope(
            canPop: false, child: LoadingNhac(telaCheia: false, tamanho: 100)),
      );

      final respostaPedido = await _tentativasCheckout.enviar(uid, pedido);
      if (authService.usuarioId != uid) {
        fecharLoading();
        return;
      }
      final idGerado = respostaPedido.pedidoId;
      try {
        await LocalCacheService.salvarPedidoAtivo(uid, idGerado);
      } catch (_) {
        // O pedido foi criado; uma falha do cache não pode repetir o checkout.
      }
      fecharLoading();

      if (!context.mounted) return;
      if (_formaPagamento == 'Cartão de crédito' || _formaPagamento == 'PIX') {
        await cartProvider.esvaziarCarrinho();
        await _tentativasCheckout.concluir(uid);
        if (!context.mounted || authService.usuarioId != uid) return;
        context.go('/pagamento?pedidoId=$idGerado');
      } else {
        // Dinheiro
        await _exibirSucessoEVoltar(idGerado.toString(), cartProvider);
        await _tentativasCheckout.concluir(uid);
      }
    } on CustomCheckoutException catch (e) {
      fecharLoading();
      if (!context.mounted) return;
      setState(() => _isSubmitting = false);

      if (e.produtoId != null) {
        cartProvider.marcarItemComoEsgotado(e.produtoId!);
      }

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            e.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.message),
              if (e.suggestions != null && e.suggestions!.isNotEmpty) ...[
                SizedBox(height: 16.h),
                const Text(
                  'Sugestões:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...e.suggestions!.map((s) => Text('• $s')),
              ],
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
      fecharLoading();
      if (!context.mounted) return;
      setState(() => _isSubmitting = false);
      context.showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted && authService.usuarioId == uid) await _consultarTentativa();
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _exibirSucessoEVoltar(
    String idGerado,
    CartProvider cartProvider,
  ) async {
    final itens = cartProvider.itens.values.toList();
    final subtotal = cartProvider.valorTotal;
    final desconto = _subtotalValidado == subtotal
        ? (_cupom?.descontoAplicado ?? 0).toDouble()
        : 0.0;
    // Snapshot local: usado só se a API não devolver o pedido a tempo.
    final dadosLocais = NotaFiscalDados(
      pedidoId: idGerado,
      lojaNome: '',
      data: DateTime.now(),
      itens: itens
          .map(
            (i) => NotaFiscalItem(
              nome: i.nome,
              preco: i.preco,
              quantidade: i.quantidade,
            ),
          )
          .toList(),
      taxaFrete: _taxaFrete,
      desconto: desconto,
      total: subtotal + _taxaFrete - desconto,
    );

    await mostrarNotaFiscalEVerPedido(
      context,
      pedidoId: idGerado,
      dadosLocais: dadosLocais,
      aoConcluir: cartProvider.esvaziarCarrinho,
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
              borderRadius: BorderRadius.circular(2.r),
            ),
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
                return Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () async {
                        if (!await selecionarEnderecoPadrao(
                            context, endereco.id)) {
                          return;
                        }
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.sp,
                        ),
                      ),
                      subtitle: Text(
                        '${endereco.bairro}${(endereco.complemento?.isNotEmpty ?? false) ? ' - ${endereco.complemento}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.sp),
                      ),
                      trailing: endereco.isPadrao
                          ? Icon(
                              Icons.check_circle,
                              color: const Color(0xFFFF6961),
                              size: 22.r,
                            )
                          : null,
                    ));
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
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, color: Colors.grey, size: 20.r),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                        child: Text(
                      'Adicionar novo endereço',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15.sp,
                        color: Colors.grey,
                      ),
                    )),
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
