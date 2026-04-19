// ─────────────────────────────────────────────────────────────────────────────
// altum_alert_service.dart  —  FULLY CORRECTED VERSION
//
// BUGS FIXED vs previous version:
//
//  BUG 1: data['alerts'] parsed directly as List
//         FIX: API returns data.alerts.array (paginated wrapper)
//              Correct path: body['data']['alerts']['array']
//
//  BUG 2: Query param 'limit' used
//         FIX: API uses 'page_length'
//
//  BUG 3: Timestamp read from 'time_stamp'/'timestamp' fields
//         FIX: API returns 'time' (ISO 8601) and 'unix_time' (epoch int)
//
//  BUG 4: actionType read from 'action_type' string
//         FIX: API returns 'event_type' as INTEGER (1=Fall, 2=Restricted etc.)
//
//  BUG 5: AltumAlertDetail parsed wrong — is_call_available inside alert
//         FIX: is_call_available is a SIBLING of alert at data level
//              Structure: data.alert + data.is_call_available + data.nearby_available_camera
//
//  BUG 6: No resolveAll support
//         FIX: Added resolveAllAlerts() — PATCH /alerts/all
//
//  BUG 7: No support for all alert event types (only fall was fetched)
//         FIX: Parameterized eventTypes with defaults matching official app
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

const String _baseApi = 'https://api.altumview.ca/v1.0';

// ═════════════════════════════════════════════════════════════════════════════
// ALERT EVENT TYPES — from AltumView API docs
// ═════════════════════════════════════════════════════════════════════════════

class AltumEventType {
  static const int fall       = 1;
  static const int restricted = 2;
  static const int fight      = 3;
  static const int fire       = 4;
  static const int handWave   = 5;
  static const int overstay   = 10;
  static const int absence    = 11;

  static String toLabel(int eventType) {
    switch (eventType) {
      case fall:       return 'Fall';
      case restricted: return 'Restricted';
      case fight:      return 'Fight';
      case fire:       return 'Fire';
      case handWave:   return 'Help';
      case overstay:   return 'Overstayed';
      case absence:    return 'Absent';
      default:         return 'Event $eventType';
    }
  }

  static const List<int> all     = [1, 2, 3, 4, 5, 10, 11];
  static const List<int> fallOnly = [1];
}

// ═════════════════════════════════════════════════════════════════════════════
// MODELS
// ═════════════════════════════════════════════════════════════════════════════

class AltumAlert {
  final String   id;
  final String   personName;
  final int      personId;       // -3 = unidentified
  final int      eventType;      // raw integer
  final String   eventLabel;     // "Fall", "Restricted", etc.
  final String   cameraName;
  final int      cameraId;
  final String   roomName;
  final int      roomId;         // -3 = no permission
  final DateTime timestamp;
  final int      unixTime;
  final bool     isResolved;
  final bool     isTrueAlert;
  final bool     isFalseAlert;
  final String?  resolvedBy;
  final int      unresolvedCount;

  const AltumAlert({
    required this.id,
    required this.personName,
    required this.personId,
    required this.eventType,
    required this.eventLabel,
    required this.cameraName,
    required this.cameraId,
    required this.roomName,
    required this.roomId,
    required this.timestamp,
    required this.unixTime,
    required this.isResolved,
    required this.isTrueAlert,
    required this.isFalseAlert,
    this.resolvedBy,
    required this.unresolvedCount,
  });

  factory AltumAlert.fromJson(Map<String, dynamic> j, int unresolvedCount) {
    // Timestamp: API returns 'time' as ISO string "2020-03-16T21:18:43.000Z"
    DateTime ts = DateTime.now();
    final rawTime = j['time'] as String?;
    if (rawTime != null && rawTime.isNotEmpty) {
      ts = DateTime.tryParse(rawTime) ?? ts;
    } else {
      final epoch = (j['unix_time'] as num?)?.toInt();
      if (epoch != null && epoch > 0) {
        ts = DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
      }
    }

    // event_type is an INTEGER in the API, not a string
    final eventType = (j['event_type'] as num?)?.toInt() ?? 0;

    // ID field: 'id' in list, '_id' sometimes in detail
    final id = j['id'] as String? ?? j['_id'] as String? ?? '';

    return AltumAlert(
      id:             id,
      personName:     j['person_name'] as String? ?? 'Unknown',
      personId:       (j['person_id']  as num?)?.toInt() ?? -3,
      eventType:      eventType,
      eventLabel:     AltumEventType.toLabel(eventType),
      cameraName:     j['camera_name'] as String? ?? '',
      cameraId:       (j['camera_id']  as num?)?.toInt() ?? -1,
      roomName:       j['room_name']   as String? ?? '',
      roomId:         (j['room_id']    as num?)?.toInt() ?? -1,
      timestamp:      ts,
      unixTime:       (j['unix_time']  as num?)?.toInt() ?? 0,
      isResolved:     (j['is_resolved']    as bool?) ?? false,
      isTrueAlert:    (j['is_true_alert']  as bool?) ?? false,
      isFalseAlert:   (j['is_false_alert'] as bool?) ?? false,
      resolvedBy:     j['resolved_by'] as String?,
      unresolvedCount: unresolvedCount,
    );
  }

  @override
  String toString() =>
      'AltumAlert(id=$id, event=$eventLabel, person=$personName, resolved=$isResolved)';
}

/// Full detail from GET /alerts/:id
///
/// IMPORTANT — API structure for this endpoint:
/// {
///   "data": {
///     "alert": { ...alert fields + background_url + skeleton_file... },
///     "is_call_available": true,          ← SIBLING of alert, NOT inside it
///     "nearby_available_camera": { ... }  ← SIBLING of alert, NOT inside it
///   }
/// }
class AltumAlertDetail {
  final AltumAlert alert;
  final String?    backgroundUrl;
  final String?    skeletonFileB64;
  final bool       isCallAvailable;
  final String?    sipUsername;

  const AltumAlertDetail({
    required this.alert,
    this.backgroundUrl,
    this.skeletonFileB64,
    this.isCallAvailable = false,
    this.sipUsername,
  });

  /// Pass body['data'] — the entire data node
  factory AltumAlertDetail.fromDataJson(Map<String, dynamic> dataNode) {
    final alertJson = dataNode['alert'] as Map<String, dynamic>? ?? dataNode;
    final alert     = AltumAlert.fromJson(alertJson, 0);

    // nearby_available_camera is at data level (sibling of alert)
    final camera = dataNode['nearby_available_camera'] as Map<String, dynamic>?
        ?? dataNode['camera_to_call'] as Map<String, dynamic>?;

    return AltumAlertDetail(
      alert:           alert,
      backgroundUrl:   alertJson['background_url']  as String?,
      skeletonFileB64: alertJson['skeleton_file']   as String?,
      isCallAvailable: (dataNode['is_call_available'] as bool?) ?? false,
      sipUsername:     camera?['sip_username'] as String?,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SERVICE
// ═════════════════════════════════════════════════════════════════════════════

class AltumAlertService {
  final String accessToken;

  AltumAlertService({required this.accessToken});

  Timer?            _pollTimer;
  final Set<String> _seenIds = {};
  final _newAlertCtrl = StreamController<AltumAlert>.broadcast();

  Stream<AltumAlert> get onNewAlert => _newAlertCtrl.stream;

  // ── Polling ───────────────────────────────────────────────────────────────

  void startPolling() {
    log('🔔 AlertService: starting poll every 30s');
    _pollOnce();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollOnce());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void dispose() {
    stopPolling();
    if (!_newAlertCtrl.isClosed) _newAlertCtrl.close();
  }

  Future<void> _pollOnce() async {
    try {
      final alerts = await getAlerts(unresolvedOnly: true);
      for (final alert in alerts) {
        if (!_seenIds.contains(alert.id)) {
          _seenIds.add(alert.id);
          if (!_newAlertCtrl.isClosed) {
            _newAlertCtrl.add(alert);
            log('🆕 New alert: ${alert.eventLabel} — ${alert.personName}');
          }
        }
      }
    } catch (e) {
      log('⚠️ AlertService poll error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GET /alerts
  //
  // CORRECTED response structure:
  // body['data']['alerts']['array']  ← THE LIST
  // body['data']['unresolved_count'] ← total unresolved count
  // body['data']['alerts']['has_next_page'] ← pagination
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<AltumAlert>> getAlerts({
    bool      unresolvedOnly  = false,
    bool      resolvedOnly    = false,
    bool      trueAlertsOnly  = false,
    bool      falseAlertsOnly = false,
    List<int> eventTypes      = AltumEventType.all,
    int       pageLength      = 50,
  })
  async {
    // Build query string manually for repeated event_types[] params
    final params = <String>[];

    params.add('page_length=$pageLength');
    params.add('direction=DESC');

    if (unresolvedOnly) {
      params.add('show_unresolved=true');
    } else if (resolvedOnly) {
      params.add('show_resolved=true');
    } else if (trueAlertsOnly) {
      params.add('show_true_alerts=true');
    } else if (falseAlertsOnly) {
      params.add('show_false_alerts=true');
    } else {
      // Default: show both so the list page shows everything
      params.add('show_unresolved=true');
      params.add('show_resolved=true');
    }

    for (final et in eventTypes) {
      // API expects: event_types[]=1&event_types[]=2 etc.
      params.add('event_types%5B%5D=$et');
    }

    final uri = Uri.parse('$_baseApi/alerts?${params.join('&')}');
    log('📋 GET $uri');

    final resp = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    log('📋 /alerts → ${resp.statusCode}');
    log('📋 body: ${resp.body}'); // full raw body — check this in console

    if (resp.statusCode != 200) {
      throw Exception('GET /alerts ${resp.statusCode}: ${resp.body}');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      log('⚠️ data is null');
      return [];
    }

    // CORRECTED: alerts is a Map with 'array' inside, NOT a direct List
    final alertsWrapper = data['alerts'] as Map<String, dynamic>?;
    if (alertsWrapper == null) {
      log('⚠️ data.alerts is null — keys: ${data.keys.toList()}');
      return [];
    }

    final array      = alertsWrapper['array']       as List<dynamic>? ?? [];
    final unresolved = (data['unresolved_count']    as num?)?.toInt() ?? 0;
    final total      = (alertsWrapper['total_count'] as num?)?.toInt() ?? 0;
    final hasNext    = (alertsWrapper['has_next_page'] as bool?) ?? false;

    log('📋 total=$total unresolved=$unresolved hasNext=$hasNext returned=${array.length}');

    return array
        .cast<Map<String, dynamic>>()
        .map((j) => AltumAlert.fromJson(j, unresolved))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GET /alerts/:id
  // ═══════════════════════════════════════════════════════════════════════════

  Future<AltumAlertDetail> getAlertById(String alertId) async {
    final resp = await http.get(
      Uri.parse('$_baseApi/alerts/$alertId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    log('🔍 /alerts/$alertId → ${resp.statusCode}');
    log('🔍 body: ${resp.body}');

    if (resp.statusCode != 200) {
      throw Exception('GET /alerts/$alertId ${resp.statusCode}: ${resp.body}');
    }

    final body     = jsonDecode(resp.body) as Map<String, dynamic>;
    final dataNode = body['data'] as Map<String, dynamic>?;
    if (dataNode == null) throw Exception('data missing in response');

    return AltumAlertDetail.fromDataJson(dataNode);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PATCH /alerts/:id — resolve single alert
  //
  // Options (mutually exclusive — pick ONE):
  //   isTrueAlert=true   → real event, caregiver confirmed
  //   isFalseAlert=true  → false alarm, ignore
  //   neither            → just acknowledge/resolve without categorizing
  //
  // comment is always optional
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> resolveAlert({
    required String alertId,
    bool    isTrueAlert  = false,
    bool    isFalseAlert = false,
    String? comment,
  }) async {
    assert(
    !(isTrueAlert && isFalseAlert),
    'Cannot set both isTrueAlert and isFalseAlert — they are mutually exclusive',
    );

    final bodyMap = <String, dynamic>{};
    if (isTrueAlert)  bodyMap['is_true_alert']  = true;
    if (isFalseAlert) bodyMap['is_false_alert'] = true;
    if (comment != null && comment.isNotEmpty) bodyMap['comment'] = comment;

    log('🔔 PATCH /alerts/$alertId  body: ${jsonEncode(bodyMap)}');

    final resp = await http.patch(
      Uri.parse('$_baseApi/alerts/$alertId'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type':  'application/json',
      },
      body: jsonEncode(bodyMap),
    );

    log('✅ PATCH /alerts/$alertId → ${resp.statusCode}  ${resp.body}');

    if (resp.statusCode != 200) {
      throw Exception('resolveAlert ${resp.statusCode}: ${resp.body}');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PATCH /alerts/all — resolve ALL unresolved alerts
  // Matches "Resolve All" button in AltumView official app
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> resolveAllAlerts() async {
    final resp = await http.patch(
      Uri.parse('$_baseApi/alerts/all'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    log('✅ PATCH /alerts/all → ${resp.statusCode}  ${resp.body}');

    if (resp.statusCode != 200) {
      throw Exception('resolveAllAlerts ${resp.statusCode}: ${resp.body}');
    }
  }
}