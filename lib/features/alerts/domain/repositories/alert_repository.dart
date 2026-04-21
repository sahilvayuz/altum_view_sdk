// ─────────────────────────────────────────────────────────────────────────────
// features/alerts/domain/repositories/alert_repository.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/features/alerts/domain/models/alert_model.dart';

abstract interface class AlertRepository {
  Future<List<AlertModel>> getAlerts({
    bool      unresolvedOnly,
    bool      resolvedOnly,
    bool      trueAlertsOnly,
    bool      falseAlertsOnly,
    List<int> eventTypes,
    int       pageLength,
  });
  Future<AlertDetailModel> getAlertById(String alertId);
  Future<void> resolveAlert({
    required String alertId,
    bool    isTrueAlert,
    bool    isFalseAlert,
    String? comment,
  });
  Future<void> resolveAllAlerts();
}