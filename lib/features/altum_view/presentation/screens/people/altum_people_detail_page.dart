// ─────────────────────────────────────────────────────────────────────────────
// altum_person_detail_page.dart
//
// Full-screen person detail page.
// Shows:
//   • Profile photo + basic info (name, DOB, gender, phone)
//   • Person group badge with ability to change group
//   • Face photos gallery with add/delete
//   • Health info (height, weight, blood type, allergies, conditions, notes)
//   • Emergency contacts
//   • Gait analysis history (read-only list)
//
// HOW TO OPEN:
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => AltumPersonDetailPage(
//       accessToken: myToken,
//       personId:    42,
//     ),
//   ));
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:altum_view_sdk/features/altum_view/services/altum_person_group_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

const String _base = 'https://api.altumview.ca/v1.0';

// ── Tiny models for what the detail endpoint returns ─────────────────────────

class _PersonDetail {
  final int    id;
  final String name;
  final String? phone;
  final String? birthDate;
  final int     gender;        // 0=Other 1=Male 2=Female
  final String? address;
  final String? country;
  final AltumPersonGroup? group;
  final _HealthInfo?   healthInfo;
  final List<_EmContact> emergencyContacts;
  final List<_GaitEntry>  gaitAnalysis;
  final List<_FaceImage>  faces;

  _PersonDetail({
    required this.id,
    required this.name,
    this.phone,
    this.birthDate,
    this.gender = 0,
    this.address,
    this.country,
    this.group,
    this.healthInfo,
    this.emergencyContacts = const [],
    this.gaitAnalysis = const [],
    this.faces = const [],
  });
}

class _HealthInfo {
  final num?   height;    // cm
  final num?   weight;    // grams → we display as kg
  final String? bloodType;
  final String? allergies;
  final String? notes;

  _HealthInfo({this.height, this.weight, this.bloodType, this.allergies, this.notes});
}

class _EmContact {
  final int    id;
  final String name;
  final String? relation;
  final String? phone;
  _EmContact({required this.id, required this.name, this.relation, this.phone});
}

class _GaitEntry {
  final double? speed;
  final double? duration;
  final int?    totalScore;
  final int     time;
  _GaitEntry({this.speed, this.duration, this.totalScore, required this.time});
}

class _FaceImage {
  final int    id;
  final String url;
  final bool   isValid;
  _FaceImage({required this.id, required this.url, required this.isValid});
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN PAGE
// ─────────────────────────────────────────────────────────────────────────────

class AltumPersonDetailPage extends StatefulWidget {
  final String accessToken;
  final int    personId;

  const AltumPersonDetailPage({
    super.key,
    required this.accessToken,
    required this.personId,
  });

  @override
  State<AltumPersonDetailPage> createState() => _AltumPersonDetailPageState();
}

class _AltumPersonDetailPageState extends State<AltumPersonDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  _PersonDetail? _person;
  List<AltumPersonGroup> _allGroups = [];
  bool   _loading = true;
  String? _error;

  // Edit name state
  bool   _editingName = false;
  final  _nameCtrl = TextEditingController();

  // Face upload state
  bool _uploadingFace = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _fetchPersonDetail(),
        _fetchFaces(),
        AltumPersonGroupService(accessToken: widget.accessToken).getGroups(),
      ]);
      final detail = results[0] as _PersonDetail;
      final faces  = results[1] as List<_FaceImage>;
      final groups = results[2] as List<AltumPersonGroup>;

      final merged = _PersonDetail(
        id:                 detail.id,
        name:               detail.name,
        phone:              detail.phone,
        birthDate:          detail.birthDate,
        gender:             detail.gender,
        address:            detail.address,
        country:            detail.country,
        group:              detail.group,
        healthInfo:         detail.healthInfo,
        emergencyContacts:  detail.emergencyContacts,
        gaitAnalysis:       detail.gaitAnalysis,
        faces:              faces,
      );

      if (mounted) setState(() {
        _person    = merged;
        _allGroups = groups;
        _loading   = false;
        _nameCtrl.text = merged.name;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<_PersonDetail> _fetchPersonDetail() async {
    final resp = await http.get(
      Uri.parse('$_base/people/${widget.personId}'
          '?attributes[]=health_info&attributes[]=emergency_contact'),
      headers: {'Authorization': 'Bearer ${widget.accessToken}'},
    );
    log('👤 GET /people/${widget.personId} → ${resp.statusCode}');
    if (resp.statusCode != 200) throw Exception('Load person failed: ${resp.body}');

    final j = (jsonDecode(resp.body) as Map)['data']?['person'] as Map<String, dynamic>? ?? {};

    // Health info
    _HealthInfo? hi;
    final raw = j['health_info'] as Map<String, dynamic>?;
    if (raw != null) {
      hi = _HealthInfo(
        height:    raw['height'] as num?,
        weight:    raw['weight'] as num?,  // grams
        bloodType: raw['blood_type'] as String?,
        allergies: raw['allergies'] as String?,
        notes:     raw['notes'] as String?,
      );
    }

    // Emergency contacts
    final ecRaw = (j['emergency_contacts']?['array'] as List?) ?? [];
    final ecs   = ecRaw.cast<Map<String, dynamic>>().map((e) => _EmContact(
      id:       (e['id'] as num).toInt(),
      name:     e['name'] as String? ?? '',
      relation: e['relation'] as String?,
      phone:    e['phone'] as String?,
    )).toList();

    // Gait
    final gaitRaw = (j['gait_analysis'] as List?) ?? [];
    final gaits   = gaitRaw.cast<Map<String, dynamic>>().map((g) => _GaitEntry(
      speed:      (g['speed'] as num?)?.toDouble(),
      duration:   (g['duration'] as num?)?.toDouble(),
      totalScore: (g['total_score'] as num?)?.toInt(),
      time:       (g['time'] as num?)?.toInt() ?? 0,
    )).toList();

    // Group
    final gMap = j['person_group'] as Map<String, dynamic>?;
    AltumPersonGroup? group;
    if (gMap != null) group = AltumPersonGroup.fromJson(gMap);

    return _PersonDetail(
      id:                j['id'] != null ? (j['id'] as num).toInt() : widget.personId,
      name:              j['friendly_name'] as String? ?? 'Unknown',
      phone:             j['phone'] as String?,
      birthDate:         j['birth_date'] as String?,
      gender:            (j['gender'] as num?)?.toInt() ?? 0,
      address:           j['address'] as String?,
      country:           j['country'] as String?,
      group:             group,
      healthInfo:        hi,
      emergencyContacts: ecs,
      gaitAnalysis:      gaits,
    );
  }

  Future<List<_FaceImage>> _fetchFaces() async {
    final resp = await http.get(
      Uri.parse('$_base/people/${widget.personId}/faces'),
      headers: {'Authorization': 'Bearer ${widget.accessToken}'},
    );
    if (resp.statusCode != 200) return [];
    final arr = (jsonDecode(resp.body) as Map)['data']?['person']?['faces']?['array'] as List? ?? [];
    return arr.cast<Map<String, dynamic>>().map((f) => _FaceImage(
      id:      (f['id'] as num).toInt(),
      url:     f['url'] as String? ?? '',
      isValid: (f['is_valid_face'] as num?)?.toInt() == 1,
    )).toList();
  }

  // ── API mutations ─────────────────────────────────────────────────────────

  Future<void> _saveName(String newName) async {
    if (newName.trim().isEmpty) return;
    try {
      final resp = await http.patch(
        Uri.parse('$_base/people/${widget.personId}'),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'friendly_name': newName.trim()}),
      );
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        setState(() {
          _person = _rebuildWith(name: newName.trim());
          _editingName = false;
        });
        _showSnack('Name updated ✓', isError: false);
      } else {
        _showSnack('Failed to update name', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _assignGroup(AltumPersonGroup group) async {
    try {
      final resp = await http.patch(
        Uri.parse('$_base/people/${widget.personId}'),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'person_group_id': group.id}),
      );
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        setState(() => _person = _rebuildWith(group: group));
        _showSnack('Assigned to ${group.name} ✓', isError: false);
      } else {
        _showSnack('Failed to assign group', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _uploadFace() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 800,
    );
    if (picked == null) return;

    setState(() => _uploadingFace = true);
    try {
      final bytes = await picked.readAsBytes();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_base/people/${widget.personId}/faces'),
      )
        ..headers['Authorization'] = 'Bearer ${widget.accessToken}'
        ..files.add(http.MultipartFile.fromBytes(
          'image', bytes,
          filename: '${_person?.name ?? 'face'}.jpg',
        ));
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        _showSnack('Face photo uploaded ✓', isError: false);
        final newFaces = await _fetchFaces();
        setState(() => _person = _rebuildWith(faces: newFaces));
      } else {
        _showSnack('Upload failed', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingFace = false);
    }
  }

  Future<void> _deleteFace(int faceId) async {
    final ok = await _confirmDialog('Delete this photo?',
        'This face image will be removed. The camera will rely on remaining photos.');
    if (!ok) return;
    try {
      final resp = await http.delete(
        Uri.parse('$_base/people/${widget.personId}/faces/$faceId'),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );
      if (resp.statusCode == 200) {
        _showSnack('Photo deleted ✓', isError: false);
        final newFaces = await _fetchFaces();
        setState(() => _person = _rebuildWith(faces: newFaces));
      } else {
        _showSnack('Delete failed', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _saveHealthInfo({
    num? height, num? weight, String? bloodType,
    String? allergies, String? notes,
  }) async {
    final payload = <String, dynamic>{};
    if (height    != null) payload['height']     = height;
    if (weight    != null) payload['weight']     = (weight * 1000).round(); // kg→grams
    if (bloodType != null) payload['blood_type'] = bloodType;
    if (allergies != null) payload['allergies']  = allergies;
    if (notes     != null) payload['notes']      = notes;

    try {
      final resp = await http.patch(
        Uri.parse('$_base/people/${widget.personId}/healthInfo'),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        _showSnack('Health info saved ✓', isError: false);
        _loadAll();
      } else {
        _showSnack('Save failed', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _addEmergencyContact() async {
    String name = '', relation = '', phone = '';
    await showDialog(
      context: context,
      builder: (_) => _inputDialog(
        title: 'Add Emergency Contact',
        fields: [
          _Field('Name', (v) => name = v),
          _Field('Relation (e.g. Son, Wife)', (v) => relation = v),
          _Field('Phone (e.g. 16042488428)', (v) => phone = v),
        ],
        onSave: () async {
          if (name.isEmpty) return;
          final resp = await http.post(
            Uri.parse('$_base/people/${widget.personId}/emergencyContact'),
            headers: {
              'Authorization': 'Bearer ${widget.accessToken}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'name': name, 'relation': relation, 'phone': phone}),
          );
          if (resp.statusCode == 200 || resp.statusCode == 201) {
            _showSnack('Contact added ✓', isError: false);
            _loadAll();
          } else {
            _showSnack('Failed to add contact', isError: true);
          }
        },
      ),
    );
  }

  Future<void> _deleteEmContact(int contactId) async {
    final ok = await _confirmDialog('Remove this contact?', 'This cannot be undone.');
    if (!ok) return;
    try {
      final resp = await http.delete(
        Uri.parse('$_base/people/${widget.personId}/emergencyContact/$contactId'),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );
      if (resp.statusCode == 200) {
        _showSnack('Contact removed ✓', isError: false);
        _loadAll();
      } else {
        _showSnack('Delete failed', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  _PersonDetail _rebuildWith({
    String? name,
    AltumPersonGroup? group,
    List<_FaceImage>? faces,
  }) {
    final p = _person!;
    return _PersonDetail(
      id: p.id, phone: p.phone, birthDate: p.birthDate,
      gender: p.gender, address: p.address, country: p.country,
      healthInfo: p.healthInfo, emergencyContacts: p.emergencyContacts,
      gaitAnalysis: p.gaitAnalysis,
      name:  name  ?? p.name,
      group: group ?? p.group,
      faces: faces ?? p.faces,
    );
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFFF4040) : const Color(0xFF00DC78),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<bool> _confirmDialog(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF08141F),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(body, style: const TextStyle(color: Color(0xFF4A7FA8))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF4A7FA8)))),
            TextButton(onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm', style: TextStyle(color: Color(0xFFFF4040)))),
          ],
        ),
      ) ?? false;

  Widget _inputDialog({
    required String title,
    required List<_Field> fields,
    required Future<void> Function() onSave,
  }) {
    return AlertDialog(
      backgroundColor: const Color(0xFF08141F),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: fields.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: f.label,
              labelStyle: const TextStyle(color: Color(0xFF4A7FA8), fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF0F2030),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1A3A5C))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1A3A5C))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF4A9EFF))),
            ),
            onChanged: f.onChanged,
          ),
        )).toList(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF4A7FA8)))),
        TextButton(
          onPressed: () async {
            await onSave();
            if (mounted) Navigator.pop(context);
          },
          child: const Text('Save', style: TextStyle(color: Color(0xFF4A9EFF))),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07101E),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A9EFF)))
          : _error != null
          ? _errorView()
          : _content(),
    );
  }

  Widget _errorView() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: Color(0xFFFF4040), size: 40),
      const SizedBox(height: 12),
      Text(_error!, style: const TextStyle(color: Color(0xFF4A7FA8))),
      const SizedBox(height: 16),
      TextButton(onPressed: _loadAll,
          child: const Text('Retry', style: TextStyle(color: Color(0xFF4A9EFF)))),
    ]),
  );

  Widget _content() {
    final p = _person!;
    return SafeArea(
      child: Column(children: [
        // ── Top bar ─────────────────────────────────────────────────────────
        _topBar(p),

        // ── Tabs ─────────────────────────────────────────────────────────────
        Container(
          color: const Color(0xFF08141F),
          child: TabBar(
            controller: _tabs,
            labelColor: const Color(0xFF4A9EFF),
            unselectedLabelColor: const Color(0xFF2A4A6A),
            indicatorColor: const Color(0xFF4A9EFF),
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'PROFILE'),
              Tab(text: 'FACES'),
              Tab(text: 'HEALTH'),
              Tab(text: 'CONTACTS'),
            ],
          ),
        ),

        // ── Tab views ─────────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _profileTab(p),
              _facesTab(p),
              _healthTab(p),
              _contactsTab(p),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Top bar with avatar + name ────────────────────────────────────────────

  Widget _topBar(_PersonDetail p) {
    final profileFace = p.faces.firstWhere(
            (f) => f.isValid, orElse: () => p.faces.isNotEmpty ? p.faces.first : _FaceImage(id: -1, url: '', isValid: false));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF08141F),
        border: Border(bottom: BorderSide(color: Color(0xFF0F2030))),
      ),
      child: Row(children: [
        // Back
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF4A9EFF), size: 18),
        ),
        const SizedBox(width: 14),

        // Avatar
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4A9EFF).withOpacity(0.12),
            border: Border.all(color: const Color(0xFF4A9EFF).withOpacity(0.3)),
          ),
          child: profileFace.url.isNotEmpty
              ? ClipOval(child: Image.network(profileFace.url, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initials(p.name)))
              : _initials(p.name),
        ),
        const SizedBox(width: 14),

        // Name + group badge
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _editingName
                ? Row(children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.bold),
                  decoration: const InputDecoration.collapsed(
                    hintText: 'Enter name',
                    hintStyle: TextStyle(color: Color(0xFF2A4A6A)),
                  ),
                  onSubmitted: _saveName,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _saveName(_nameCtrl.text),
                child: const Icon(Icons.check_rounded,
                    color: Color(0xFF00DC78), size: 18),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _editingName = false),
                child: const Icon(Icons.close_rounded,
                    color: Color(0xFFFF4040), size: 18),
              ),
            ])
                : Row(children: [
              Flexible(child: Text(p.name,
                  style: const TextStyle(color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() { _editingName = true; _nameCtrl.text = p.name; }),
                child: const Icon(Icons.edit_rounded,
                    color: Color(0xFF2A4A6A), size: 14),
              ),
            ]),
            const SizedBox(height: 4),
            if (p.group != null)
              _groupBadge(p.group!)
            else
              GestureDetector(
                onTap: _showGroupPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A4A6A).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2A4A6A).withOpacity(0.4)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, color: Color(0xFF2A4A6A), size: 12),
                    SizedBox(width: 4),
                    Text('Assign group',
                        style: TextStyle(color: Color(0xFF2A4A6A), fontSize: 11)),
                  ]),
                ),
              ),
          ]),
        ),

        // ID chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2030),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('ID ${p.id}',
              style: const TextStyle(color: Color(0xFF2A4A6A), fontSize: 10)),
        ),
      ]),
    );
  }

  Widget _initials(String name) => Center(
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(color: Color(0xFF4A9EFF),
          fontSize: 20, fontWeight: FontWeight.bold),
    ),
  );

  Widget _groupBadge(AltumPersonGroup g) => GestureDetector(
    onTap: _showGroupPicker,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Color(g.uiColour).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(g.uiColour).withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(g.type.emoji, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 4),
        Text(g.name,
            style: TextStyle(color: Color(g.uiColour), fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        Icon(Icons.keyboard_arrow_down_rounded,
            color: Color(g.uiColour), size: 12),
      ]),
    ),
  );

  void _showGroupPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF08141F),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: const Color(0xFF1A3A5C), borderRadius: BorderRadius.circular(2)),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 20, bottom: 12),
          child: Align(alignment: Alignment.centerLeft,
              child: Text('Assign to Group', style: TextStyle(color: Colors.white,
                  fontSize: 14, fontWeight: FontWeight.bold))),
        ),
        if (_allGroups.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No groups yet. Create one in Manage People → Groups tab.',
                style: TextStyle(color: Color(0xFF4A7FA8)), textAlign: TextAlign.center),
          )
        else
          ..._allGroups.map((g) => ListTile(
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Color(g.uiColour).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(g.type.emoji)),
            ),
            title: Text(g.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: Text(g.type.label,
                style: TextStyle(color: Color(g.uiColour), fontSize: 11)),
            trailing: _person?.group?.id == g.id
                ? const Icon(Icons.check_rounded, color: Color(0xFF00DC78))
                : null,
            onTap: () {
              Navigator.pop(context);
              _assignGroup(g);
            },
          )),
        const SizedBox(height: 24),
      ]),
    );
  }

  // ── PROFILE TAB ───────────────────────────────────────────────────────────

  Widget _profileTab(_PersonDetail p) {
    final genderLabels = ['Other / Not Specified', 'Male', 'Female'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHead('Basic Information'),
        _infoRow(Icons.cake_rounded, 'Date of Birth', p.birthDate ?? '—'),
        _infoRow(Icons.wc_rounded, 'Gender',
            genderLabels[p.gender.clamp(0, 2)]),
        _infoRow(Icons.phone_rounded, 'Phone', p.phone ?? '—'),
        _infoRow(Icons.location_on_rounded, 'Address', p.address ?? '—'),
        _infoRow(Icons.flag_rounded, 'Country', p.country ?? '—'),

        if (p.gaitAnalysis.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionHead('Latest Gait Analysis'),
          _gaitCard(p.gaitAnalysis.first),
          if (p.gaitAnalysis.length > 1) ...[
            const SizedBox(height: 8),
            _sectionHead('History (${p.gaitAnalysis.length} entries)'),
            ...p.gaitAnalysis.skip(1).map(_gaitCard),
          ],
        ],
      ],
    );
  }

  Widget _sectionHead(String label) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 10),
    child: Text(label.toUpperCase(),
        style: const TextStyle(color: Color(0xFF2A4A6A),
            fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
  );

  Widget _infoRow(IconData icon, String label, String value) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF08141F),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF0F2030)),
    ),
    child: Row(children: [
      Icon(icon, color: const Color(0xFF2A4A6A), size: 16),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Color(0xFF2A4A6A), fontSize: 10)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ]),
    ]),
  );

  Widget _gaitCard(_GaitEntry g) {
    final date = DateTime.fromMillisecondsSinceEpoch(g.time * 1000);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF08141F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF0F2030)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${date.day}/${date.month}/${date.year}',
              style: const TextStyle(color: Color(0xFF2A4A6A), fontSize: 10)),
          Text(
            g.speed != null ? '${g.speed!.toStringAsFixed(2)} m/s' : '—',
            style: const TextStyle(color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.bold),
          ),
          if (g.duration != null)
            Text('${g.duration!.toStringAsFixed(1)}s duration',
                style: const TextStyle(color: Color(0xFF4A7FA8), fontSize: 11)),
        ])),
        if (g.totalScore != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _scoreColor(g.totalScore!).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _scoreColor(g.totalScore!).withOpacity(0.4)),
            ),
            child: Text('Score: ${g.totalScore}',
                style: TextStyle(color: _scoreColor(g.totalScore!),
                    fontSize: 11, fontWeight: FontWeight.bold)),
          ),
      ]),
    );
  }

  Color _scoreColor(int score) {
    if (score < 25)  return const Color(0xFF00DC78);
    if (score < 50)  return const Color(0xFFFFD700);
    return const Color(0xFFFF4040);
  }

  // ── FACES TAB ─────────────────────────────────────────────────────────────

  Widget _facesTab(_PersonDetail p) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                'Face photos are used by the camera to identify this person in alerts. '
                    'Add 2–3 clear front-facing photos for best accuracy.',
                style: TextStyle(color: Color(0xFF4A7FA8), fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _uploadingFace ? null : _uploadFace,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A9EFF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF4A9EFF).withOpacity(0.4)),
                  ),
                  child: _uploadingFace
                      ? const Center(child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF4A9EFF))))
                      : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_photo_alternate_rounded,
                        color: Color(0xFF4A9EFF), size: 18),
                    SizedBox(width: 8),
                    Text('Add Face Photo',
                        style: TextStyle(color: Color(0xFF4A9EFF),
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ),

        if (p.faces.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text('No face photos yet.\nAdd one above.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF2A4A6A))),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                    (_, i) => _faceCard(p.faces[i]),
                childCount: p.faces.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _faceCard(_FaceImage f) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF08141F),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: f.isValid
              ? const Color(0xFF00DC78).withOpacity(0.3)
              : const Color(0xFF1A3A5C)),
    ),
    child: Stack(children: [
      // Photo
      Positioned.fill(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.network(f.url, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF0F2030),
                child: const Icon(Icons.broken_image_rounded,
                    color: Color(0xFF2A4A6A), size: 32),
              )),
        ),
      ),
      // Valid badge
      Positioned(
        top: 8, left: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: f.isValid
                ? const Color(0xFF00DC78).withOpacity(0.85)
                : const Color(0xFFFF4040).withOpacity(0.85),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(f.isValid ? '✓ Valid' : '✗ Invalid',
              style: const TextStyle(color: Colors.white, fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
      ),
      // Delete button
      Positioned(
        top: 6, right: 6,
        child: GestureDetector(
          onTap: () => _deleteFace(f.id),
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded,
                color: Colors.white, size: 16),
          ),
        ),
      ),
    ]),
  );

  // ── HEALTH TAB ────────────────────────────────────────────────────────────

  Widget _healthTab(_PersonDetail p) {
    final hi = p.healthInfo;
    final bloodTypes = ['—', 'O-', 'O+', 'B-', 'B+', 'A-', 'A+', 'AB-', 'AB+'];
    String selectedBlood = hi?.bloodType ?? '—';

    // Controllers
    final htCtrl  = TextEditingController(text: hi?.height?.toString() ?? '');
    final wtCtrl  = TextEditingController(
        text: hi?.weight != null ? ((hi!.weight! / 1000).toStringAsFixed(1)) : '');
    final alCtrl  = TextEditingController(text: hi?.allergies ?? '');
    final ntCtrl  = TextEditingController(text: hi?.notes ?? '');

    return StatefulBuilder(builder: (ctx, ss) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Health information is used by caregivers. '
              'Height and weight are used for fall risk calculations.',
          style: TextStyle(color: Color(0xFF4A7FA8), fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 16),

        _sectionHead('Measurements'),
        Row(children: [
          Expanded(child: _textInput(htCtrl, 'Height (cm)', isNumber: true)),
          const SizedBox(width: 10),
          Expanded(child: _textInput(wtCtrl, 'Weight (kg)', isNumber: true)),
        ]),

        const SizedBox(height: 12),
        _sectionHead('Blood Type'),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: bloodTypes.map((bt) => GestureDetector(
            onTap: () => ss(() => selectedBlood = bt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selectedBlood == bt
                    ? const Color(0xFFFF4040).withOpacity(0.15)
                    : const Color(0xFF08141F),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selectedBlood == bt
                      ? const Color(0xFFFF4040).withOpacity(0.5)
                      : const Color(0xFF0F2030),
                ),
              ),
              child: Text(bt,
                  style: TextStyle(
                    color: selectedBlood == bt
                        ? const Color(0xFFFF4040)
                        : const Color(0xFF4A7FA8),
                    fontSize: 12, fontWeight: FontWeight.bold,
                  )),
            ),
          )).toList(),
        ),

        const SizedBox(height: 12),
        _sectionHead('Allergies'),
        _textInput(alCtrl, 'e.g. Peanuts, Dust'),

        const SizedBox(height: 12),
        _sectionHead('Notes'),
        _textInput(ntCtrl, 'Any additional medical notes...', maxLines: 3),

        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => _saveHealthInfo(
            height:    double.tryParse(htCtrl.text),
            weight:    double.tryParse(wtCtrl.text),
            bloodType: selectedBlood == '—' ? null : selectedBlood,
            allergies: alCtrl.text.trim(),
            notes:     ntCtrl.text.trim(),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF4A9EFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF4A9EFF).withOpacity(0.4)),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.save_rounded, color: Color(0xFF4A9EFF), size: 16),
              SizedBox(width: 8),
              Text('Save Health Info',
                  style: TextStyle(color: Color(0xFF4A9EFF),
                      fontSize: 13, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ],
    ));
  }

  Widget _textInput(TextEditingController ctrl, String hint,
      {bool isNumber = false, int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF2A4A6A), fontSize: 12),
          filled: true,
          fillColor: const Color(0xFF08141F),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0F2030))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0F2030))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4A9EFF))),
        ),
      );

  // ── CONTACTS TAB ──────────────────────────────────────────────────────────

  Widget _contactsTab(_PersonDetail p) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: GestureDetector(
          onTap: _addEmergencyContact,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B9D).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFF6B9D).withOpacity(0.4)),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.person_add_rounded, color: Color(0xFFFF6B9D), size: 16),
              SizedBox(width: 8),
              Text('Add Emergency Contact',
                  style: TextStyle(color: Color(0xFFFF6B9D),
                      fontSize: 13, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ),
      Expanded(
        child: p.emergencyContacts.isEmpty
            ? const Center(
          child: Text('No emergency contacts.\nAdd one above.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF2A4A6A))),
        )
            : ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: p.emergencyContacts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _contactCard(p.emergencyContacts[i]),
        ),
      ),
    ]);
  }

  Widget _contactCard(_EmContact c) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF08141F),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF0F2030)),
    ),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B9D).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person_rounded, color: Color(0xFFFF6B9D), size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 13,
            fontWeight: FontWeight.w600)),
        if (c.relation != null && c.relation!.isNotEmpty)
          Text(c.relation!, style: const TextStyle(
              color: Color(0xFF4A7FA8), fontSize: 11)),
        if (c.phone != null && c.phone!.isNotEmpty)
          Text(c.phone!, style: const TextStyle(
              color: Color(0xFF4A9EFF), fontSize: 11)),
      ])),
      GestureDetector(
        onTap: () => _deleteEmContact(c.id),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFFF4040).withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFFF4040).withOpacity(0.3)),
          ),
          child: const Icon(Icons.delete_outline_rounded,
              color: Color(0xFFFF4040), size: 16),
        ),
      ),
    ]),
  );
}

// Tiny helper for the dialog fields
class _Field {
  final String label;
  final void Function(String) onChanged;
  _Field(this.label, this.onChanged);
}