import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nhac/services/notificacao_historico_service.dart';

class NotificacoesPage extends StatefulWidget {
  const NotificacoesPage({super.key, required this.usuarioId});
  final String? usuarioId;

  @override
  State<NotificacoesPage> createState() => _NotificacoesPageState();
}

class _NotificacoesPageState extends State<NotificacoesPage>
    with WidgetsBindingObserver {
  late Future<List<NotificacaoRegistrada>> _avisos;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _avisos = _listar();
    _subscription = NotificacaoHistoricoService.alteracoes.listen((usuarioId) {
      if (usuarioId == widget.usuarioId && mounted) _atualizar();
    });
  }

  Future<List<NotificacaoRegistrada>> _listar() => widget.usuarioId == null
      ? Future.value([])
      : NotificacaoHistoricoService.listar(widget.usuarioId!);

  Future<void> _atualizar() async {
    final future = _listar();
    setState(() => _avisos = future);
    try {
      await future;
    } catch (_) {
      // O FutureBuilder apresenta o erro e oferece nova tentativa.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _atualizar();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFFFE7E5),
        appBar: AppBar(
          title: const Text(
            'Notificações',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFFFE7E5),
          foregroundColor: const Color(0xFF5D201C),
          surfaceTintColor: Colors.transparent,
        ),
        body: FutureBuilder<List<NotificacaoRegistrada>>(
          future: _avisos,
          builder: (context, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6961)),
              );
            }
            final avisos = snapshot.data ?? [];
            return RefreshIndicator(
              color: const Color(0xFFFF6961),
              onRefresh: _atualizar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (snapshot.hasError) ...[
                    const Text(
                      'Não foi possível carregar suas notificações.',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: _atualizar,
                      child: const Text('Tentar novamente'),
                    ),
                  ] else if (avisos.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            size: 64,
                            color: Color(0xFFFF6961),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.usuarioId == null
                                ? 'Entre na sua conta para ver os avisos.'
                                : 'As atualizações dos seus pedidos aparecerão aqui.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF5D201C)),
                          ),
                        ],
                      ),
                    ),
                  for (final aviso in avisos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: const Icon(
                            Icons.notifications_active_outlined,
                            color: Color(0xFFFF6961),
                          ),
                          title: Text(
                            aviso.titulo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D201C),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text(aviso.corpo),
                              const SizedBox(height: 8),
                              Text(
                                DateFormat('dd/MM/yyyy • HH:mm')
                                    .format(aviso.recebidaEm.toLocal()),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          trailing: aviso.pedidoId == null
                              ? null
                              : const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFFFF6961),
                                ),
                          onTap: aviso.pedidoId == null
                              ? null
                              : () {
                                  final path = aviso.status?.terminal == true
                                      ? '/pedido-detalhes'
                                      : '/rastreio';
                                  context.push(
                                    '$path?pedidoId=${Uri.encodeQueryComponent(aviso.pedidoId!)}',
                                  );
                                },
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
}
