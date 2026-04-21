// ─────────────────────────────────────────────────────────────────────────────
// bootstrap.dart
//
// App entry point called from main.dart via:
//   void main() => bootstrap();
//
// Responsibilities:
//   1. Initialize Flutter bindings
//   2. Wrap the app in MultiProvider at the very top of the widget tree
//   3. Catch and log unhandled zone errors
//
// WHY MultiProvider IS HERE (not in MainShell):
//   Placing providers at the root means every pushed route automatically
//   inherits them — no need to wrap each Navigator.push with .value().
//
// WHY create: lambdas (not .value):
//   create: (() => ServiceLocator.xProvider) is evaluated LAZILY — only when
//   the provider is first read by a widget. By that time, MainShell.initState()
//   has already called ServiceLocator.init(token), so every field is ready.
//   If a provider is never read, it is never accessed — zero cost.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:developer';
import 'package:altum_view_sdk/app/app.dart';
import 'package:altum_view_sdk/app/service_locator.dart';
import 'package:altum_view_sdk/features/alerts/presentation/controller/alert_provider.dart';
import 'package:altum_view_sdk/features/calibration/presentation/controllers/calibration_provider.dart';
import 'package:altum_view_sdk/features/camera/presentation/controllers/camera_provider.dart';
import 'package:altum_view_sdk/features/device_connection/presentation/controller/device_connection_provider.dart';
import 'package:altum_view_sdk/features/device_settings/presentation/controllers/device_settings_provider.dart';
import 'package:altum_view_sdk/features/people/presentation/controller/person_provider.dart';
import 'package:altum_view_sdk/features/people_groups/presentation/controller/person_group_provider.dart';
import 'package:altum_view_sdk/features/rooms/presentation/controllers/room_provider.dart';
import 'package:altum_view_sdk/features/skeleton_stream/presentation/screens/skeleton_stream_screen.dart';
import 'package:altum_view_sdk/features/wifi_connection/presentation/controller/wifi_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> bootstrap() async {
  final bootFuture = runZonedGuarded<Future<void>>(
        () async {
      // ── 1. Flutter bindings ────────────────────────────────────────────────
      WidgetsFlutterBinding.ensureInitialized();

      // ── 2. Uncomment when notification helper is ready ─────────────────────
      // await AltumNotificationHelper.init();

      // ── 3. Run app with top-level MultiProvider ────────────────────────────
      //
      // create: lambdas are lazy — they only execute when a widget first calls
      // context.read<T>() or context.watch<T>(). That always happens AFTER
      // MainShell.initState() has called ServiceLocator.init(token).
      //
      // This means providers are available in every route automatically,
      // including any screen pushed via Navigator.push — no wrapping needed.
      runApp(
        MultiProvider(
          providers: [
            // ── Camera ────────────────────────────────────────────────────────
            ChangeNotifierProvider<CameraProvider>(
              create: (_) => ServiceLocator.cameraProvider,
            ),

            // ── Rooms ─────────────────────────────────────────────────────────
            ChangeNotifierProvider<RoomProvider>(
              create: (_) => ServiceLocator.roomProvider,
            ),

            // ── Device connection ─────────────────────────────────────────────
            ChangeNotifierProvider<DeviceConnectionProvider>(
              create: (_) => ServiceLocator.deviceConnectionProvider,
            ),

            // ── WiFi ──────────────────────────────────────────────────────────
            ChangeNotifierProvider<WifiProvider>(
              create: (_) => ServiceLocator.wifiProvider,
            ),

            // ── Calibration ───────────────────────────────────────────────────
            ChangeNotifierProvider<CalibrationProvider>(
              create: (_) => ServiceLocator.calibrationProvider,
            ),

            // ── Alerts ────────────────────────────────────────────────────────
            ChangeNotifierProvider<AlertProvider>(
              create: (_) => ServiceLocator.alertProvider,
            ),

            // ── People ────────────────────────────────────────────────────────
            ChangeNotifierProvider<PersonProvider>(
              create: (_) => ServiceLocator.personProvider,
            ),

            // ── People Groups ─────────────────────────────────────────────────
            ChangeNotifierProvider<PersonGroupProvider>(
              create: (_) => ServiceLocator.personGroupProvider,
            ),

            // ── Device Settings ───────────────────────────────────────────────
            ChangeNotifierProvider<DeviceSettingsProvider>(
              create: (_) => ServiceLocator.deviceSettingsProvider,
            ),

            // ── SkeletonStreamProvider is intentionally NOT registered here.
            //    It requires a cameraId + serialNumber only known at runtime.
            //    Create it per-camera inside the live stream screen:
            //
               ChangeNotifierProvider(
                 create: (_) => ServiceLocator.buildSkeletonProvider(
                   cameraId:     11303,
                   serialNumber: '230C4C2056C9D0EE',
                 ),
                 child: const SkeletonStreamScreen(cameraId: 11303, serialNumber: '230C4C2056C9D0EE',),
               )
          ],
          child: const App(),
        ),
      );
    },
        (error, stack) {
      // ── Zone-level error handler ───────────────────────────────────────────
      // Replace with your crash reporting (e.g. Firebase Crashlytics):
      //   FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      log('Unhandled error: $error', error: error, stackTrace: stack);
    },
  );

  if (bootFuture != null) {
    await bootFuture;
  }
}