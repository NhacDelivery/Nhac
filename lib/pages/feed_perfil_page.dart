import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/components/profile/banner_perfil.dart';
import 'package:nhac/components/seta_voltar.dart';
import 'package:nhac/models/feed/feed_perfil_model.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/repositories/chat_repository.dart';
import 'package:nhac/repositories/feed_repository.dart';
import 'package:nhac/utils/error_ui_helper.dart';

class FeedPerfilPage extends StatefulWidget {
  const FeedPerfilPage({
    super.key,
    required this.usuarioId,
    this.feedRepository,
    this.chatRepository,
  });

  final String usuarioId;
  final FeedRepository? feedRepository;
  final ChatRepository? chatRepository;

  @override
  State<FeedPerfilPage> createState() => _FeedPerfilPageState();
}

class _FeedPerfilPageState extends State<FeedPerfilPage> {
  late final _feed = widget.feedRepository ?? FeedRepository();
  late final _chat = widget.chatRepository ?? ChatRepository();
  FeedPerfilModel? _perfil;
  final _publicacoes = <FeedPostModel>[];
  int _pagina = 0;
  bool _carregando = false;
  bool _abrindoConversa = false;
  String? _erro;
  static const _marrom = Color(0xFF5D201C);

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar({bool mais = false}) async {
    if (_carregando) return;
    final pagina = mais ? _pagina + 1 : 0;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final perfil = await _feed.buscarPerfil(widget.usuarioId, page: pagina);
      if (!mounted) return;
      if (!mais) _publicacoes.clear();
      final ids = _publicacoes.map((post) => post.id).toSet();
      _publicacoes.addAll(perfil.publicacoes.where((post) => ids.add(post.id)));
      _perfil = perfil;
      _pagina = pagina;
    } catch (e) {
      if (!mounted) return;
      _erro = ErrorUIHelper.mensagem(
        e,
        fallback: 'Não foi possível carregar o perfil.',
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _enviarMensagem(FeedPerfilModel perfil) async {
    if (_abrindoConversa) return;
    setState(() => _abrindoConversa = true);
    try {
      final conversaId = await _chat.abrirConversaComPessoa(perfil.id);
      if (!mounted) return;
      context.push(
        '/chat-pessoa',
        extra: {
          'conversaId': conversaId,
          'pessoaNome': perfil.nome,
          'fotoUrl': perfil.avatarUrl,
        },
      );
    } catch (e) {
      if (mounted) ErrorUIHelper.handle(context, e);
    } finally {
      if (mounted) setState(() => _abrindoConversa = false);
    }
  }

  Future<void> _abrirPost(FeedPostModel post) async {
    final excluido = await context.push<bool>('/feed-post', extra: post);
    if (mounted && excluido == true) {
      setState(() => _publicacoes.removeWhere((item) => item.id == post.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = _perfil;
    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      body: SafeArea(
        child: perfil == null
            ? Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 24.h),
                    child: _barraPerfil(),
                  ),
                  Expanded(
                    child: Center(
                      child: _carregando
                          ? const CircularProgressIndicator()
                          : _rodape(),
                    ),
                  ),
                ],
              )
            : RefreshIndicator(
                onRefresh: _carregar,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _cabecalho(perfil)),
                    SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
                        padding: EdgeInsets.symmetric(vertical: 24.h),
                        child: _rodape(),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _barraPerfil() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 40.w,
          height: 40.h,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          child: const Center(child: SetaVoltar()),
        ),
        Text(
          'Perfil',
          style: TextStyle(
            color: _marrom,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 40.w, height: 40.h),
      ],
    );
  }

  Widget _cabecalho(FeedPerfilModel perfil) {
    final foto = perfil.avatarUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BannerPerfil(
          url: perfil.bannerUrl,
          sobreposicao: 40.h,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: [
                SizedBox(height: 16.h),
                SizedBox(height: 16.h),
                _barraPerfil(),
                SizedBox(height: 32.h),
                Row(
                  children: [
                    Container(
                      width: 80.w,
                      height: 80.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _marrom.withValues(alpha: 0.1),
                            blurRadius: 10.r,
                            offset: Offset(0, 4.h),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: foto == null || foto.isEmpty
                            ? Icon(
                                Icons.person,
                                size: 48.r,
                                color: Colors.grey.shade400,
                              )
                            : CachedNetworkImage(
                                imageUrl: foto,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Icon(
                                  Icons.person,
                                  size: 48.r,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Text(
                        perfil.nome,
                        style: TextStyle(
                          color: _marrom,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (perfil.podeEnviarMensagem)
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 0),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6961),
                foregroundColor: Colors.white,
              ),
              onPressed: _abrindoConversa
                  ? null
                  : () => _enviarMensagem(perfil),
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(
                _abrindoConversa ? 'Abrindo conversa…' : 'Enviar mensagem',
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 12.h),
          child: Text(
            'Publicações',
            style: TextStyle(
              color: _marrom,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE6DEDD)),
        const SizedBox(height: 2),
      ],
    );
  }

  Widget _miniatura(FeedPostModel post) {
    return Semantics(
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
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(erro, textAlign: TextAlign.center),
            ),
            TextButton(
              onPressed: _carregar,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    if (_carregando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_perfil?.temMais == true) {
      return Center(
        child: TextButton(
          onPressed: () => _carregar(mais: true),
          child: const Text('Carregar mais'),
        ),
      );
    }
    if (_publicacoes.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: const Text('Nenhuma publicação ainda.'),
      );
    }
    return const SizedBox.shrink();
  }
}
