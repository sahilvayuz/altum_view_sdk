// ─────────────────────────────────────────────────────────────────────────────
// features/alerts/data/sources/alert_remote_data_source.dart
//
// All raw HTTP calls for the Alerts feature.
// Extracted 1-for-1 from AltumAlertService in altum_alert_service.dart.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';
import 'package:altum_view_sdk/core/networking/api_constant.dart';
import 'package:altum_view_sdk/core/networking/dio_client.dart';
import 'package:altum_view_sdk/features/alerts/domain/models/alert_model.dart';


abstract interface class AlertRemoteDataSource {
  Future<List<AlertModel>> getAlerts({
    bool      unresolvedOnly,
    bool      resolvedOnly,
    bool      trueAlertsOnly,
    bool      falseAlertsOnly,
    List<int> eventTypes,
    int       pageLength,
  });
  Future<AlertDetailModel> getAlertById(String alertId);
  Future<void>             resolveAlert({
    required String alertId,
    bool    isTrueAlert,
    bool    isFalseAlert,
    String? comment,
  });
  Future<void> resolveAllAlerts();
}

class AlertRemoteDataSourceImpl implements AlertRemoteDataSource {
  final DioClient _client;
  AlertRemoteDataSourceImpl(this._client);

  // ── GET /alerts ───────────────────────────────────────────────────────────

  @override
  Future<List<AlertModel>> getAlerts({
    bool      unresolvedOnly  = false,
    bool      resolvedOnly    = false,
    bool      trueAlertsOnly  = false,
    bool      falseAlertsOnly = false,
    List<int> eventTypes      = AltumEventType.all,
    int       pageLength      = 50,
  }) async {
    // Build query manually for repeated event_types[] params
    final params = <String>[
      'page_length=$pageLength',
      'direction=DESC',
    ];

    if (unresolvedOnly) {
      params.add('show_unresolved=true');
    } else if (resolvedOnly) {
      params.add('show_resolved=true');
    } else if (trueAlertsOnly) {
      params.add('show_true_alerts=true');
    } else if (falseAlertsOnly) {
      params.add('show_false_alerts=true');
    } else {
      params.add('show_unresolved=true');
      params.add('show_resolved=true');
    }

    for (final et in eventTypes) {
      params.add('event_types%5B%5D=$et');
    }

    final resp = await _client.get(
      '${ApiConstants.alerts}?${params.join('&')}',
    );

    log('📋 /alerts → ${resp.statusCode}');
    final data = resp.data['data'] as Map<String, dynamic>?;
    if (data == null) return [];

    final alertsWrapper = data['alerts'] as Map<String, dynamic>?;
    if (alertsWrapper == null) return [];

    final array      = alertsWrapper['array']        as List? ?? [];
    final unresolved = (data['unresolved_count']     as num?)?.toInt() ?? 0;
    final total      = (alertsWrapper['total_count'] as num?)?.toInt() ?? 0;
    final hasNext    = (alertsWrapper['has_next_page'] as bool?) ?? false;

    log('📋 total=$total unresolved=$unresolved hasNext=$hasNext returned=${array.length}');

    return array
        .cast<Map<String, dynamic>>()
        .map((j) => AlertModel.fromJson(j, unresolved))
        .toList();
  }

  // ── GET /alerts/:id ───────────────────────────────────────────────────────

  @override
  Future<AlertDetailModel> getAlertById(String alertId) async {
    final resp     = await _client.get(ApiConstants.alertById(alertId));
    final dataNode = resp.data['data'] as Map<String, dynamic>?;
    if (dataNode == null) throw Exception('data missing in response');
    return AlertDetailModel.fromDataJson(dataNode);
  }

  // ── PATCH /alerts/:id ─────────────────────────────────────────────────────

  @override
  Future<void> resolveAlert({
    required String alertId,
    bool    isTrueAlert  = false,
    bool    isFalseAlert = false,
    String? comment,
  }) async {
    assert(
    !(isTrueAlert && isFalseAlert),
    'Cannot set both isTrueAlert and isFalseAlert',
    );
    final body = <String, dynamic>{};
    if (isTrueAlert)  body['is_true_alert']  = true;
    if (isFalseAlert) body['is_false_alert'] = true;
    if (comment != null && comment.isNotEmpty) body['comment'] = comment;

    await _client.patch(ApiConstants.alertById(alertId), data: body);
    log('✅ Alert $alertId resolved');
  }

  // ── PATCH /alerts/all ─────────────────────────────────────────────────────

  @override
  Future<void> resolveAllAlerts() async {
    await _client.patch(ApiConstants.resolveAll);
    log('✅ All alerts resolved');
  }
}