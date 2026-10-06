import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/services/push_notification_service.dart';

void main() {
  test(
    'aviso sem destinatário ou para outra conta não pode ser exibido ou aberto',
    () {
      expect(
        PushNotificationService.pertenceAConta({'usuarioId': 'u1'}, 'u1'),
        isTrue,
      );
      expect(
        PushNotificationService.pertenceAConta({'usuarioId': 'u1'}, 'u2'),
        isFalse,
      );
      expect(
        PushNotificationService.pertenceAConta({'usuarioId': 'u1'}, null),
        isFalse,
      );
      expect(PushNotificationService.pertenceAConta({}, 'u1'), isFalse);
    },
  );
}
