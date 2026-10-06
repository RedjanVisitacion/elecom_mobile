import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/notifications/notification_center_store.dart';
import 'core/notifications/push_notification_service.dart';
import 'features/elecom/student_dashboard/utils/theme_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeNotifier.load();
  await PushNotificationService.init();
  await NotificationCenterStore.init();
  runApp(const ElecomApp());
}
