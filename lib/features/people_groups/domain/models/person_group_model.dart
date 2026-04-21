// ─────────────────────────────────────────────────────────────────────────────
// features/people_groups/data/models/person_group_model.dart
//
// Extracted 1-for-1 from altum_person_group_service.dart.
// ─────────────────────────────────────────────────────────────────────────────

// ── Group type enum ───────────────────────────────────────────────────────────

enum PersonGroupType {
  senior(0,  'Senior',  '🧓'),
  staff(1,   'Staff',   '👷'),
  visitor(2, 'Visitor', '🪪'),
  student(3, 'Student', '🎓');

  final int    value;
  final String label;
  final String emoji;

  const PersonGroupType(this.value, this.label, this.emoji);

  static PersonGroupType fromInt(int v) =>
      PersonGroupType.values.firstWhere(
            (e) => e.value == v,
        orElse: () => PersonGroupType.senior,
      );
}

// ── Model ─────────────────────────────────────────────────────────────────────

class PersonGroupModel {
  final int             id;
  final String          name;
  final PersonGroupType type;

  const PersonGroupModel({
    required this.id,
    required this.name,
    required this.type,
  });

  factory PersonGroupModel.fromJson(Map<String, dynamic> j) => PersonGroupModel(
    id:   (j['id']   as num).toInt(),
    name: j['name']  as String? ?? 'Unnamed Group',
    type: PersonGroupType.fromInt((j['type'] as num?)?.toInt() ?? 0),
  );

  // UI colour for each group type (matches original service)
  static const Map<PersonGroupType, int> _groupColours = {
    PersonGroupType.senior:  0xFF4A9EFF, // blue
    PersonGroupType.staff:   0xFF00DC78, // green
    PersonGroupType.visitor: 0xFFFFD700, // gold
    PersonGroupType.student: 0xFFFF6B9D, // pink
  };

  int get uiColour => _groupColours[type] ?? 0xFF4A9EFF;
}