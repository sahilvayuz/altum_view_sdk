# 🧠 feature/domain/

The domain layer is the **heart of the feature** — pure Dart, no Flutter, no HTTP.  
It defines *what* the app can do, completely independent of *how* it does it.

---

## Structure

```
domain/
├── entities/               ← The real data shapes your app works with
└── repositories/           ← Abstract contracts (interfaces)
```

---

## entities/

Entities are simple Dart classes. No `fromJson`, no Flutter imports.

```dart
// device_entity.dart
class DeviceEntity {
  final String id;
  final String name;
  final bool isConnected;

  const DeviceEntity({
    required this.id,
    required this.name,
    required this.isConnected,
  });
}
```

---

## repositories/

An abstract class that declares what operations are possible.  
The `data/` layer implements this. The `presentation/` layer uses it.

```dart
// device_repository.dart
import '../entities/device_entity.dart';

abstract class DeviceRepository {
  Future<List<DeviceEntity>> getDevices();
  Future<void> connectToDevice(String deviceId);
  Future<void> disconnectDevice(String deviceId);
}
```

---

## Why This Layer Exists

- You can **swap the API** (REST → GraphQL → Bluetooth) without touching the UI
- You can **write unit tests** for business logic without a running server
- The presentation layer **never knows** if data comes from the network or cache

---

## Rules

- ✅ Pure Dart only — no `package:flutter`, no `package:dio`
- ✅ Entities hold only data — no methods that call services
- ✅ Repository is abstract — implementation stays in `data/`
- ❌ Never import from `data/` inside `domain/`
