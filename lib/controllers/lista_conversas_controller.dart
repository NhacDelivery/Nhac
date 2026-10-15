import 'package:flutter/foundation.dart';
import 'package:nhac/utils/error_ui_helper.dart';

/// Estado de uma caixa de conversas. Refresh e paginação conservam os dados
/// confirmados; uma falha nunca vira uma caixa vazia.
class ListaConversasController<T> extends ChangeNotifier {
  final Future<List<T>> Function(int pagina, int tamanho) buscar;
  final String Function(T item) identificar;
  final int tamanho;
  final List<T> _itens = [];
  List<T> get itens => List.unmodifiable(_itens);
  bool carregando = false;
  bool carregou = false;
  bool temMais = true;
  String? erro;
  int _pagina = 0;
  bool _disposed = false;
  Future<void>? _consulta;
  bool _ultimaReiniciar = false;

  Future<void> tentarNovamente() => carregar(reiniciar: _ultimaReiniciar);

  ListaConversasController(
      {required this.buscar, required this.identificar, this.tamanho = 20});

  Future<void> carregar({bool reiniciar = false}) {
    if (_disposed) return Future.value();
    if (_consulta != null) return _consulta!;
    if (!reiniciar && !temMais) return Future.value();
    final consulta = _carregar(reiniciar);
    _consulta = consulta;
    return consulta.whenComplete(() => _consulta = null);
  }

  Future<void> _carregar(bool reiniciar) async {
    _ultimaReiniciar = reiniciar;
    carregando = true;
    erro = null;
    notifyListeners();
    final pagina = reiniciar ? 0 : _pagina;
    try {
      final novos = await buscar(pagina, tamanho);
      if (_disposed) return;
      if (reiniciar) _itens.clear();
      final ids = _itens.map(identificar).toSet();
      _itens.addAll(novos.where((item) => ids.add(identificar(item))));
      _pagina = pagina + 1;
      temMais = novos.length == tamanho;
      carregou = true;
    } catch (e) {
      if (!_disposed)
        erro = ErrorUIHelper.mensagem(e,
            fallback:
                'Não foi possível carregar as conversas. Tente novamente.');
    } finally {
      if (!_disposed) {
        carregando = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
