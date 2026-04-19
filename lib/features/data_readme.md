# 📡 feature/data/

The data layer talks to the **outside world** — your API, local storage, or hardware.

---

## Structure

```
data/
├── models/                 ← JSON ↔ Dart class converters
├── services/               ← HTTP calls using DioClient
└── repositories/           ← Implements the domain repository contract
```

---

## models/

A model maps exactly to what the API returns.

```dart
// device_model.dart
class DeviceModel {
  final String id;
  final String name;

  DeviceModel({required this.id, required this.name});

  // fromJson: API response → Dart object
  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id:   json['id']   as String,
      name: json['name'] as String,
    );
  }

  // toJson: Dart object → API request body
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
```

---

## services/

Each service class groups related API calls.  
Always use `DioClient.instance` — never `Dio()` directly.

```dart
// device_service.dart
import 'package:your_app/core/networking/dio_client.dart';

class DeviceService {
  final _client = DioClient.instance;

  Future<List<DeviceModel>> getDevices() async {
    final res = await _client.get('/devices');
    return (res.data['devices'] as List)
        .map((e) => DeviceModel.fromJson(e))
        .toList();
  }
}
```

---

## repositories/

Implements the abstract class defined in `domain/repositories/`.  
Converts models to domain entities so the rest of the app stays independent of API shapes.

```dart
class DeviceRepositoryImpl implements DeviceRepository {
  final DeviceService _service;
  DeviceRepositoryImpl(this._service);

  @override
  Future<List<DeviceEntity>> getDevices() async {
    final models = await _service.getDevices();
    return models.map((m) => DeviceEntity(id: m.id, name: m.name)).toList();
  }
}
```

---

## Rules

- ✅ One service class per API resource group
- ✅ Always convert models → entities in the repository
- ❌ Domain layer must never import from `data/`
- ❌ Never use `Dio()` directly in a service
