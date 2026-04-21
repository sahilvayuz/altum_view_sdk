// ─────────────────────────────────────────────────────────────────────────────
// features/alerts/data/repositories/alert_repository_impl.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/networking/app_exception.dart';
import 'package:altum_view_sdk/features/alerts/data/data_source/alert_remote_data_source.dart';
import 'package:altum_view_sdk/features/alerts/domain/models/alert_model.dart';
import 'package:dio/dio.dart';
import '../../domain/repositories/alert_repository.dart';

class AlertRepositoryImpl implements AlertRepository {
  final AlertRemoteDataSource _source;
  AlertRepositoryImpl(this._source);

  @override
  Future<List<AlertModel>> getAlerts({
    bool      unresolvedOnly  = false,
    bool      resolvedOnly    = false,
    bool      trueAlertsOnly  = false,
    bool      falseAlertsOnly = false,
    List<int> eventTypes      = AltumEventType.all,
    int       pageLength      = 50,
  }) =>
      _safe(() => _source.getAlerts(
        unresolvedOnly:  unresolvedOnly,
        resolvedOnly:    resolvedOnly,
        trueAlertsOnly:  trueAlertsOnly,
        falseAlertsOnly: falseAlertsOnly,
        eventTypes:      eventTypes,
        pageLength:      pageLength,
      ));

  @override
  Future<AlertDetailModel> getAlertById(String alertId) =>
      _safe(() => _source.getAlertById(alertId));

  @override
  Future<void> resolveAlert({
    required String alertId,
    bool    isTrueAlert  = false,
    bool    isFalseAlert = false,
    String? comment,
  }) =>
      _safe(() => _source.resolveAlert(
        alertId:     alertId,
        isTrueAlert: isTrueAlert,
        isFalseAlert: isFalseAlert,
        comment:     comment,
      ));

  @override
  Future<void> resolveAllAlerts() => _safe(_source.resolveAllAlerts);

  Future<T> _safe<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : ApiException(e.message ?? 'Unknown error');
    }
  }
}