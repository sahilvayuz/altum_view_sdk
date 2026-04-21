// ─────────────────────────────────────────────────────────────────────────────
// features/skeleton_stream/domain/models/skeleton_model.dart
// ─────────────────────────────────────────────────────────────────────────────

/// A single body joint received from the camera.
/// x=0 is left in camera space, x=1 is right (horizontally mirrored vs display).
class SkeletonJoint {
  final double x;
  final double y;

  const SkeletonJoint(this.x, this.y);

  /// Flip x for display: camera space → screen space.
  double get displayX => 1.0 - x;

  @override
  String toString() =>
      'Joint(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})';
}

/// One decoded skeleton frame from the MQTT stream.
/// [persons] is a list of people; each person is a list of 18 [SkeletonJoint]s.
class SkeletonFrame {
  final List<List<SkeletonJoint>> persons; // never null — may be empty
  final DateTime                  receivedAt;

  const SkeletonFrame({required this.persons, required this.receivedAt});

  bool get isEmpty => persons.isEmpty;
}

/// MQTT broker credentials fetched from /mqttAccount.
class MqttCredentials {
  final String   username;
  final String   password;
  final String   wssUrl;
  final DateTime expiresAt;

  const MqttCredentials({
    required this.username,
    required this.password,
    required this.wssUrl,
    required this.expiresAt,
  });

  bool get isExpired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 2)));

  factory MqttCredentials.fromJson(Map<String, dynamic> json) {
    final data    = json['data'] as Map<String, dynamic>;
    final account = data['mqtt_account'] as Map<String, dynamic>? ?? data;

    DateTime parseExpiry(dynamic v) {
      if (v is int)    return DateTime.fromMillisecondsSinceEpoch(v * 1000);
      if (v is String) {
        return DateTime.tryParse(v) ??
            DateTime.now().add(const Duration(hours: 1));
      }
      return DateTime.now().add(const Duration(hours: 1));
    }

    final password = account['passcode'] as String?
        ?? account['password'] as String?
        ?? '';
    final wssUrl = data['wss_url']    as String?
        ?? account['wss_url'] as String?
        ?? '';

    return MqttCredentials(
      username:  account['username'] as String? ?? '',
      password:  password,
      wssUrl:    wssUrl,
      expiresAt: parseExpiry(account['expires_at']),
    );
  }
}