# 📋 core/logger

A simple logging wrapper so we can swap out the underlying library without touching features.

---

## Files

```
core/logger/
└── app_logger.dart
```

---

## app_logger.dart

```dart
import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void info(String message) {
    if (kDebugMode) debugPrint('ℹ️  [INFO] $message');
  }

  static void warning(String message) {
    if (kDebugMode) debugPrint('⚠️  [WARN] $message');
  }

  static void error(String message, [Object? error, StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint('❌ [ERROR] $message');
      if (error != null) debugPrint('   Error: $error');
      if (stack != null) debugPrint('   Stack: $stack');
    }
    // TODO: send to crash reporting (Sentry, Firebase Crashlytics) in production
  }
}
```

---

## Usage

```dart
AppLogger.info('Device connected: $deviceId');
AppLogger.warning('Retrying connection...');
AppLogger.error('Failed to fetch devices', e, stackTrace);
```

---

## Rules

- ✅ Use `AppLogger` everywhere — never use `print()` directly
- ✅ Logs only appear in debug mode by default
- ✅ Hook `error()` into a crash reporter for production builds
