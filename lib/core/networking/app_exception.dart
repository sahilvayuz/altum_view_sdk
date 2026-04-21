// ─────────────────────────────────────────────────────────────────────────────
// core/errors/app_exception.dart
//
// Typed exception hierarchy used across the entire app.
// Providers catch these and expose them as human-readable error strings.
// ─────────────────────────────────────────────────────────────────────────────

sealed class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// Generic API-level error (non-specific HTTP failure)
class ApiException extends AppException {
  const ApiException(super.message);
}

/// 400 / 422 — Caller sent invalid data
class BadRequestException extends AppException {
  const BadRequestException(super.message);
}

/// 401 / 403 — Token missing or expired
class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message);
}

/// 404 — Resource does not exist
class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

/// 500-level — Server-side failure
class ServerException extends AppException {
  const ServerException(super.message);
}

/// Timeout or no connectivity
class NetworkException extends AppException {
  const NetworkException(super.message);
}

/// BLE-specific errors (scan, connect, MTU, characteristic)
class BleException extends AppException {
  const BleException(super.message);
}

/// Parse / mapping errors
class ParseException extends AppException {
  const ParseException(super.message);
}