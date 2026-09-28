import 'package:flutter/material.dart';
import 'package:nhac/components/app_notification.dart';

extension AppUiUtils on BuildContext {
  void showError(String message) {
    showAppNotification(
      this,
      message: message,
      type: NotificationType.error,
    );
  }

  void showSuccess(String message) {
    showAppNotification(
      this,
      message: message,
      type: NotificationType.success,
    );
  }

  void showInfo(String message) {
    showAppNotification(
      this,
      message: message,
      type: NotificationType.info,
    );
  }
}
