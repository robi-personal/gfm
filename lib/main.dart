import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'features/notifications/data/services/notification_service.dart';
import 'features/paywall/data/services/subscription_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}

  await SubscriptionService.configure();

  // Route Flutter framework errors to Crashlytics.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Route async/platform errors to Crashlytics.
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  configureDependencies();

  // Initialise FCM + local notifications listeners in the background; permission
  // is requested at sign-in time, so blocking startup here is unnecessary.
  unawaited(getIt<NotificationService>().init());

  runApp(const App());
}
