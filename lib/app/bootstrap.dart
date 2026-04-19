import 'dart:async';
import 'package:altum_view_sdk/app/app.dart';
import 'package:altum_view_sdk/features/altum_view/helpers/altum_notification_helper.dart';
import 'package:flutter/material.dart';

Future<void> bootstrap() async {

  final bootFuture = runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await AltumNotificationHelper.init();

      runApp(App());
    },
    (error, stack) {

    },
  );

  if (bootFuture != null) {
    await bootFuture;
  }
}
