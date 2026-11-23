import 'package:flutter/material.dart';
import 'package:nhac/models/loja/lojas.dart';
import 'package:nhac/pages/loja_page.dart';
import 'package:nhac/repositories/loja_repository.dart';

class LojasFavoritasPage extends StatefulWidget {
  final LojaRepository? repository;
  const LojasFavoritasPage({super.key, this.repository});

  @override
  State<LojasFavoritasPage> createState() => _LojasFavoritasPageState();
}

class _LojasFavoritasPageState extends State<LojasFavoritasPage> {
  late final _repository = widget.repository ?? LojaRepository();
  List<LojasModel> _lojas = [];
  int _pagina = 0;
  bool _falhouAoPaginar = false;
  bool _temMais = true, _carregando = false, _erro = false;

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
      _erro = false;
    });
    try {
      final lojas = await _repository.listarLojasFavoritas(page: pagina);
      if (!mounted) return;
      setState(() {
        _lojas = {
          for (final loja in [...(mais ? _lojas : <LojasModel>[]), ...lojas])
            loja.id: loja,
        }.values.toList();
        _pagina = pagina;
        _temMais = lojas.length == 10;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _erro = true;
          _falhouAoPaginar = mais;
        });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrir(LojasModel loja) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => LojaPage(loja: loja)));
    if (mounted) await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    const tinta = Color(0xFF5D201C);
    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFFF6961),
          onRefresh: _carregar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: BackButton(color: tinta),
              ),
              const SizedBox(height: 12),
              const Text(
                'Lojas favoritas',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: tinta,
                ),
              ),
              const SizedBox(height: 20),
              for (final loja in _lojas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _CartaoLoja(loja: loja, onTap: () => _abrir(loja)),
                ),
              if (_carregando)
                const Center(child: CircularProgressIndicator())
              else if (_erro) ...[
                const Text(
                  'Não foi possível carregar as lojas favoritas.',
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () =>
                      _carregar(mais: _lojas.isNotEmpty && _falhouAoPaginar),
                  child: const Text('Tentar novamente'),
                ),
              ] else if (_lojas.isEmpty)
                const Card(
                  elevation: 0,
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Icon(
                          Icons.favorite_border_rounded,
                          color: Color(0xFFFF6961),
                          size: 36,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Nenhuma loja favorita ainda',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: tinta,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'As lojas que você seguir aparecerão aqui.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else if (_temMais)
                TextButton(
                  onPressed: () => _carregar(mais: true),
                  child: const Text('Carregar mais lojas'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaoLoja extends StatelessWidget {
  final LojasModel loja;
  final VoidCallback onTap;

  const _CartaoLoja({required this.loja, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const tinta = Color(0xFF5D201C);
    final dados = loja.dadosOperacionais;
    final minimo = dados?.tempoEntregaMin ?? 0;
    final maximo = dados?.tempoEntregaMax ?? 0;
    final tempo = minimo > 0 && minimo < maximo
        ? '$minimo–$maximo min'
        : '$maximo min';
    const semLogo = ColoredBox(
      color: Color(0xFFFFEEEB),
      child: Center(
        child: Icon(Icons.storefront_outlined, color: tinta, size: 28),
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (loja.bannerUrl.isNotEmpty)
              Image.network(
                loja.bannerUrl,
                height: 102,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox.square(
                      dimension: 62,
                      child: loja.imagemUrl.isEmpty
                          ? semLogo
                          : Image.network(
                              loja.imagemUrl,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                              errorBuilder: (_, __, ___) => semLogo,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loja.nome,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: tinta,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (loja.categoria.isNotEmpty)
                          Text(
                            loja.categoria,
                            style: const TextStyle(color: Color(0xFF765753)),
                          ),
                        if (maximo > 0 || (dados?.totalAvaliacoes ?? 0) > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                if ((dados?.totalAvaliacoes ?? 0) > 0)
                                  _DetalheLoja(
                                    Icons.star_rounded,
                                    dados!.avaliacaoMedia
                                        .toStringAsFixed(1)
                                        .replaceAll('.', ','),
                                    'Avaliação',
                                  ),
                                if (maximo > 0)
                                  _DetalheLoja(
                                    Icons.schedule_rounded,
                                    tempo,
                                    'Tempo de entrega',
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: tinta,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetalheLoja extends StatelessWidget {
  final IconData icone;
  final String texto;
  final String rotulo;
  const _DetalheLoja(this.icone, this.texto, this.rotulo);

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$rotulo: $texto',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 16, color: const Color(0xFF97453F)),
        const SizedBox(width: 4),
        Text(
          texto,
          style: const TextStyle(fontSize: 13, color: Color(0xFF5D201C)),
        ),
      ],
    ),
  );
}
