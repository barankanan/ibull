import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../core/runtime_diagnostic_logger.dart';
import '../firebase_options.dart';
import '../services/push_notification_service.dart';

Future<void> initFirebaseNative() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

Future<void> initPushNotifications({
  required GlobalKey<NavigatorState> navigatorKey,
}) async {
  RuntimeDiagnosticLogger.fcm('token sync deferred (background init)');
  try {
    await PushNotificationService.instance.initialize(
      navigatorKey: navigatorKey,
    );
  } catch (error, stackTrace) {
    debugPrint('PushNotificationService initialize failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
