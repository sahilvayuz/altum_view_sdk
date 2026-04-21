// ─────────────────────────────────────────────────────────────────────────────
// features/wifi_connection/presentation/providers/wifi_provider.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';
import 'package:altum_view_sdk/core/state/view_state.dart';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/wifi_repository.dart';

enum WifiChangeStep { idle, scanning, selecting, connecting, success, error }

class WifiProvider extends ChangeNotifier {
  final WifiRepository _repo;
  WifiProvider(this._repo);

  WifiChangeStep             step          = WifiChangeStep.idle;
  String                     statusMessage = '';
  ViewState<List<String>>    networksState = const IdleState();
  ViewState<void>            changeState   = const IdleState();

  List<String> get networks =>
      networksState is SuccessState<List<String>>
          ? (networksState as SuccessState<List<String>>).data
          : [];

  // ── Scan available networks ────────────────────────────────────────────────

  Future<void> loadNetworks() async {
    networksState = const LoadingState();
    step = WifiChangeStep.scanning;
    notifyListeners();
    try {
      final list = await _repo.getAvailableNetworks();
      networksState = SuccessState(list);
      step = WifiChangeStep.selecting;
    } catch (e) {
      networksState = ErrorState(e.toString());
      step = WifiChangeStep.error;
      statusMessage = e.toString();
    }
    notifyListeners();
  }

  // ── Change WiFi ────────────────────────────────────────────────────────────

  Future<void> changeWifi({
    required String token,
    required String ssid,
    required String password,
    required String mqttPasscode,
    required String groupId,
  }) async {
    changeState = const LoadingState();
    step = WifiChangeStep.connecting;
    statusMessage = 'Disconnecting previous network…';
    notifyListeners();

    try {
      await _repo.disconnectCurrent(token);
      log('✅ /DISCONNECT done');

      statusMessage = 'Setting server…';
      notifyListeners();
      final serverResult = await _repo.setServer(token);
      if (serverResult['status'] != 'success') {
        throw Exception('/SERVER failed: ${serverResult['status']}');
      }

      statusMessage = 'Sending Wi-Fi credentials…';
      notifyListeners();
      final result = await _repo.changeWifi(
        token:        token,
        ssid:         ssid,
        password:     password,
        mqttPasscode: mqttPasscode,
        groupId:      groupId,
      );

      final wifiStatus = result['wifi_status'] as String? ?? 'unknown';
      if (wifiStatus == 'success') {
        changeState = const SuccessState(null);
        step = WifiChangeStep.success;
      } else {
        throw Exception('WiFi failed: wifi=${result['wifi_status']} mqtt=${result['mqtt_status']}');
      }
    } catch (e) {
      changeState = ErrorState(e.toString());
      step = WifiChangeStep.error;
      statusMessage = e.toString();
    }
    notifyListeners();
  }

  void reset() {
    step = WifiChangeStep.idle;
    statusMessage = '';
    networksState = const IdleState();
    changeState = const IdleState();
    notifyListeners();
  }
}