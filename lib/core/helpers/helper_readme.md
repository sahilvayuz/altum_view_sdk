# 🛠️ core/helpers

Pure utility functions used across the whole app.  
No Flutter widgets. No business logic. Just simple input → output functions.

---

## Files

```
core/helpers/
├── date_helper.dart        ← DateTime formatting and parsing
├── string_helper.dart      ← String utilities (trim, capitalize, mask)
└── validator_helper.dart   ← Form validation helpers
```

---

## date_helper.dart

```dart
import 'package:intl/intl.dart';

class DateHelper {
  DateHelper._();

  // "2024-06-15" → "15 Jun 2024"
  static String formatDisplayDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  // "2024-06-15T10:30:00Z" → DateTime object
  static DateTime parseIsoString(String iso) {
    return DateTime.parse(iso).toLocal();
  }

  // DateTime → "10:30 AM"
  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  // How long ago? → "2 hours ago"
  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inHours < 1)    return '${diff.inMinutes}m ago';
    if (diff.inDays < 1)     return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
```

---

## string_helper.dart

```dart
class StringHelper {
  StringHelper._();

  // "hello world" → "Hello World"
  static String toTitleCase(String text) {
    return text
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  // "john.doe@email.com" → "jo***@email.com"
  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final masked = name.length <= 2 ? name : '${name.substring(0, 2)}***';
    return '$masked@${parts[1]}';
  }

  // Null-safe empty check
  static bool isNullOrEmpty(String? value) {
    return value == null || value.trim().isEmpty;
  }
}
```

---

## validator_helper.dart

```dart
class ValidatorHelper {
  ValidatorHelper._();

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email';
    return null; // null = valid
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }
}
```

---

## Usage in a Widget

```dart
// In any widget or provider
Text(DateHelper.formatDisplayDate(device.lastSeen)),
Text(StringHelper.toTitleCase(device.name)),
TextFormField(validator: ValidatorHelper.validateEmail),
```

---

## Rules

- ✅ Every function is `static` — no instances needed
- ✅ Functions are pure: same input always gives same output
- ❌ No `BuildContext`, no API calls, no providers here
- ✅ Add `intl` to `pubspec.yaml` for date formatting: `intl: ^0.19.0`
