// ─────────────────────────────────────────────────────────────────────────────
// features/wifi_connection/data/sources/wifi_remote_data_source.dart
//
// Handles changing Wi-Fi credentials on a camera that is ALREADY live.
// This is a separate feature from the initial device_connection setup flow.
//
// Flow:
//   1. Scan → connect BLE
//   2. /GET network_list — show user available networks
//   3. /DISCONNECT → /SERVER → /SET with new credentials
// ─────────────────────────────────────────────────────────────────────────────


import 'package:altum_view_sdk/core/services/ble_services.dart';

/// Thin wrapper — re-uses BleService for all BLE commands.
/// No new logic; it is a named boundary so the WiFi feature
/// has its own provider and repository.
class WifiDataSource {
  final BleService _ble;
  WifiDataSource(this._ble);

  Future<List<String>> scanWifiNetworks() async {
    _ble.deviceWifiList.clear();
    await _ble.getWifiList();
    return List.from(_ble.deviceWifiList);
  }

  Future<void> disconnect(String token) =>
      _ble.disconnectFromPreviousNetwork(token);

  Future<Map<String, dynamic>> setServer(String token) =>
      _ble.setServer(token);

  Future<Map<String, dynamic>> setWifi({
    required String token,
    required String ssid,
    required String password,
    required String mqttPasscode,
    required String groupId,
  }) =>
      _ble.setWifi(
        token:        token,
        ssid:         ssid,
        password:     password,
        mqttPasscode: mqttPasscode,
        groupId:      groupId,
      );
}