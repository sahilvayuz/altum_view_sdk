// ─────────────────────────────────────────────────────────────────────────────
// features/wifi_connection/domain/repositories/wifi_repository.dart
// ─────────────────────────────────────────────────────────────────────────────

abstract interface class WifiRepository {
  Future<List<String>>         getAvailableNetworks();
  Future<void>                 disconnectCurrent(String token);
  Future<Map<String, dynamic>> setServer(String token);
  Future<Map<String, dynamic>> changeWifi({
    required String token,
    required String ssid,
    required String password,
    required String mqttPasscode,
    required String groupId,
  });
}