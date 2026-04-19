# 📱 Flutter Project — Codebase Guide

## Architecture Overview

This project follows **Clean Architecture** with **Feature-First** folder structure.

```
lib/
├── core/                   # Shared utilities used across all features
│   ├── constants/          # App-wide constants (colors, strings, URLs)
│   ├── design_system/      # Reusable UI tokens (text styles, spacing, theme)
│   ├── helpers/            # Pure utility functions (date, format, validators)
│   ├── logger/             # Logging utility wrapper
│   └── networking/         # Dio HTTP client setup
├── features/               # One folder per app screen/feature
│   ├── altum_view/
│   ├── calibration/
│   └── device_connection/
│       ├── data/           # API calls, models, repository implementation
│       ├── domain/         # Business logic, entities, repository contract
│       └── presentation/   # UI screens, widgets, providers
├── shared/                 # Widgets used by MORE THAN ONE feature
└── main.dart               # App entry point
```

---

## State Management

We use **Provider** for state management.

- Each feature has its own `Provider` (or `ChangeNotifier`) class inside `presentation/`
- Providers are registered at the top level in `main.dart` via `MultiProvider`
- Never put business logic inside widgets — always delegate to the provider

```dart
// Good
context.read<DeviceConnectionProvider>().connectDevice(id);

// Bad — logic inside widget
setState(() { device = fetchDevice(id); });
```

---

## Networking

All HTTP calls go through the central `DioClient` in `core/networking/`.

- Services call `DioClient` — never create raw `Dio()` instances elsewhere
- See `core/networking/README.md` for full usage

---

## Rules

| Rule | Why |
|------|-----|
| Each widget belongs to its feature | Keeps features self-contained |
| Globally reused widgets go in `shared/` | Single source of truth |
| No raw `Dio()` outside `core/networking/` | Consistent headers/interceptors |
| No business logic in widgets | Testable, readable code |
| Helper functions go in `core/helpers/` | Reusable, testable utilities |

---

## Getting Started

```bash
flutter pub get
flutter run
```
