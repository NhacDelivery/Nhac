import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/components/profile/banner_perfil.dart';
import 'package:nhac/components/profile/publicacoes_perfil.dart';
import 'package:nhac/components/seta_voltar.dart';
import 'package:nhac/models/feed/feed_perfil_model.dart';
import 'package:nhac/pages/feed_images_page.dart';
import 'package:nhac/repositories/chat_repository.dart';
import 'package:nhac/repositories/feed_repository.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/utils/error_ui_helper.dart';
import 'package:provider/provider.dart';

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
  static const _marrom = Color(0xFF5D201C);
  final _publicacoes = GlobalKey<PublicacoesPerfilState>();
  late final _chat = widget.chatRepository ?? ChatRepository();
  bool _abrindoConversa = false;

  Future<void> _enviarMensagem(FeedPerfilModel perfil) async {
    if (_abrindoConversa) return;
    final usuarioId = widget.usuarioId;
    final loja = perfil.lojaParaMensagem;
    setState(() => _abrindoConversa = true);
    try {
      if (loja != null) {
        await context.push(
          '/chat-loja',
          extra: {
            'lojaId': loja.id,
            'lojaNome': loja.nome,
            'lojaFotoUrl': loja.imagemUrl,
          },
        );
      } else {
        final conversaId = await _chat.abrirConversaComPessoa(perfil.id);
        if (!mounted || widget.usuarioId != usuarioId) return;
        await context.push(
          '/chat-pessoa',
          extra: {
            'conversaId': conversaId,
            'pessoaNome': perfil.nome,
            'fotoUrl': perfil.avatarUrl,
          },
        );
      }
    } catch (e) {
      if (mounted && widget.usuarioId == usuarioId) {
        ErrorUIHelper.handle(context, e);
      }
    } finally {
      if (mounted) setState(() => _abrindoConversa = false);
    }
  }

  void _ampliarImagem(String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FeedImagesPage(imagens: [url])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meuId = context.select<AuthService?, String?>(
      (auth) => auth?.usuarioId,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _publicacoes.currentState!.atualizar(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              PublicacoesPerfil(
                key: _publicacoes,
                usuarioId: widget.usuarioId,
                repository: widget.feedRepository,
                titulo: 'Publicações',
                cabecalho: (perfil) => perfil == null
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 24.h),
                        child: _barraPerfil(null),
                      )
                    : _cabecalho(perfil, meuId == perfil.id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barraPerfil(String? capa, {String titulo = 'Perfil'}) {
    final fundo = Colors.white.withValues(alpha: 0.9);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 40.w,
          height: 40.h,
          decoration: BoxDecoration(color: fundo, shape: BoxShape.circle),
          child: const Center(child: SetaVoltar()),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: fundo,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Text(
              titulo,
              style: TextStyle(
                color: _marrom,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(
          width: 40.w,
          height: 40.h,
          child: capa == null || capa.isEmpty
              ? null
              : IconButton.filledTonal(
                  tooltip: 'Ampliar banner',
                  onPressed: () => _ampliarImagem(capa),
                  style: IconButton.styleFrom(
                    backgroundColor: fundo,
                    foregroundColor: _marrom,
                  ),
                  icon: const Icon(Icons.open_in_full, size: 18),
                ),
        ),
      ],
    );
  }

  Widget _cabecalho(FeedPerfilModel perfil, bool proprio) {
    final foto = perfil.avatarUrl?.trim();
    final capa = perfil.bannerUrl?.trim();
    final loja = perfil.lojaParaMensagem;
    final podeConversar =
        !proprio && (perfil.podeEnviarMensagem || loja != null);
    final iconePessoa = Icon(
      Icons.person,
      size: 48.r,
      color: Colors.grey.shade400,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BannerPerfil(
          url: capa,
          sobreposicao: 40.h,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: [
                SizedBox(height: 32.h),
                _barraPerfil(capa, titulo: perfil.nome),
                SizedBox(height: 32.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
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
                            ? iconePessoa
                            : Semantics(
                                button: true,
                                label: 'Ampliar foto de perfil',
                                child: GestureDetector(
                                  onTap: () => _ampliarImagem(foto),
                                  child: CachedNetworkImage(
                                    imageUrl: foto,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => iconePessoa,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 4.h),
                        child: Text(
                          perfil.nome,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _marrom,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.bold,
                            shadows: const [
                              Shadow(color: Colors.white, blurRadius: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (perfil.anoCadastro != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Text(
                    'No Nhac desde ${perfil.anoCadastro}',
                    style: TextStyle(color: _marrom, fontSize: 14.sp),
                  ),
                ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _marrom,
                  foregroundColor: Colors.white,
                ),
                onPressed: !podeConversar || _abrindoConversa
                    ? null
                    : () => _enviarMensagem(perfil),
                icon: Icon(
                  loja == null
                      ? Icons.chat_bubble_outline
                      : Icons.storefront_outlined,
                ),
                label: Text(
                  _abrindoConversa
                      ? 'Abrindo conversa…'
                      : loja == null
                      ? 'Enviar mensagem'
                      : 'Mensagem para ${loja.nome}',
                ),
              ),
              if (!podeConversar)
                Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Text(
                    proprio
                        ? 'Você está vendo seu próprio perfil.'
                        : 'Mensagens indisponíveis entre estas contas.',
                    style: TextStyle(color: _marrom, fontSize: 13.sp),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
