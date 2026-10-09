import 'package:nhac/components/nhac_confirm_dialog.dart';
import 'package:nhac/utils/request_outcome.dart';
import 'package:nhac/pages/feed_images_page.dart';
import 'package:nhac/components/feed_timestamp.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/feed_tentativa_service.dart';
import 'package:nhac/services/feed_share_service.dart';
import 'package:nhac/components/feed_content.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nhac/components/seta_voltar.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:shimmer/shimmer.dart';
import 'package:nhac/repositories/feed_repository.dart';
import 'package:nhac/models/feed/feed_comment_model.dart';
import 'package:nhac/utils/error_ui_helper.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:nhac/pages/loja_page.dart';
import 'package:nhac/pages/feed_edit_page.dart';

class FeedPostDetailPage extends StatefulWidget {
  final FeedPostModel post;
  final bool focarComentario;

  const FeedPostDetailPage({
    super.key,
    required this.post,
    this.focarComentario = false,
  });

  @override
  State<FeedPostDetailPage> createState() => _FeedPostDetailPageState();
}

class _FeedPostDetailPageState extends State<FeedPostDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();

  final FeedRepository _repository = FeedRepository();
  List<FeedCommentModel> _comments = [];
  final Map<int, List<FeedCommentModel>> _porFiltro = {};
  late FeedPostModel _post;
  bool _loadingComments = true;
  bool _sending = false;
  String? _respostaAId;
  String? _respostaANome;
  final Set<String> _curtindoComentarios = {};
  final Map<String, FeedCommentModel> _comentariosConfirmados = {};
  bool _commentPending = false;
  bool _restoringComment = true;
  bool _interacting = false;
  bool _postRefreshPending = false;
  bool _hasMoreComments = false;
  int _commentPage = 0;
  int _commentRequestId = 0;
  int _postRequestId = 0;
  bool _openingStore = false;
  String? _commentError;
  bool _falhouMaisComentarios = false;

  final _tentativas = const FeedTentativaService();
  bool? _seguindo;
  bool _seguindoBusy = false;
  bool _alterando = false;
  int _tabAtual = 0;
  List<FeedCommentModel> get _visibleComments => _comments;
  String? get _uid => context.read<AuthService>().usuarioId;
  bool get _podeEditar =>
      _post.usuarioId != null && (_post.usuarioId == _uid || _post.podeEditar);
  static const List<String> _tabs = ['Padrão', 'Recentes', 'Autor'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _post = widget.post;
    _tabController.addListener(() {
      if (_tabController.index != _tabAtual) {
        _porFiltro[_tabAtual] = List.of(_comments);
        _tabAtual = _tabController.index;
        _comments = List.of(_porFiltro[_tabAtual] ?? []);
        _commentPage = 0;
        _hasMoreComments = false;
        _carregarComentarios();
      }
    });
    _carregarComentarios();
    _atualizarPost();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _consultarSeguindo();
      final uid = _uid;
      try {
        if (uid != null) {
          final pending = await _tentativas.carregar(
            uid,
            'comentario:${_post.id}',
          );
          if (mounted && pending != null) {
            _commentController.text = pending['payload']['conteudo'] as String;
            _respostaAId = pending['payload']['respostaAId'] as String?;
            _respostaANome = _respostaAId == null
                ? null
                : 'comentário anterior';
            _commentPending = true;
          }
        }
      } catch (e) {
        if (mounted) ErrorUIHelper.handle(context, e);
      } finally {
        if (mounted) setState(() => _restoringComment = false);
      }
      if (mounted && widget.focarComentario) _commentFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _carregarComentarios({bool mais = false}) async {
    if (mais && _loadingComments) return;
    _falhouMaisComentarios = mais;
    _comentariosConfirmados.clear();
    final requestId = ++_commentRequestId;
    setState(() {
      _loadingComments = true;
      _commentError = null;
    });
    try {
      final page = mais ? _commentPage + 1 : 0;
      final comments = await _repository.buscarComentarios(
        _post.id,
        page: page,
        ordem: _tabAtual == 1 ? 'Recentes' : 'Padrao',
        autor: _tabAtual == 2,
      );
      if (!mounted || requestId != _commentRequestId) return;
      setState(() {
        _comments = {
          for (final c in [
            ...(mais ? _comments : <FeedCommentModel>[]),
            ...comments,
          ])
            c.id: _comentariosConfirmados[c.id] ?? c,
        }.values.toList();
        _porFiltro[_tabAtual] = List.of(_comments);
        _commentPage = page;
        _hasMoreComments = comments.length == 20;
      });
    } catch (_) {
      if (mounted && requestId == _commentRequestId)
        setState(
          () => _commentError = 'Não foi possível carregar os comentários.',
        );
    } finally {
      if (mounted && requestId == _commentRequestId)
        setState(() => _loadingComments = false);
    }
  }

  Future<void> _enviarComentario() async {
    final text = _commentController.text.trim();
    if (_sending || _restoringComment || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final uid = _uid;
      if (uid == null) throw StateError('Faça login para comentar.');
      final tentativa = await _tentativas.preparar(
        uid,
        'comentario:${_post.id}',
        {
          'conteudo': text,
          if (_respostaAId != null) 'respostaAId': _respostaAId,
        },
      );
      if (mounted) setState(() => _commentPending = true);
      await _repository.comentar(
        _post.id,
        text,
        idempotencyKey: tentativa['key'] as String,
        respostaAId: _respostaAId,
      );
      await _tentativas.concluir(uid, 'comentario:${_post.id}');
      if (mounted)
        setState(() {
          _commentPending = false;
          _respostaAId = null;
          _respostaANome = null;
        });
      if (!mounted) return;
      if (_commentController.text.trim() == text) _commentController.clear();
      _commentFocus.unfocus();
      await _carregarComentarios();
      await _atualizarPost();
    } catch (e) {
      if (rejeicaoDefinitiva(e)) {
        final uid = _uid;
        if (uid != null)
          await _tentativas.concluir(uid, 'comentario:${_post.id}');
        if (mounted) setState(() => _commentPending = false);
      }
      if (mounted) ErrorUIHelper.handle(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _responder(FeedCommentModel comment) {
    if (_sending || _commentPending || _restoringComment) return;
    setState(() {
      _respostaAId = comment.id;
      _respostaANome = comment.nome;
    });
    _commentFocus.requestFocus();
  }

  Future<void> _curtirComentario(FeedCommentModel comment) async {
    if (!_curtindoComentarios.add(comment.id)) return;
    setState(() {});
    try {
      final atualizado = await _repository.curtirComentario(
        _post.id,
        comment.id,
        ativo: !comment.curtido,
      );
      if (!mounted) return;
      setState(() {
        _comentariosConfirmados[comment.id] = atualizado;
        _comments = _comments
            .map((c) => c.id == atualizado.id ? atualizado : c)
            .toList();
      });
    } catch (e) {
      if (mounted) ErrorUIHelper.handle(context, e);
    } finally {
      if (mounted) setState(() => _curtindoComentarios.remove(comment.id));
    }
  }

  Future<void> _interagir({bool salvar = false}) async {
    if (_interacting) return;
    final postRequestId = ++_postRequestId;
    setState(() => _interacting = true);
    try {
      final post = await _repository.interagir(
        _post.id,
        ativo: salvar ? !_post.salvo : !_post.curtido,
        salvar: salvar,
      );
      if (mounted && postRequestId == _postRequestId)
        setState(() => _post = post);
    } catch (e) {
      if (mounted) ErrorUIHelper.handle(context, e);
    } finally {
      if (mounted) {
        setState(() => _interacting = false);
        if (_postRefreshPending) await _atualizarPost();
      }
    }
  }

  Future<void> _atualizarPost() async {
    if (_interacting) {
      _postRefreshPending = true;
      return;
    }
    _postRefreshPending = false;
    final request = ++_postRequestId;
    try {
      final post = await _repository.buscarPost(_post.id);
      if (mounted && request == _postRequestId) setState(() => _post = post);
    } catch (e) {
      if (mounted && recursoExcluido(e)) {
        if (context.canPop())
          context.pop(true);
        else
          context.go('/');
        return;
      }
      if (mounted) ErrorUIHelper.handle(context, e);
    }
  }

  Future<void> _consultarSeguindo() async {
    final uid = _uid, lojaId = _post.mentionedStore?.id;
    if (uid == null || lojaId == null) return;
    try {
      final seguindo = await LojaRepository().estaSeguindo(uid, lojaId);
      if (mounted && _uid == uid) setState(() => _seguindo = seguindo);
    } catch (e) {
      if (mounted) ErrorUIHelper.handle(context, e);
    }
  }

  Future<void> _seguir() async {
    if (_seguindoBusy) return;
    if (_seguindo == null) {
      await _consultarSeguindo();
      return;
    }
    final uid = _uid, lojaId = _post.mentionedStore?.id;
    if (uid == null || lojaId == null) return;
    setState(() => _seguindoBusy = true);
    try {
      if (_seguindo!) {
        await LojaRepository().deixarDeSeguir(uid, lojaId);
      } else {
        await LojaRepository().seguirLoja(uid, lojaId);
      }
      if (mounted && _uid == uid) setState(() => _seguindo = !_seguindo!);
    } catch (e) {
      if (mounted) ErrorUIHelper.handle(context, e);
    } finally {
      if (mounted) setState(() => _seguindoBusy = false);
    }
  }

  Future<bool> _confirmar(String title, String content) =>
      confirmarNhac(context, titulo: title, mensagem: content);

  Future<void> _denunciar({FeedCommentModel? comentario}) async {
    final motivo = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Por que você quer denunciar?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF5D201C),
                ),
              ),
            ),
            for (final razao in [
              'Spam ou propaganda',
              'Conteúdo ofensivo',
              'Assédio ou discriminação',
              'Informação enganosa',
              'Outro problema',
            ])
              ListTile(
                title: Text(razao),
                leading: const Icon(
                  Icons.flag_outlined,
                  color: Color(0xFFFF6961),
                ),
                onTap: () => Navigator.pop(ctx, razao),
              ),
          ],
        ),
      ),
    );
    if (motivo == null || !mounted) return;
    try {
      await _repository.denunciar(
        _post.id,
        motivo,
        comentarioId: comentario?.id,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Denúncia registrada para análise.')),
        );
    } catch (e) {
      if (mounted) ErrorUIHelper.handle(context, e);
    }
  }

  Future<void> _menuPublicacao() async {
    final acao = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Publicação',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D201C),
                ),
              ),
            ),
            if (_podeEditar)
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFFFF6961),
                ),
                title: const Text('Editar publicação'),
                onTap: () => Navigator.pop(ctx, 'editar'),
              ),
            if (_podeEditar)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFFF6961),
                ),
                title: const Text('Excluir publicação'),
                onTap: () => Navigator.pop(ctx, 'excluir'),
              ),
            ListTile(
              leading: const Icon(
                Icons.flag_outlined,
                color: Color(0xFFFF6961),
              ),
              title: const Text('Denunciar publicação'),
              onTap: () => Navigator.pop(ctx, 'denunciar'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (acao == 'editar') _editarPost();
    if (acao == 'excluir') _excluirPost();
    if (acao == 'denunciar') _denunciar();
  }

  Future<void> _excluirComentario(FeedCommentModel comment) async {
    if (_alterando ||
        !await _confirmar(
          'Excluir comentário?',
          'O comentário será removido desta publicação.',
        ))
      return;
    if (!mounted) return;
    setState(() => _alterando = true);
    try {
      await _repository.excluirComentario(_post.id, comment.id);
      await _carregarComentarios();
      await _atualizarPost();
    } catch (e) {
      if (mounted) ErrorUIHelper.handle(context, e);
    } finally {
      if (mounted) setState(() => _alterando = false);
    }
  }

  Future<void> _excluirPost() async {
    if (_alterando ||
        !await _confirmar(
          'Excluir publicação?',
          'A publicação e seus comentários serão removidos.',
        ))
      return;
    if (!mounted) return;
    setState(() => _alterando = true);
    try {
      await _repository.excluir(_post.id);
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) ErrorUIHelper.handle(context, e);
    } finally {
      if (mounted) setState(() => _alterando = false);
    }
  }

  Future<void> _editarPost() async {
    final updated = await Navigator.of(context).push<FeedPostModel>(
      MaterialPageRoute(builder: (_) => FeedEditPage(post: _post)),
    );
    if (mounted && updated != null) {
      ++_postRequestId;
      setState(() => _post = updated);
    }
  }

  Future<void> _compartilhar() async {
    try {
      await FeedShareService.compartilhar(context, _post.id);
    } catch (e) {
      if (mounted) ErrorUIHelper.handle(context, e);
    }
  }

  Future<void> _abrirLoja(MentionedStoreModel store) async {
    if (_openingStore || store.id == null) return;
    setState(() => _openingStore = true);
    try {
      final loja = await LojaRepository().buscarLoja(store.id!);
      if (!mounted) return;
      if (loja == null) {
        throw StateError('Loja não encontrada');
      }
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => LojaPage(loja: loja)));
    } catch (e) {
      if (mounted) ErrorUIHelper.handle(context, e);
    } finally {
      if (mounted) setState(() => _openingStore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final comments = _visibleComments;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(
        type: MaterialType.transparency,
        child: Container(
          color: Colors.white,
          child: Stack(
            children: [
              // Scrollable content
              Positioned.fill(
                child: CustomScrollView(
                  slivers: [
                    // ── AppBar ─────────────────────────────────
                    SliverAppBar(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      pinned: true,
                      leading: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Center(child: SetaVoltar()),
                      ),
                      title: Row(
                        children: [
                          _buildAvatar(post.avatarUrl, 32.w),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.nomeUsuario,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15.sp,
                                    color: const Color(0xFF5D201C),
                                  ),
                                ),
                                FeedTimestamp(post.criadoEm),
                                if (post.badge != null)
                                  Text(
                                    post.badge!,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        IconButton(
                          tooltip: 'Opções da publicação',
                          onPressed: _alterando ? null : _menuPublicacao,
                          icon: const Icon(
                            Icons.more_horiz,
                            color: Color(0xFF5D201C),
                          ),
                        ),
                      ],
                    ),

                    if (post.mentionedStore?.id != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.storefront_outlined,
                                color: Color(0xFFFF6961),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  post.mentionedStore!.nome,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                onPressed: _seguindoBusy ? null : _seguir,
                                child: Text(
                                  _seguindo == null
                                      ? 'Consultar vínculo'
                                      : _seguindo!
                                      ? 'Seguindo loja'
                                      : 'Seguir loja',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Post Images ────────────────────────────
                    if (post.imagens.isNotEmpty)
                      SliverToBoxAdapter(child: _buildPostImages(post.imagens)),

                    // ── Post Content ───────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRichText(post.conteudo, post.hashTags),
                            if (post.mentionedStore != null)
                              _buildMentionedStore(post.mentionedStore!),
                            SizedBox(height: 16.h),

                            // Actions row (like, comment, share)
                            Row(
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: _buildActionChip(
                                      icon: post.curtido
                                          ? Icons.thumb_up_alt
                                          : Icons.thumb_up_alt_outlined,
                                      onPressed: _interacting
                                          ? null
                                          : () => _interagir(),
                                      active: post.curtido,
                                      tooltip: 'Curtir ou descurtir',
                                      label: _formatCount(post.curtidas),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: _buildActionChip(
                                    icon: Icons.chat_bubble_outline,
                                    onPressed: () =>
                                        _commentFocus.requestFocus(),
                                    tooltip: 'Comentar',
                                    label: _formatCount(post.comentarios),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _buildActionChip(
                                      icon: Icons.share_outlined,
                                      onPressed: _compartilhar,
                                      tooltip: 'Compartilhar',
                                      label: '',
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 16.h),
                            Divider(color: Colors.grey.shade200, height: 1),
                          ],
                        ),
                      ),
                    ),

                    // ── Comments Header + Tabs ─────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 18.r,
                              color: const Color(0xFF5D201C),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              '${post.comentarios} comentários',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15.sp,
                                color: const Color(0xFF5D201C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyTabDelegate(
                        child: Container(
                          color: Colors.white,
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            labelColor: const Color(0xFFFF6961),
                            unselectedLabelColor: Colors.grey,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                            ),
                            unselectedLabelStyle: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 13.sp,
                            ),
                            indicator: UnderlineTabIndicator(
                              borderSide: BorderSide(
                                color: const Color(0xFFFF6961),
                                width: 2.5,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            indicatorSize: TabBarIndicatorSize.label,
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            tabs: _tabs.map((t) => Tab(text: t)).toList(),
                          ),
                        ),
                      ),
                    ),

                    // ── Comments List ──────────────────────────
                    if (_loadingComments)
                      const SliverToBoxAdapter(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_commentError != null)
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            Text(_commentError!, textAlign: TextAlign.center),
                            TextButton(
                              onPressed: _loadingComments
                                  ? null
                                  : () => _carregarComentarios(
                                      mais: _falhouMaisComentarios,
                                    ),
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                    if (!_loadingComments &&
                        _commentError == null &&
                        comments.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Nenhum comentário por aqui ainda.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildCommentCard(comments[index]),
                        childCount: comments.length,
                      ),
                    ),
                    if (!_loadingComments && _hasMoreComments)
                      SliverToBoxAdapter(
                        child: TextButton(
                          onPressed: () => _carregarComentarios(mais: true),
                          child: const Text('Carregar mais comentários'),
                        ),
                      ),

                    SliverToBoxAdapter(
                      child: SizedBox(
                        height:
                            (_respostaAId == null ? 100.h : 160.h) +
                            bottomPadding,
                      ),
                    ),
                  ],
                ),
              ),

              if (_respostaAId != null)
                Positioned(
                  left: 16.w,
                  right: 16.w,
                  bottom: 80.h + bottomPadding,
                  child: Material(
                    color: const Color(0xFFFFF0EE),
                    borderRadius: BorderRadius.circular(12.r),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Respondendo a ${_respostaANome ?? "comentário"}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cancelar resposta',
                          onPressed: _sending || _commentPending
                              ? null
                              : () => setState(() {
                                  _respostaAId = null;
                                  _respostaANome = null;
                                }),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Bottom Floating Bar ───────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    16.w,
                    10.h,
                    16.w,
                    10.h + bottomPadding,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Left Pill (Input)
                      Expanded(
                        child: Container(
                          height: 52.h,
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 20.r,
                                color: const Color(0xFFFF6961),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  readOnly:
                                      _sending ||
                                      _commentPending ||
                                      _restoringComment,
                                  focusNode: _commentFocus,
                                  style: TextStyle(fontSize: 14.sp),
                                  decoration: InputDecoration(
                                    hintText: _respostaAId == null
                                        ? 'Escreva...'
                                        : 'Sua resposta...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 14.sp,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  maxLength: 2000,
                                  buildCounter:
                                      (
                                        _, {
                                        required currentLength,
                                        required isFocused,
                                        maxLength,
                                      }) => null,
                                  onSubmitted: (_) => _enviarComentario(),
                                ),
                              ),
                              IconButton(
                                tooltip: _commentPending
                                    ? 'Confirmar comentário anterior'
                                    : 'Enviar comentário',
                                onPressed: _sending || _restoringComment
                                    ? null
                                    : _enviarComentario,
                                icon: Icon(
                                  _sending ? Icons.hourglass_empty : Icons.send,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Right Pill (Actions)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildFloatingAction(
                              Icons.chat_bubble_outline,
                              _formatCount(post.comentarios),
                            ),
                            SizedBox(width: 8.w),
                            _buildFloatingAction(
                              post.curtido
                                  ? Icons.thumb_up_alt
                                  : Icons.thumb_up_alt_outlined,
                              _formatCount(post.curtidas),
                              label: 'Curtir',
                              onPressed: _interacting
                                  ? null
                                  : () => _interagir(),
                            ),
                            SizedBox(width: 8.w),
                            _buildFloatingAction(
                              post.salvo
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              _formatCount(post.salvos),
                              label: 'Salvar',
                              onPressed: _interacting
                                  ? null
                                  : () => _interagir(salvar: true),
                            ),
                          ],
                        ),
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
  }

  // ─── Post Images ──────────────────────────────────────────────────────────

  Widget _buildPostImages(List<String> imagens) {
    if (imagens.length == 1) {
      return _buildNetworkImage(imagens[0], height: 300.h);
    }

    return SizedBox(
      height: 300.h,
      child: PageView.builder(
        itemCount: imagens.length,
        itemBuilder: (context, index) {
          return _buildNetworkImage(imagens[index], height: 300.h);
        },
      ),
    );
  }

  Widget _buildNetworkImage(String url, {required double height}) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FeedImagesPage(
            imagens: _post.imagens,
            inicial: _post.imagens.indexOf(url),
          ),
        ),
      ),
      child: CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade100,
          child: Container(
            color: Colors.white,
            height: height,
            width: double.infinity,
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          height: height,
          color: const Color(0xFFFFF0EE),
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  // ─── Comment Card ─────────────────────────────────────────────────────────

  Widget _buildCommentCard(FeedCommentModel comment) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        comment.respostaAId == null ? 16.w : 40.w,
        12.h,
        16.w,
        12.h,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(comment.avatarUrl, 34.w),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.sp,
                          color: const Color(0xFF5D201C),
                        ),
                      ),
                    ),
                    if (comment.isAuthor) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6961),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          'Autor',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                FeedTimestamp(comment.criadoEm),
                if (comment.respostaAId != null)
                  Text(
                    '@${comment.respostaANome ?? "comentário excluído"}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                  ),
                SizedBox(height: 4.h),
                Text(
                  comment.conteudo,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: const Color(0xFF333333),
                    height: 1.4,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: _curtindoComentarios.contains(comment.id)
                          ? null
                          : () => _curtirComentario(comment),
                      icon: Icon(
                        comment.curtido
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 18,
                      ),
                      label: Text('${comment.curtidas}'),
                      style: TextButton.styleFrom(
                        foregroundColor: comment.curtido
                            ? const Color(0xFFFF6961)
                            : const Color(0xFF666666),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Denunciar comentário',
                      onPressed: () => _denunciar(comentario: comment),
                      icon: const Icon(Icons.flag_outlined, size: 18),
                    ),
                    TextButton(
                      onPressed:
                          _sending || _commentPending || _restoringComment
                          ? null
                          : () => _responder(comment),
                      child: const Text('Responder'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (comment.usuarioId == _uid || comment.podeExcluir || _podeEditar)
            IconButton(
              tooltip: 'Excluir comentário',
              onPressed: _alterando ? null : () => _excluirComentario(comment),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildAvatar(String? url, double size) {
    return ClipOval(
      child: url != null && url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: size,
                height: size,
                color: Colors.grey.shade200,
              ),
              errorWidget: (_, __, ___) => _defaultAvatar(size),
            )
          : _defaultAvatar(size),
    );
  }

  Widget _defaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFFFE7E5),
      child: Icon(
        Icons.person,
        color: const Color(0xFF5D201C),
        size: size * 0.55,
      ),
    );
  }

  Widget _buildRichText(String conteudo, List<String> hashTags) {
    return FeedContent(conteudo: conteudo, tags: hashTags);
  }

  Widget _buildMentionedStore(MentionedStoreModel store) {
    return Container(
      margin: EdgeInsets.only(top: 16.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: CachedNetworkImage(
                  imageUrl: store.imageUrl,
                  width: 48.w,
                  height: 48.w,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: Colors.grey.shade300),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.store),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE7E5),
                            borderRadius: BorderRadius.circular(4.r),
                            border: Border.all(color: const Color(0xFFFF6961)),
                          ),
                          child: Text(
                            'Loja',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: const Color(0xFFFF6961),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            store.nome,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF5D201C),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 14.r,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          store.avaliacoes,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    store.rating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5D201C),
                    ),
                  ),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < store.rating.floor()
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 12.r,
                        color: Colors.amber,
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _openingStore || store.id == null
                  ? null
                  : () => _abrirLoja(store),
              child: Text(
                _openingStore ? 'Carregando...' : 'Ver loja e fazer pedido',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required String tooltip,
    bool active = false,
    VoidCallback? onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      child: Tooltip(
        message: tooltip,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22.r,
              color: active ? const Color(0xFFFF6961) : Colors.grey.shade500,
            ),
            if (label.isNotEmpty) ...[
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: active
                        ? const Color(0xFFFF6961)
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingAction(
    IconData icon,
    String count, {
    String? label,
    VoidCallback? onPressed,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22.r, color: const Color(0xFFFF6961)),
        SizedBox(height: 2.h),
        Text(
          count,
          style: TextStyle(fontSize: 10.sp, color: const Color(0xFF5D201C)),
        ),
      ],
    );
    return label == null
        ? content
        : Semantics(
            label: label,
            button: true,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                child: content,
              ),
            ),
          );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}

// ─── Sticky Tab Delegate ─────────────────────────────────────────────────────

class _StickyTabDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabDelegate({required this.child});
  final Widget child;

  @override
  double get minExtent => 46;
  @override
  double get maxExtent => 46;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyTabDelegate oldDelegate) =>
      oldDelegate.child != child;
}
