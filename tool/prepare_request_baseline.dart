import 'dart:io';
import 'dart:convert';

void main(List<String> args) {
  const files = {
    'lib/pages/home_page.dart': 'home_page.dart',
    'lib/components/home/home_content.dart': 'home_content.dart',
    'lib/components/home/home_order_tracking_card.dart':
        'home_order_tracking_card.dart',
    'lib/pages/rastreio_pedido_page.dart': 'rastreio_pedido_page.dart',
    'lib/repositories/produto_repository.dart': 'produto_repository.dart',
    'lib/repositories/pedido_repository.dart': 'pedido_repository.dart',
    'lib/repositories/loja_repository.dart': 'loja_repository.dart',
    'lib/repositories/entrega_repository.dart': 'entrega_repository.dart',
  };
  if (args.contains('--clean')) {
    for (final name in files.values) {
      final file = File('test/.request_baseline/$name');
      if (file.existsSync()) file.deleteSync();
    }
    final directory = Directory('test/.request_baseline');
    if (directory.existsSync()) directory.deleteSync();
    final test = File('test/.request_benchmark_test.dart');
    if (test.existsSync()) test.deleteSync();
    return;
  }
  Directory('test/.request_baseline').createSync(recursive: true);
  for (final entry in files.entries) {
    final result = Process.runSync('git', ['show', '76f9fb4:${entry.key}'],
        stdoutEncoding: utf8);
    if (result.exitCode != 0) throw StateError(entry.key);
    var source = result.stdout as String;
    for (final dependency in files.entries) {
      source = source.replaceAll(
          'package:nhac/${dependency.key.substring(4)}', dependency.value);
    }
    File('test/.request_baseline/${entry.value}').writeAsStringSync(source);
  }
  File('test/.request_benchmark_test.dart').writeAsStringSync(
      File('tool/request_benchmark.dart.template').readAsStringSync());
}
