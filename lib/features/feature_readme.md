# 📦 features/

Each subfolder is a **self-contained feature** of the app.

---

## Structure Rule

Every feature follows the same 3-layer folder pattern:

```
features/
└── your_feature/
    ├── data/               ← API calls, JSON models, repository impl
    ├── domain/             ← Business rules, entities, abstract repo
    └── presentation/       ← Provider, screens, and widgets
```

---

## Layer Responsibilities

### `data/`
- Talks to the outside world (API, local DB, Bluetooth)
- Contains: models (JSON ↔ Dart), service classes, repository implementation
- Only uses `DioClient.instance` for HTTP — never raw `Dio()`

### `domain/`
- Pure Dart — no Flutter, no Dio, no external dependencies
- Contains: entity classes (the real data shapes), repository abstract class, use cases
- Defines **what** the app can do, not **how**

### `presentation/`
- Flutter widgets and providers
- Contains: one `*_provider.dart`, screens, and feature-specific widgets
- Widgets just read from the provider and call provider methods

---

## Full Example — `device_connection`

```
device_connection/
├── data/
│   ├── models/
│   │   └── device_model.dart          ← fromJson / toJson
│   ├── services/
│   │   └── device_service.dart        ← HTTP calls via DioClient
│   └── repositories/
│       └── device_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── device_entity.dart         ← Pure Dart class
│   └── repositories/
│       └── device_repository.dart     ← Abstract (interface)
└── presentation/
    ├── providers/
    │   └── device_connection_provider.dart
    ├── screens/
    │   └── device_connection_screen.dart
    └── widgets/
        ├── device_list_tile.dart      ← Only used in this feature
        └── connection_status_badge.dart
```

---

## Creating a New Feature

1. Create the folder: `features/my_feature/data/`, `domain/`, `presentation/`
2. Define the entity in `domain/entities/`
3. Write the abstract repository in `domain/repositories/`
4. Implement the service in `data/services/` using `DioClient`
5. Implement the repository in `data/repositories/`
6. Create the provider in `presentation/providers/`
7. Build screens and widgets in `presentation/screens/` and `presentation/widgets/`
8. Register the provider in `main.dart`

---

## Rules

- ✅ Widgets specific to a feature stay inside that feature's `presentation/widgets/`
- ✅ If a widget is used in 2+ features → move it to `shared/`
- ❌ Features must not import from each other's `data/` or `presentation/` layers
