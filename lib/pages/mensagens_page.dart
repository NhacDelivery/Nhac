import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nhac/components/estado_com_retry.dart';
import 'package:nhac/controllers/lista_conversas_controller.dart';
import 'package:nhac/models/chat/conversa_pessoa_resumo.dart';
import 'package:nhac/models/chat/conversa_resumo.dart';
import 'package:nhac/repositories/chat_repository.dart';

class MensagensPage extends StatefulWidget {
  final ChatRepository? repository;
  const MensagensPage({super.key, this.repository});

  @override
  State<MensagensPage> createState() => _MensagensPageState();
}

class _MensagensPageState extends State<MensagensPage>
    with WidgetsBindingObserver {
  late final _repository = widget.repository ?? ChatRepository();
  late final _pessoas = ListaConversasController<ConversaPessoaResumo>(
    buscar: (pagina, tamanho) =>
        _repository.listarConversasPessoas(pagina: pagina, tamanho: tamanho),
    identificar: (item) => item.id,
  );
  late final _lojas = ListaConversasController<ConversaResumo>(
    buscar: (pagina, tamanho) =>
        _repository.listarConversas(pagina: pagina, tamanho: tamanho),
    identificar: (item) => item.id,
  );
  final _busca = TextEditingController();
  final _focoBusca = FocusNode();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pessoas.carregar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _atualizar();
  }

  Future<void> _atualizar() => _currentIndex == 0
      ? _pessoas.carregar(reiniciar: true)
      : _lojas.carregar(reiniciar: true);

  bool _combina(String nome, String mensagem) {
    final termo = _busca.text.trim().toLowerCase();
    return termo.isEmpty || '$nome $mensagem'.toLowerCase().contains(termo);
  }

  Future<void> _abrir(String rota, Map<String, dynamic> dados) async {
    await context.push(rota, extra: dados);
    if (mounted) await _atualizar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top actions (Back button + Refresh/Search + More)
            Padding(
              padding: EdgeInsets.only(top: 8.h, right: 8.w, left: 8.w),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: const Color(0xFF5D201C),
                      size: 24.r,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: Listenable.merge([_pessoas, _lojas]),
                    builder: (_, __) => IconButton(
                      tooltip: 'Atualizar conversas',
                      icon: Icon(
                        Icons.refresh,
                        color: const Color(0xFF5D201C),
                        size: 26.r,
                      ),
                      onPressed: (_currentIndex == 0
                              ? _pessoas.carregando
                              : _lojas.carregando)
                          ? null
                          : _atualizar,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.search,
                      color: const Color(0xFF5D201C),
                      size: 28.r,
                    ),
                    onPressed: () {
                      _focoBusca.requestFocus();
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: const Color(0xFF5D201C),
                      size: 28.r,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // Large Title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
              child: Text(
                'Mensagens',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 34.sp,
                  color: const Color(0xFF5D201C),
                  letterSpacing: -0.5,
                ),
              ),
            ),

            // Barra de busca integrada com o visual moderno
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 4.h, 24.w, 12.h),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F8),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: TextField(
                  controller: _busca,
                  focusNode: _focoBusca,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar nas conversas carregadas',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14.sp,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey.shade500,
                      size: 22.r,
                    ),
                    suffixIcon: _busca.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar busca',
                            icon: Icon(
                              Icons.close,
                              color: Colors.grey.shade500,
                              size: 20.r,
                            ),
                            onPressed: () {
                              _busca.clear();
                              setState(() {});
                              _focoBusca.requestFocus();
                            },
                          ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                  ),
                ),
              ),
            ),

            // List
            Expanded(
              child: AnimatedBuilder(
                animation: Listenable.merge([_pessoas, _lojas]),
                builder: (_, __) => _currentIndex == 0
                    ? _buildListaPessoas()
                    : _buildListaLojas(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFFFF6961), // Vermelho do app
        shape: const CircleBorder(),
        elevation: 4,
        child: Icon(Icons.add, color: Colors.white, size: 36.r),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 0 && !_pessoas.carregou) _pessoas.carregar();
          if (index == 1 && !_lojas.carregou) _lojas.carregar();
        },
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF5D201C),
        unselectedItemColor: Colors.grey.shade500,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12.sp,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 12.sp,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.chat),
            ),
            label: 'Pessoas',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Badge(
                smallSize: 10,
                backgroundColor: Color(0xFFFE645C), // Red badge
                child: Icon(Icons.inventory_2_outlined),
              ),
            ),
            label: 'Lojas',
          ),
        ],
      ),
    );
  }

  Widget _buildListaPessoas() {
    if (_pessoas.carregando && !_pessoas.carregou && _pessoas.itens.isEmpty) {
      return const Center(
        child: LoadingNhac(telaCheia: false, tamanho: 40),
      );
    }

    if (_pessoas.erro != null && _pessoas.itens.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _pessoas.erro!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16.sp),
              ),
              SizedBox(height: 12.h),
              TextButton(
                onPressed: _pessoas.tentarNovamente,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final itens = _pessoas.itens
        .where((item) => _combina(item.pessoaNome, item.ultimaMensagem))
        .toList();

    if (itens.isEmpty && _pessoas.carregou && _pessoas.erro == null) {
      return Center(
        child: Text(
          _busca.text.trim().isEmpty
              ? 'Ainda não há conversas com pessoas.'
              : 'Nenhuma conversa carregada corresponde à busca.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16.sp),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _pessoas.carregar(reiniciar: true),
      child: ListView.builder(
        key: const PageStorageKey('conversas-pessoas'),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itens.length +
            (_pessoas.erro != null ? 1 : 0) +
            (_pessoas.temMais && _pessoas.carregou ? 1 : 0),
        itemBuilder: (context, index) {
          if (_pessoas.erro != null && index == 0) {
            return Semantics(
              liveRegion: true,
              child: BannerErroInline(
                mensagem: _pessoas.erro!,
                aoTentarNovamente:
                    _pessoas.carregando ? null : _pessoas.tentarNovamente,
              ),
            );
          }

          final adjustedIndex = _pessoas.erro != null ? index - 1 : index;

          if (adjustedIndex == itens.length) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: TextButton(
                  onPressed: _pessoas.carregando ? null : _pessoas.carregar,
                  child: Text(_pessoas.carregando
                      ? 'Carregando...'
                      : 'Carregar mais conversas'),
                ),
              ),
            );
          }

          final item = itens[adjustedIndex];
          final dateFormat = DateFormat('dd/MM', 'pt_BR');
          final dataStr = dateFormat.format(item.ultimaMensagemData);

          return ListTile(
            key: ValueKey('conversa-${item.id}'),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 24.w,
              vertical: 6.h,
            ),
            leading: CircleAvatar(
              radius: 25.r,
              backgroundColor: Colors.grey.shade300,
              child: Icon(Icons.person, color: Colors.white, size: 34.r),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    item.pessoaNome,
                    style: TextStyle(
                      fontWeight: item.mensagensNaoLidas > 0
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 17.sp,
                      color: const Color(0xFF5D201C),
                    ),
                  ),
                ),
                Text(
                  dataStr,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: item.mensagensNaoLidas > 0
                        ? const Color(0xFFFF6961)
                        : Colors.grey.shade500,
                    fontWeight: item.mensagensNaoLidas > 0
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.ultimaMensagem,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: item.mensagensNaoLidas > 0
                          ? const Color(0xFF5D201C)
                          : Colors.grey.shade500,
                      fontWeight: item.mensagensNaoLidas > 0
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            onTap: () => _abrir('/chat-pessoa', {
              'conversaId': item.id,
              'pessoaNome': item.pessoaNome,
            }),
          );
        },
      ),
    );
  }

  Widget _buildListaLojas() {
    if (_lojas.carregando && !_lojas.carregou && _lojas.itens.isEmpty) {
      return const Center(
        child: LoadingNhac(telaCheia: false, tamanho: 40),
      );
    }

    if (_lojas.erro != null && _lojas.itens.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _lojas.erro!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16.sp),
              ),
              SizedBox(height: 12.h),
              TextButton(
                onPressed: _lojas.tentarNovamente,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final itens = _lojas.itens
        .where((item) => _combina(item.lojaNome, item.ultimaMensagem))
        .toList();

    if (itens.isEmpty && _lojas.carregou && _lojas.erro == null) {
      return Center(
        child: Text(
          _busca.text.trim().isEmpty
              ? 'Ainda não há conversas com lojas.'
              : 'Nenhuma conversa carregada corresponde à busca.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16.sp),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _lojas.carregar(reiniciar: true),
      child: ListView.builder(
        key: const PageStorageKey('conversas-lojas'),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itens.length +
            (_lojas.erro != null ? 1 : 0) +
            (_lojas.temMais && _lojas.carregou ? 1 : 0),
        itemBuilder: (context, index) {
          if (_lojas.erro != null && index == 0) {
            return Semantics(
              liveRegion: true,
              child: BannerErroInline(
                mensagem: _lojas.erro!,
                aoTentarNovamente:
                    _lojas.carregando ? null : _lojas.tentarNovamente,
              ),
            );
          }

          final adjustedIndex = _lojas.erro != null ? index - 1 : index;

          if (adjustedIndex == itens.length) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: TextButton(
                  onPressed: _lojas.carregando ? null : _lojas.carregar,
                  child: Text(_lojas.carregando
                      ? 'Carregando...'
                      : 'Carregar mais conversas'),
                ),
              ),
            );
          }

          final item = itens[adjustedIndex];
          final dateFormat = DateFormat('dd/MM', 'pt_BR');
          final dataStr = dateFormat.format(item.ultimaMensagemData);

          return ListTile(
            key: ValueKey('conversa-${item.id}'),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 24.w,
              vertical: 6.h,
            ),
            leading: CircleAvatar(
              radius: 25.r,
              backgroundColor: Colors.grey.shade300,
              child: Icon(Icons.store, color: Colors.white, size: 30.r),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    item.lojaNome,
                    style: TextStyle(
                      fontWeight: item.mensagensNaoLidas > 0
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 17.sp,
                      color: const Color(0xFF5D201C),
                    ),
                  ),
                ),
                Text(
                  dataStr,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: item.mensagensNaoLidas > 0
                        ? const Color(0xFFFF6961)
                        : Colors.grey.shade500,
                    fontWeight: item.mensagensNaoLidas > 0
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '[Loja Oficial]',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: const Color(0xFFE67E22), // Orange
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    item.ultimaMensagem,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: item.mensagensNaoLidas > 0
                          ? const Color(0xFF5D201C)
                          : Colors.grey.shade500,
                      fontWeight: item.mensagensNaoLidas > 0
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            onTap: () => _abrir('/chat-loja', {
              'conversaId': item.id,
              'lojaId': item.lojaId,
              'lojaNome': item.lojaNome,
            }),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pessoas.dispose();
    _lojas.dispose();
    _busca.dispose();
    _focoBusca.dispose();
    super.dispose();
  }
}
