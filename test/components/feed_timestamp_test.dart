import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/components/feed_timestamp.dart';

void main() {
  test('Hoje e Ontem respeitam a virada do dia e do ano', () {
    final agora = DateTime(2026, 1, 1, 0, 5);
    expect(
      formatarDataFeed(DateTime(2026, 1, 1, 0, 1), agora: agora),
      'Hoje • 00:01',
    );
    expect(
      formatarDataFeed(DateTime(2025, 12, 31, 23, 59), agora: agora),
      'Ontem • 23:59',
    );
    expect(
      formatarDataFeed(DateTime(2025, 12, 30, 12), agora: agora),
      '30/12/2025 • 12:00',
    );
  });
}
