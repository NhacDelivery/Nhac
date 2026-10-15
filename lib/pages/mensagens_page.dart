import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nhac/components/estado_com_retry.dart';
import 'package:nhac/components/loading_nhac.dart';
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
  int _aba = 0;

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

  Future<void> _atualizar() => _aba == 0
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
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Mensagens'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF5D201C),
          actions: [
            AnimatedBuilder(
              animation: Listenable.merge([_pessoas, _lojas]),
              builder: (_, __) => IconButton(
                tooltip: 'Atualizar conversas',
                onPressed: (_aba == 0 ? _pessoas.carregando : _lojas.carregando)
                    ? null
                    : _atualizar,
                icon: const Icon(Icons.refresh),
              ),
            )
          ],
        ),
        body: SafeArea(
            child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _busca,
              focusNode: _focoBusca,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Buscar nas conversas carregadas',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busca.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _busca.clear();
                          setState(() {});
                          _focoBusca.requestFocus();
                        },
                      ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          Row(children: [
            _tab('Pessoas', Icons.people_outline, 0),
            _tab('Lojas', Icons.storefront_outlined, 1)
          ]),
          Expanded(
              child: AnimatedBuilder(
            animation: Listenable.merge([_pessoas, _lojas]),
            builder: (_, __) => _aba == 0
                ? _lista<ConversaPessoaResumo>(
                    _pessoas,
                    (item) => _combina(item.pessoaNome, item.ultimaMensagem),
                    (item) => _item(
                        item.id,
                        item.pessoaNome,
                        item.ultimaMensagem,
                        item.ultimaMensagemData,
                        item.mensagensNaoLidas,
                        Icons.person_outline,
                        () => _abrir('/chat-pessoa', {
                              'conversaId': item.id,
                              'pessoaNome': item.pessoaNome
                            })),
                    'Ainda não há conversas com pessoas.',
                  )
                : _lista<ConversaResumo>(
                    _lojas,
                    (item) => _combina(item.lojaNome, item.ultimaMensagem),
                    (item) => _item(
                        item.id,
                        item.lojaNome,
                        item.ultimaMensagem,
                        item.ultimaMensagemData,
                        item.mensagensNaoLidas,
                        Icons.storefront_outlined,
                        () => _abrir('/chat-loja', {
                              'conversaId': item.id,
                              'lojaId': item.lojaId,
                              'lojaNome': item.lojaNome
                            })),
                    'Ainda não há conversas com lojas.',
                  ),
          )),
        ])),
      );

  Widget _tab(String nome, IconData icone, int indice) => Expanded(
        child: Semantics(
            selected: _aba == indice,
            child: TextButton.icon(
              onPressed: () {
                setState(() => _aba = indice);
                if (indice == 0 && !_pessoas.carregou) _pessoas.carregar();
                if (indice == 1 && !_lojas.carregou) _lojas.carregar();
              },
              style: TextButton.styleFrom(
                  foregroundColor: _aba == indice
                      ? const Color(0xFFFF6961)
                      : const Color(0xFF5D201C)),
              icon: Icon(icone),
              label: Text(nome),
            )),
      );

  Widget _lista<T>(ListaConversasController<T> caixa, bool Function(T) filtrar,
      Widget Function(T) construir, String vazio) {
    if (caixa.carregando && !caixa.carregou && caixa.itens.isEmpty) {
      return const Center(child: LoadingNhac(telaCheia: false, tamanho: 80));
    }
    final itens = caixa.itens.where(filtrar).toList();
    return RefreshIndicator(
      onRefresh: () => caixa.carregar(reiniciar: true),
      child: ListView(
        key: PageStorageKey('conversas-$_aba'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (caixa.erro != null)
            Semantics(
                liveRegion: true,
                child: BannerErroInline(
                  mensagem: caixa.erro!,
                  aoTentarNovamente:
                      caixa.carregando ? null : caixa.tentarNovamente,
                )),
          if (caixa.carregando) const LinearProgressIndicator(),
          if (itens.isEmpty && caixa.carregou && caixa.erro == null)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                _busca.text.trim().isEmpty
                    ? vazio
                    : 'Nenhuma conversa carregada corresponde à busca.',
                textAlign: TextAlign.center,
              ),
            ),
          ...itens.map(construir),
          if (caixa.temMais && caixa.carregou)
            Center(
                child: TextButton(
              onPressed: caixa.carregando ? null : caixa.carregar,
              child: Text(caixa.carregando
                  ? 'Carregando...'
                  : 'Carregar mais conversas'),
            )),
        ],
      ),
    );
  }

  Widget _item(String id, String nome, String mensagem, DateTime data,
          int naoLidas, IconData icone, VoidCallback abrir) =>
      ListTile(
        key: ValueKey('conversa-$id'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
            backgroundColor: const Color(0xFFFFE7E5),
            child: Icon(icone, color: const Color(0xFF5D201C))),
        title: Text(nome,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: const Color(0xFF5D201C),
                fontWeight: naoLidas > 0 ? FontWeight.w700 : FontWeight.w500)),
        subtitle: Text(mensagem.isEmpty ? 'Conversa iniciada' : mensagem,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(DateFormat('dd/MM', 'pt_BR').format(data)),
          if (naoLidas > 0)
            Semantics(
                label: '$naoLidas mensagens não lidas',
                child: Text('$naoLidas',
                    style: const TextStyle(
                        color: Color(0xFFFF6961),
                        fontWeight: FontWeight.bold))),
        ]),
        onTap: abrir,
      );

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
