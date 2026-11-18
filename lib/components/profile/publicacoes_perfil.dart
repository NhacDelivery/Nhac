import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/models/feed/feed_perfil_model.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/repositories/feed_repository.dart';
import 'package:nhac/utils/error_ui_helper.dart';

class PublicacoesPerfil extends StatefulWidget {
  const PublicacoesPerfil({
    super.key,
    required this.usuarioId,
    required this.titulo,
    this.cabecalho,
    this.repository,
    this.ativo = true,
  });

  final String usuarioId;
  final String titulo;
  final Widget Function(FeedPerfilModel?)? cabecalho;
  final FeedRepository? repository;
  final bool ativo;

  @override
  State<PublicacoesPerfil> createState() => PublicacoesPerfilState();
}

class PublicacoesPerfilState extends State<PublicacoesPerfil> {
  static const _marrom = Color(0xFF5D201C);
  late final _repositoryPadrao = FeedRepository();
  FeedPerfilModel? _perfil;
  final _publicacoes = <FeedPostModel>[];
  int _pagina = 0;
  int _requisicao = 0;
  int? _total;
  bool _carregando = false;
  String? _erro;
  int _paginaComErro = 0;

  @override
  void initState() {
    super.initState();
    if (widget.ativo) atualizar();
  }

  @override
  void didUpdateWidget(covariant PublicacoesPerfil oldWidget) {
    super.didUpdateWidget(oldWidget);
    final mudouAutor =
        oldWidget.usuarioId != widget.usuarioId ||
        oldWidget.repository != widget.repository;
    if (mudouAutor) {
      _requisicao++;
      _perfil = null;
      _publicacoes.clear();
      _pagina = 0;
      _total = null;
      _erro = null;
      _carregando = false;
    }
    if (widget.ativo && (mudouAutor || !oldWidget.ativo)) atualizar();
  }

  Future<void> atualizar() => _carregar(0);

  Future<void> _carregar(int pagina) async {
    final requisicao = ++_requisicao;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final repo = widget.repository ?? _repositoryPadrao;
      final perfil = await repo.buscarPerfil(widget.usuarioId, page: pagina);
      if (!mounted || requisicao != _requisicao) return;
      if (pagina == 0) _publicacoes.clear();
      final ids = _publicacoes.map((post) => post.id).toSet();
      _publicacoes.addAll(perfil.publicacoes.where((post) => ids.add(post.id)));
      _perfil = perfil;
      _total = perfil.totalPublicacoes;
      _pagina = pagina;
    } catch (e) {
      if (!mounted || requisicao != _requisicao) return;
      _erro = ErrorUIHelper.mensagem(
        e,
        fallback: _perfil == null && widget.cabecalho != null
            ? 'Não foi possível carregar o perfil.'
            : 'Não foi possível carregar as publicações.',
      );
      _paginaComErro = pagina;
    } finally {
      if (mounted && requisicao == _requisicao) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _abrirPost(FeedPostModel post) async {
    final usuarioId = widget.usuarioId;
    final excluido = await context.push<bool>('/feed-post', extra: post);
    if (!mounted || excluido != true || widget.usuarioId != usuarioId) return;
    setState(() {
      _publicacoes.removeWhere((item) => item.id == post.id);
      if ((_total ?? 0) > 0) _total = _total! - 1;
    });
    await atualizar();
  }

  @override
  Widget build(BuildContext context) {
    final perfil = _perfil;
    final cabecalho = widget.cabecalho;
    // Em servidores antigos, a quantidade só é exata ao chegar à última página.
    final total =
        _total ?? (perfil?.temMais == false ? _publicacoes.length : null);
    return SliverMainAxisGroup(
      slivers: [
        if (cabecalho != null) SliverToBoxAdapter(child: cabecalho(perfil)),
        if (perfil != null || cabecalho == null)
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 12.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.titulo,
                          style: TextStyle(
                            color: _marrom,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (total != null && total > 0)
                        Text(
                          '$total',
                          semanticsLabel: total == 1
                              ? '1 publicação'
                              : '$total publicações',
                          style: TextStyle(
                            color: _marrom,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFE6DEDD),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _miniatura(_publicacoes[index]),
            childCount: _publicacoes.length,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            child: _rodape(),
          ),
        ),
      ],
    );
  }

  Widget _miniatura(FeedPostModel post) {
    return Semantics(
      key: ValueKey(post.id),
      button: true,
      label: 'Abrir publicação de ${post.nomeUsuario}',
      value: post.conteudo,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: () => _abrirPost(post),
          child: ExcludeSemantics(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (post.imagens.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: Text(
                        post.conteudo,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _marrom,
                          fontSize: 13.sp,
                          height: 1.3,
                        ),
                      ),
                    ),
                  )
                else
                  CachedNetworkImage(
                    imageUrl: post.imagens.first,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: Color(0xFF918783),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Color(0xFF918783),
                      ),
                    ),
                  ),
                if (post.imagens.length > 1)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: Colors.white,
                      size: 18,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rodape() {
    final erro = _erro;
    if (erro != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(erro, textAlign: TextAlign.center),
          TextButton(
            onPressed: () => _carregar(_paginaComErro),
            child: const Text('Tentar novamente'),
          ),
        ],
      );
    }
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_perfil?.temMais == true) {
      return Center(
        child: TextButton(
          onPressed: () => _carregar(_pagina + 1),
          child: const Text('Carregar mais'),
        ),
      );
    }
    if (_publicacoes.isEmpty && _perfil != null)
      return const Text('Nenhuma publicação ainda.');
    return const SizedBox.shrink();
  }
}
