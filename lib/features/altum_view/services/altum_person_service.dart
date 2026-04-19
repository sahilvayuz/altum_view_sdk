// ─────────────────────────────────────────────────────────────────────────────
// altum_person_service.dart  (UPDATED)
//
// Changes vs original:
//   1. AltumPerson now exposes `groupId` (int?) and `groupName` (String?)
//      so the management sheet can count people per group.
//   2. Added `assignGroup()` — PATCH /people/:id  { person_group_id }
//      Called after createPerson() if the user selected a group in the form.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

const String _baseApi = 'https://api.altumview.ca/v1.0';

class AltumPerson {
  final int id;
  final String name;
  final bool hasFacePhoto;
  final String? profileImageUrl;
  // ── NEW fields ──────────────────────────────────────────────────
  final int?    groupId;
  final String? groupName;

  const AltumPerson({
    required this.id,
    required this.name,
    required this.hasFacePhoto,
    this.profileImageUrl,
    this.groupId,
    this.groupName,
  });

  factory AltumPerson.fromJson(Map<String, dynamic> j) {
    final faceCount = (j['face_count'] as num?)?.toInt() ?? 0;

    // ── Extract group info if present ────────────────────────────
    final groupMap  = j['person_group'] as Map<String, dynamic>?;

    return AltumPerson(
      id:   (j['id'] as num?)?.toInt() ?? 0,

      name: j['friendly_name'] as String? ??
          j['name']          as String? ??
          'Unknown',

      hasFacePhoto:    faceCount > 0,

      profileImageUrl: (j['profile_face'] as Map<String, dynamic>?)?['url'] as String?,

      // ── NEW ──────────────────────────────────────────────────────
      groupId:   (groupMap?['id']   as num?)?.toInt(),
      groupName:  groupMap?['name'] as String?,
    );
  }
}

class AltumPersonService {
  final String accessToken;
  AltumPersonService({required this.accessToken});

  Map<String, String> get _headers => {'Authorization': 'Bearer $accessToken'};

  // ── List all people ───────────────────────────────────────────────────────

  Future<List<AltumPerson>> getPeople() async {
    final resp = await http.get(
      Uri.parse('$_baseApi/people'),
      headers: _headers,
    );

    log('👥 GET /people → ${resp.statusCode}');
    if (resp.statusCode != 200) throw Exception('GET /people: ${resp.body}');

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final raw  = body['data']?['people']?['array'];

    List<dynamic> list = raw is List ? raw : [];

    return list
        .cast<Map<String, dynamic>>()
        .map(AltumPerson.fromJson)
        .toList();
  }

  // ── Register a new person ─────────────────────────────────────────────────

  Future<int> createPerson(String friendlyName) async {
    final resp = await http.post(
      Uri.parse('$_baseApi/people'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'friendly_name': friendlyName}),
    );
    log('➕ POST /people → ${resp.statusCode}');
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('createPerson failed: ${resp.body}');
    }

    final body   = jsonDecode(resp.body) as Map<String, dynamic>;
    final person = body['data']?['person'] as Map<String, dynamic>?;
    final id     = (person?['id'] as num?)?.toInt();
    if (id == null) throw Exception('No person ID in response: $body');

    log('✅ Created person id=$id name=$friendlyName');
    return id;
  }

  // ── Assign a person to a group  ───────────────────────────────────────────
  // NEW: called from AltumPersonManagementSheet after createPerson()
  // Also called from AltumPersonDetailPage when the user taps the group badge.

  Future<void> assignGroup({
    required int personId,
    required int groupId,
  }) async {
    final resp = await http.patch(
      Uri.parse('$_baseApi/people/$personId'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'person_group_id': groupId}),
    );
    log('🏷️ PATCH /people/$personId (group=$groupId) → ${resp.statusCode}');
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('assignGroup failed: ${resp.body}');
    }
  }

  // ── Upload face photo ─────────────────────────────────────────────────────

  Future<void> uploadFacePhoto({
    required int      personId,
    required Uint8List imageBytes,
    String            filename = 'face.jpg',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseApi/people/$personId/faces'),
    )
      ..headers.addAll(_headers)
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: filename,
      ));

    final streamedResp = await request.send();
    final resp = await http.Response.fromStream(streamedResp);

    log('📷 POST /people/$personId/faces → ${resp.statusCode}  ${resp.body}');

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('uploadFacePhoto failed: ${resp.body}');
    }

    log('✅ Face photo uploaded for person $personId');
  }

  // ── Delete a person ───────────────────────────────────────────────────────

  Future<void> deletePerson(int personId) async {
    final resp = await http.delete(
      Uri.parse('$_baseApi/people/$personId'),
      headers: _headers,
    );
    log('🗑️ DELETE /people/$personId → ${resp.statusCode}');
    if (resp.statusCode != 200) {
      throw Exception('deletePerson failed: ${resp.body}');
    }
  }
}