// ─────────────────────────────────────────────────────────────────────────────
// features/people/data/models/person_model.dart
//
// Extracted 1-for-1 from AltumPerson in altum_person_service.dart.
// ─────────────────────────────────────────────────────────────────────────────

class PersonModel {
  final int     id;
  final String  name;
  final bool    hasFacePhoto;
  final String? profileImageUrl;
  final int?    groupId;
  final String? groupName;

  const PersonModel({
    required this.id,
    required this.name,
    required this.hasFacePhoto,
    this.profileImageUrl,
    this.groupId,
    this.groupName,
  });

  factory PersonModel.fromJson(Map<String, dynamic> j) {
    final faceCount = (j['face_count'] as num?)?.toInt() ?? 0;
    final groupMap  = j['person_group'] as Map<String, dynamic>?;

    return PersonModel(
      id:  (j['id'] as num?)?.toInt() ?? 0,
      name: j['friendly_name'] as String?
          ?? j['name']         as String?
          ?? 'Unknown',
      hasFacePhoto:    faceCount > 0,
      profileImageUrl: (j['profile_face'] as Map<String, dynamic>?)?['url'] as String?,
      groupId:   (groupMap?['id']   as num?)?.toInt(),
      groupName:  groupMap?['name'] as String?,
    );
  }
}