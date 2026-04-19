# 🔗 shared/

Widgets that are used in **two or more features** live here.  
If a widget is only used in one feature, keep it inside that feature's `presentation/widgets/`.

---

## When to Move a Widget Here

| Situation | Where it goes |
|-----------|---------------|
| Widget used only in `device_connection` | `features/device_connection/presentation/widgets/` |
| Widget used in `device_connection` AND `calibration` | `shared/widgets/` |
| Widget used everywhere (loading spinner, error banner) | `shared/widgets/` |

---

## Suggested Structure

```
shared/
└── widgets/
    ├── app_loading_indicator.dart    ← Full-screen loading spinner
    ├── app_error_banner.dart         ← Error message display
    ├── app_primary_button.dart       ← Standard branded button
    ├── app_text_field.dart           ← Standard text input
    └── empty_state_view.dart         ← "No data found" illustration + text
```

---

## app_loading_indicator.dart

```dart
import 'package:flutter/material.dart';

class AppLoadingIndicator extends StatelessWidget {
  final String? message;

  const AppLoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
```

---

## app_primary_button.dart

```dart
import 'package:flutter/material.dart';

class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }
}
```

---

## app_error_banner.dart

```dart
import 'package:flutter/material.dart';

class AppErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorBanner({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
```

---

## Usage

```dart
// Any screen in any feature
import 'package:your_app/shared/widgets/app_loading_indicator.dart';

if (provider.isLoading) {
  return const AppLoadingIndicator(message: 'Loading devices...');
}
```

---

## Rules

- ✅ Shared widgets must be **stateless** or manage only their own local UI state
- ✅ Shared widgets must **not** import any single feature's provider or service
- ❌ Never put business logic in shared widgets — pass everything via constructor params
- ✅ If a shared widget grows too complex, break it into smaller composable pieces
