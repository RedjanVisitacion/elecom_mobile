import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/notifications/local_push_service.dart';
import 'core/notifications/notification_center_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalPushService.init();
  await NotificationCenterStore.init();
  runApp(const ElecomApp());
}
