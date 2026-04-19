# 🌐 core/networking

This folder contains the **single Dio HTTP client** for the entire app.  
All features call this — never create a raw `Dio()` anywhere else.

---

## Files

```
core/networking/
└── dio_client.dart     ← The only place Dio is configured
```

---

## dio_client.dart — Full Implementation

```dart
import 'package:dio/dio.dart';

class DioClient {
  // Private constructor — use DioClient.instance everywhere
  DioClient._();
  static final DioClient instance = DioClient._();

  late final Dio _dio;

  /// Call this once in main.dart before runApp()
  void init({required String baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Log requests and responses in debug mode
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));

    // Add auth token to every request automatically
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // TODO: read token from secure storage and attach
          // options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (DioException error, handler) {
          // Handle 401 globally — redirect to login, etc.
          handler.next(error);
        },
      ),
    );
  }

  // ─── HTTP helpers ────────────────────────────────────────────────

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    return await _dio.get(path, queryParameters: queryParams);
  }

  Future<Response> post(
    String path, {
    dynamic body,
  }) async {
    return await _dio.post(path, data: body);
  }

  Future<Response> put(
    String path, {
    dynamic body,
  }) async {
    return await _dio.put(path, data: body);
  }

  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }
}
```

---

## Setup in main.dart

```dart
void main() {
  DioClient.instance.init(baseUrl: AppConstants.baseUrl);
  runApp(const MyApp());
}
```

---

## Usage Inside a Service

```dart
// features/device_connection/data/services/device_service.dart

import 'package:your_app/core/networking/dio_client.dart';

class DeviceService {
  final _client = DioClient.instance;

  Future<Map<String, dynamic>> fetchDevices() async {
    final response = await _client.get('/devices');
    return response.data as Map<String, dynamic>;
  }

  Future<void> connectDevice(String deviceId) async {
    await _client.post('/devices/connect', body: {'id': deviceId});
  }
}
```

---

## Rules

- ✅ Use `DioClient.instance` in every service
- ❌ Never do `Dio()` directly in a feature or widget
- ✅ Add interceptors only here — they apply to every request automatically
