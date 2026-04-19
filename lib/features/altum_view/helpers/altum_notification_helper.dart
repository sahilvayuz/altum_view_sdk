// ─────────────────────────────────────────────────────────────────────────────
// altum_notification_helper.dart
//
// Shows a local push notification when a new fall alert arrives.
// Uses the flutter_local_notifications package.
//
// Add to pubspec.yaml:
//   flutter_local_notifications: ^17.0.0
//
// Android: no extra setup needed for basic notifications.
// iOS: add to ios/Runner/AppDelegate.swift:
//   UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';
import 'dart:ui';
import 'package:altum_view_sdk/features/altum_view/services/altum_alert_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AltumNotificationHelper {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool  _initialized = false;

  /// Call this once in main() before runApp()
  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    _initialized = true;
    log('🔔 NotificationHelper initialized');
  }

  /// Call this when AltumAlertService.onNewAlert fires
  static Future<void> showFallAlert(AltumAlert alert) async {
    if (!_initialized) await init();

    await _plugin.show(
     id: alert.id.hashCode, // ✅ ID goes here
      title: '🚨 Fall Detected',
      body: '${alert.personName} — ${alert.eventType}',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'fall_alerts',
          'Fall Alerts',
          channelDescription: 'AltumView fall detection alerts',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    log('🔔 Notification shown: ${alert.personName}');
  }
}