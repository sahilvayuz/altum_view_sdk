// ─────────────────────────────────────────────────────────────────────────────
// features/wifi_connection/data/repositories/wifi_repository_impl.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/features/wifi_connection/data/data_source_implimentation/wifi_data_source.dart';
import '../../domain/repositories/wifi_repository.dart';

class WifiRepositoryImpl implements WifiRepository {
  final WifiDataSource _source;
  WifiRepositoryImpl(this._source);

  @override
  Future<List<String>> getAvailableNetworks() => _source.scanWifiNetworks();

  @override
  Future<void> disconnectCurrent(String token) => _source.disconnect(token);

  @override
  Future<Map<String, dynamic>> setServer(String token) =>
      _source.setServer(token);

  @override
  Future<Map<String, dynamic>> changeWifi({
    required String token,
    required String ssid,
    required String password,
    required String mqttPasscode,
    required String groupId,
  }) =>
      _source.setWifi(
        token:        token,
        ssid:         ssid,
        password:     password,
        mqttPasscode: mqttPasscode,
        groupId:      groupId,
      );
}