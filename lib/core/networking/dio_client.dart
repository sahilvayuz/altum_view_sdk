// ─────────────────────────────────────────────────────────────────────────────
// core/network/dio_client.dart
//
// Centralised Dio HTTP client used by every feature repository.
//
// Responsibilities:
//   • Attach Bearer token to every request (via interceptor)
//   • Convert non-2xx responses into AppException (typed errors)
//   • Log request / response in debug mode
//   • Retry on network failure (optional, can be extended)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';

import 'package:altum_view_sdk/core/networking/api_constant.dart';
import 'package:altum_view_sdk/core/networking/app_exception.dart';
import 'package:dio/dio.dart';

class DioClient {
  late final Dio _dio;

  /// [accessToken] — Bearer token set once at app-start (or after login).
  /// Re-create this client or call [updateToken] if the token changes.
  DioClient({required String accessToken}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(accessToken),
      _LogInterceptor(),
      _ErrorInterceptor(),
    ]);
  }

  // ── Public HTTP helpers ────────────────────────────────────────────────────

  Future<Response<T>> get<T>(
      String path, {
        Map<String, dynamic>? queryParameters,
        Options? options,
      }) =>
      _dio.get<T>(path,
          queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(
      String path, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
        Options? options,
      }) =>
      _dio.post<T>(path,
          data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> patch<T>(
      String path, {
        dynamic data,
        Options? options,
      }) =>
      _dio.patch<T>(path, data: data, options: options);

  Future<Response<T>> delete<T>(
      String path, {
        Options? options,
      }) =>
      _dio.delete<T>(path, options: options);

  Future<Response<T>> postFormData<T>(
      String path, {
        required FormData formData,
      }) =>
      _dio.post<T>(
        path,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

  /// Downloads raw bytes (images, background frames, etc.)
  ///
  /// FIX: Uses the authenticated _dio instance (with _AuthInterceptor) instead
  /// of a naked Dio() — the old Dio().get() had no Bearer token → 401 on
  /// any endpoint that requires auth (e.g. /cameras/:id/view?preview_token=…).
  Future<Response<List<int>>> getBytes(String path) => _dio.get<List<int>>(
    path,
    options: Options(responseType: ResponseType.bytes),
  );

  /// Update the Bearer token without rebuilding the client.
  void updateToken(String newToken) {
    final authInterceptor =
        _dio.interceptors.whereType<_AuthInterceptor>().firstOrNull;
    authInterceptor?.updateToken(newToken);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auth Interceptor — attaches Bearer token to every outgoing request
// ─────────────────────────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  String _token;
  _AuthInterceptor(this._token);

  void updateToken(String token) => _token = token;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Authorization'] = 'Bearer $_token';
    handler.next(options);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Log Interceptor — prints concise request/response lines in debug mode
// ─────────────────────────────────────────────────────────────────────────────

class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    log('➡️  [${options.method}] ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    log('✅  [${response.statusCode}] ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    log('❌  [${err.response?.statusCode}] ${err.requestOptions.uri} — ${err.message}');
    handler.next(err);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error Interceptor — converts DioException → AppException
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final appException = switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
          NetworkException('Connection timed out. Please try again.'),
      DioExceptionType.badResponse => _mapStatusCode(err),
      DioExceptionType.connectionError =>
          NetworkException('No internet connection. Please check your network.'),
      _ => ApiException('An unexpected error occurred: ${err.message}'),
    };

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: appException,
        response: err.response,
        type: err.type,
      ),
    );
  }

  AppException _mapStatusCode(DioException err) {
    final code    = err.response?.statusCode ?? 0;
    final message = _extractMessage(err.response?.data);
    return switch (code) {
      400 => BadRequestException(message ?? 'Bad request'),
      401 => UnauthorizedException(message ?? 'Unauthorised — check your token'),
      403 => UnauthorizedException(message ?? 'Forbidden'),
      404 => NotFoundException(message ?? 'Resource not found'),
      422 => BadRequestException(message ?? 'Validation failed'),
      500 || 502 || 503 =>
          ServerException(message ?? 'Server error — try again later'),
      _ => ApiException(message ?? 'HTTP $code error'),
    };
  }

  String? _extractMessage(dynamic data) {
    if (data is Map) return data['message'] as String?;
    return null;
  }
}