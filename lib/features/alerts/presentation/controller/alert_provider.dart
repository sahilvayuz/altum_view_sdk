// ─────────────────────────────────────────────────────────────────────────────
// features/alerts/presentation/providers/alert_provider.dart
//
// Manages alert list state, polling, and resolve actions.
// Mirrors AltumAlertService polling logic — extracted into Provider layer.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:developer';

import 'package:altum_view_sdk/core/state/view_state.dart';
import 'package:altum_view_sdk/features/alerts/domain/models/alert_model.dart';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/alert_repository.dart';

class AlertProvider extends ChangeNotifier {
  final AlertRepository _repo;
  AlertProvider(this._repo);

  // ── State ──────────────────────────────────────────────────────────────────
  ViewState<List<AlertModel>>  alertsState  = const IdleState();
  ViewState<AlertDetailModel>  detailState  = const IdleState();
  ViewState<void>              resolveState = const IdleState();

  List<AlertModel> get alerts =>
      alertsState is SuccessState<List<AlertModel>>
          ? (alertsState as SuccessState<List<AlertModel>>).data
          : [];

  int get unresolvedCount =>
      alerts.isEmpty ? 0 : alerts.first.unresolvedCount;

  // ── Polling ────────────────────────────────────────────────────────────────
  Timer?            _pollTimer;
  final Set<String> _seenIds = {};
  final _newAlertCtrl = StreamController<AlertModel>.broadcast();
  Stream<AlertModel> get onNewAlert => _newAlertCtrl.stream;

  void startPolling() {
    log('🔔 AlertProvider: starting poll every 30 s');
    _pollOnce();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollOnce());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollOnce() async {
    try {
      final fresh = await _repo.getAlerts(unresolvedOnly: true);
      for (final alert in fresh) {
        if (!_seenIds.contains(alert.id)) {
          _seenIds.add(alert.id);
          if (!_newAlertCtrl.isClosed) {
            _newAlertCtrl.add(alert);
            log('🆕 New alert: ${alert.eventLabel} — ${alert.personName}');
          }
        }
      }
    } catch (e) {
      log('⚠️ AlertProvider poll error: $e');
    }
  }

  // ── Load alerts ────────────────────────────────────────────────────────────

  Future<void> loadAlerts({
    bool      unresolvedOnly  = false,
    bool      resolvedOnly    = false,
    List<int> eventTypes      = AltumEventType.all,
  }) async {
    alertsState = const LoadingState();
    notifyListeners();
    try {
      final data = await _repo.getAlerts(
        unresolvedOnly: unresolvedOnly,
        resolvedOnly:   resolvedOnly,
        eventTypes:     eventTypes,
      );
      alertsState = SuccessState(data);
    } catch (e) {
      alertsState = ErrorState(e.toString());
    }
    notifyListeners();
  }

  // ── Load alert detail ──────────────────────────────────────────────────────

  Future<void> loadAlertDetail(String alertId) async {
    detailState = const LoadingState();
    notifyListeners();
    try {
      final detail = await _repo.getAlertById(alertId);
      detailState = SuccessState(detail);
    } catch (e) {
      detailState = ErrorState(e.toString());
    }
    notifyListeners();
  }

  // ── Resolve single ─────────────────────────────────────────────────────────

  Future<void> resolveAlert({
    required String alertId,
    bool    isTrueAlert  = false,
    bool    isFalseAlert = false,
    String? comment,
  }) async {
    resolveState = const LoadingState();
    notifyListeners();
    try {
      await _repo.resolveAlert(
        alertId:     alertId,
        isTrueAlert: isTrueAlert,
        isFalseAlert: isFalseAlert,
        comment:     comment,
      );
      resolveState = const SuccessState(null);
      await loadAlerts(); // refresh list
    } catch (e) {
      resolveState = ErrorState(e.toString());
      notifyListeners();
    }
  }

  // ── Resolve all ────────────────────────────────────────────────────────────

  Future<void> resolveAllAlerts() async {
    resolveState = const LoadingState();
    notifyListeners();
    try {
      await _repo.resolveAllAlerts();
      resolveState = const SuccessState(null);
      await loadAlerts();
    } catch (e) {
      resolveState = ErrorState(e.toString());
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopPolling();
    if (!_newAlertCtrl.isClosed) _newAlertCtrl.close();
    super.dispose();
  }
}