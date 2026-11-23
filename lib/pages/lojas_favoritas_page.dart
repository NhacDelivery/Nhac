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
    setState(() { _carregando = true; _erro = false; });
    try {
      final lojas = await _repository.listarLojasFavoritas(page: pagina);
      if (!mounted) return;
      setState(() {
        _lojas = {for (final loja in [...(mais ? _lojas : <LojasModel>[]), ...lojas]) loja.id: loja}.values.toList();
        _pagina = pagina;
        _temMais = lojas.length == 10;
      });
    } catch (_) {
      if (mounted) setState(() { _erro = true; _falhouAoPaginar = mais; });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrir(LojasModel loja) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LojaPage(loja: loja),
    ));
    if (mounted) await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lojas favoritas')),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            for (final loja in _lojas)
              ListTile(
                leading: ClipOval(child: loja.imagemUrl.isEmpty
                    ? const Icon(Icons.storefront)
                    : Image.network(loja.imagemUrl, width: 44, height: 44, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.storefront))),
                title: Text(loja.nome),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _abrir(loja),
              ),
            if (_carregando) const Center(child: CircularProgressIndicator())
            else if (_erro) ...[
              const Text('Não foi possível carregar as lojas favoritas.', textAlign: TextAlign.center),
              TextButton(onPressed: () => _carregar(mais: _lojas.isNotEmpty && _falhouAoPaginar), child: const Text('Tentar novamente')),
            ] else if (_lojas.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 48),
                child: Text('As lojas que você seguir aparecerão aqui.', textAlign: TextAlign.center))
            else if (_temMais)
              TextButton(onPressed: () => _carregar(mais: true), child: const Text('Carregar mais lojas')),
          ],
        ),
      ),
    );
  }
}
