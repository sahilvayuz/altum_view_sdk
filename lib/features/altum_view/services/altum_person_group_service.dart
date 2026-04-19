// ─────────────────────────────────────────────────────────────────────────────
// altum_person_group_service.dart
//
// What this does (plain English):
//   Person Groups are categories that people belong to — Senior, Staff, Visitor,
//   or Student. The camera uses these groups to apply different detection rules
//   (e.g. restricted regions only alert for specific groups).
//
//   This service lets you:
//     1. List all person groups in the account
//     2. Create a new group (with a name and type)
//     3. Update a group's name or type
//     4. Delete a group
//
//   After you create a group, you can assign people to it using
//   AltumPersonService.createPerson() or updatePerson() with the person_group_id.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;

const String _baseApi = 'https://api.altumview.ca/v1.0';

// ── Person group type enum ────────────────────────────────────────────────────
// Maps to the API integer values: Senior=0, Staff=1, Visitor=2, Student=3

enum PersonGroupType {
  senior(0, 'Senior', '🧓'),
  staff(1, 'Staff', '👷'),
  visitor(2, 'Visitor', '🪪'),
  student(3, 'Student', '🎓');

  final int value;
  final String label;
  final String emoji;

  const PersonGroupType(this.value, this.label, this.emoji);

  static PersonGroupType fromInt(int v) =>
      PersonGroupType.values.firstWhere((e) => e.value == v,
          orElse: () => PersonGroupType.senior);
}

// ── Model ─────────────────────────────────────────────────────────────────────

class AltumPersonGroup {
  final int id;
  final String name;
  final PersonGroupType type;

  const AltumPersonGroup({
    required this.id,
    required this.name,
    required this.type,
  });

  factory AltumPersonGroup.fromJson(Map<String, dynamic> j) => AltumPersonGroup(
    id:   (j['id']   as num).toInt(),
    name: j['name']  as String? ?? 'Unnamed Group',
    type: PersonGroupType.fromInt((j['type'] as num?)?.toInt() ?? 0),
  );

  // Colour used in the UI for each group type
  static const Map<PersonGroupType, int> _groupColours = {
    PersonGroupType.senior:  0xFF4A9EFF, // blue
    PersonGroupType.staff:   0xFF00DC78, // green
    PersonGroupType.visitor: 0xFFFFD700, // gold
    PersonGroupType.student: 0xFFFF6B9D, // pink
  };

  int get uiColour => _groupColours[type] ?? 0xFF4A9EFF;
}

// ── Service ───────────────────────────────────────────────────────────────────

class AltumPersonGroupService {
  final String accessToken;
  AltumPersonGroupService({required this.accessToken});

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $accessToken',
    'Content-Type':  'application/json',
  };

  // ── List all groups ───────────────────────────────────────────────────────

  Future<List<AltumPersonGroup>> getGroups() async {
    final resp = await http.get(
      Uri.parse('$_baseApi/people/groups'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    log('👥 GET /people/groups → ${resp.statusCode}');
    if (resp.statusCode != 200) {
      throw Exception('getGroups failed: ${resp.body}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final raw  = body['data']?['person_groups']?['array'] as List? ?? [];
    return raw.cast<Map<String, dynamic>>().map(AltumPersonGroup.fromJson).toList();
  }

  // ── Create a new group ────────────────────────────────────────────────────
  // Returns the new group's ID.

  Future<int> createGroup({
    required String name,
    PersonGroupType type = PersonGroupType.senior,
  }) async {
    final resp = await http.post(
      Uri.parse('$_baseApi/people/groups'),
      headers: _headers,
      body: jsonEncode({'name': name, 'type': type.value}),
    );
    log('➕ POST /people/groups → ${resp.statusCode}');
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('createGroup failed: ${resp.body}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final id   = (body['data']?['person_group']?['id'] as num?)?.toInt();
    if (id == null) throw Exception('No group ID in response: $body');
    log('✅ Created group id=$id name=$name type=${type.label}');
    return id;
  }

  // ── Update a group ────────────────────────────────────────────────────────

  Future<void> updateGroup({
    required int    id,
    String?         name,
    PersonGroupType? type,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (type != null) payload['type'] = type.value;

    final resp = await http.patch(
      Uri.parse('$_baseApi/people/groups/$id'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    log('✏️ PATCH /people/groups/$id → ${resp.statusCode}');
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('updateGroup failed: ${resp.body}');
    }
  }

  // ── Delete a group ────────────────────────────────────────────────────────

  Future<void> deleteGroup(int id) async {
    final resp = await http.delete(
      Uri.parse('$_baseApi/people/groups/$id'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    log('🗑️ DELETE /people/groups/$id → ${resp.statusCode}');
    if (resp.statusCode != 200) {
      throw Exception('deleteGroup failed: ${resp.body}');
    }
  }
}