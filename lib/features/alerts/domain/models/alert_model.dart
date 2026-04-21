// ─────────────────────────────────────────────────────────────────────────────
// features/alerts/data/models/alert_model.dart
//
// Models extracted 1-for-1 from altum_alert_service.dart.
// ─────────────────────────────────────────────────────────────────────────────

// ── Event type constants ──────────────────────────────────────────────────────

class AltumEventType {
  static const int fall       = 1;
  static const int restricted = 2;
  static const int fight      = 3;
  static const int fire       = 4;
  static const int handWave   = 5;
  static const int overstay   = 10;
  static const int absence    = 11;

  static String toLabel(int eventType) => switch (eventType) {
    fall       => 'Fall',
    restricted => 'Restricted',
    fight      => 'Fight',
    fire       => 'Fire',
    handWave   => 'Help',
    overstay   => 'Overstayed',
    absence    => 'Absent',
    _          => 'Event $eventType',
  };

  static const List<int> all      = [1, 2, 3, 4, 5, 10, 11];
  static const List<int> fallOnly = [1];
}

// ── Alert list item ───────────────────────────────────────────────────────────

class AlertModel {
  final String   id;
  final String   personName;
  final int      personId;
  final int      eventType;
  final String   eventLabel;
  final String   cameraName;
  final int      cameraId;
  final String   roomName;
  final int      roomId;
  final DateTime timestamp;
  final int      unixTime;
  final bool     isResolved;
  final bool     isTrueAlert;
  final bool     isFalseAlert;
  final String?  resolvedBy;
  final int      unresolvedCount;

  const AlertModel({
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

  factory AlertModel.fromJson(Map<String, dynamic> j, int unresolvedCount) {
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

    final eventType = (j['event_type'] as num?)?.toInt() ?? 0;
    final id        = j['id'] as String? ?? j['_id'] as String? ?? '';

    return AlertModel(
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
      isResolved:     (j['is_resolved']   as bool?) ?? false,
      isTrueAlert:    (j['is_true_alert'] as bool?) ?? false,
      isFalseAlert:   (j['is_false_alert'] as bool?) ?? false,
      resolvedBy:     j['resolved_by'] as String?,
      unresolvedCount: unresolvedCount,
    );
  }
}

// ── Alert detail ──────────────────────────────────────────────────────────────

class AlertDetailModel {
  final AlertModel alert;
  final String?    backgroundUrl;
  final String?    skeletonFileB64;
  final bool       isCallAvailable;
  final String?    sipUsername;

  const AlertDetailModel({
    required this.alert,
    this.backgroundUrl,
    this.skeletonFileB64,
    this.isCallAvailable = false,
    this.sipUsername,
  });

  /// [dataNode] = body['data'] — the entire data node from GET /alerts/:id
  factory AlertDetailModel.fromDataJson(Map<String, dynamic> dataNode) {
    final alertJson = dataNode['alert'] as Map<String, dynamic>? ?? dataNode;
    final alert     = AlertModel.fromJson(alertJson, 0);

    final camera = dataNode['nearby_available_camera'] as Map<String, dynamic>?
        ?? dataNode['camera_to_call']             as Map<String, dynamic>?;

    return AlertDetailModel(
      alert:           alert,
      backgroundUrl:   alertJson['background_url'] as String?,
      skeletonFileB64: alertJson['skeleton_file']  as String?,
      isCallAvailable: (dataNode['is_call_available'] as bool?) ?? false,
      sipUsername:     camera?['sip_username']        as String?,
    );
  }
}