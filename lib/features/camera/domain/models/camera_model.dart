// ─────────────────────────────────────────────────────────────────────────────
// features/altum_view/data/models/camera_model.dart
//
// The top-level camera object shown on the main dashboard screen.
// ─────────────────────────────────────────────────────────────────────────────

class CameraModel {
  final int     id;
  final String  friendlyName;
  final String  serialNumber;
  final bool    isOnline;
  final bool    isStreaming;
  final int?    roomId;
  final String? roomName;
  final String? firmwareVersion;

  const CameraModel({
    required this.id,
    required this.friendlyName,
    required this.serialNumber,
    required this.isOnline,
    required this.isStreaming,
    this.roomId,
    this.roomName,
    this.firmwareVersion,
  });

  factory CameraModel.fromJson(Map<String, dynamic> j) => CameraModel(
    id:              (j['id']             as num).toInt(),
    friendlyName:     j['friendly_name']  as String? ?? '',
    serialNumber:     j['serial_number']  as String? ?? '',
    isOnline:        (j['is_online']      as bool?) ?? false,
    isStreaming:     (j['is_streaming']   as bool?) ?? false,
    roomId:          (j['room_id']        as num?)?.toInt(),
    roomName:         j['room_name']      as String?,
    firmwareVersion:  j['version']        as String?,
  );
}