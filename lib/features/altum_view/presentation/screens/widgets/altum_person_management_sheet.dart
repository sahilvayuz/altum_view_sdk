// ─────────────────────────────────────────────────────────────────────────────
// altum_person_management_sheet.dart
//
// Drop-in replacement for the _PersonManagementSheet inside altum_alert_dashboard.dart.
//
// HOW TO USE — inside _AltumDashboardPageState._openPersonManagement():
//
//   void _openPersonManagement() {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: const Color(0xFF07101E),
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (_) => AltumPersonManagementSheet(
//         accessToken:   widget.accessToken,
//         personService: _personService,
//       ),
//     );
//   }
//
// WHAT'S NEW vs the old sheet:
//   • Two tabs: PEOPLE | GROUPS
//   • PEOPLE tab: tap a person row → opens AltumPersonDetailPage (full screen)
//   • PEOPLE tab: "Add" form now has a group picker
//   • GROUPS tab: create / rename / delete person groups
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';
import 'package:altum_view_sdk/features/altum_view/presentation/screens/people/altum_people_detail_page.dart';
import 'package:altum_view_sdk/features/altum_view/services/altum_person_group_service.dart';
import 'package:altum_view_sdk/features/altum_view/services/altum_person_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// Import your existing person service — adjust path to match your project

// ─────────────────────────────────────────────────────────────────────────────

class AltumPersonManagementSheet extends StatefulWidget {
  final String            accessToken;
  final AltumPersonService personService;

  const AltumPersonManagementSheet({
    super.key,
    required this.accessToken,
    required this.personService,
  });

  @override
  State<AltumPersonManagementSheet> createState() => _AltumPersonManagementSheetState();
}

class _AltumPersonManagementSheetState extends State<AltumPersonManagementSheet>
    with SingleTickerProviderStateMixin {

  late final TabController _tabs;
  late final AltumPersonGroupService _groupService;

  // ── People state ──────────────────────────────────────────────────────────
  List<AltumPerson>      _people    = [];
  bool   _loadingPeople  = true;
  bool   _savingPerson   = false;
  String _nameInput      = '';
  int?   _selectedGroupId;        // group chosen in the "add person" form
  int?   _uploadingForId;
  String? _peopleStatus;
  bool    _peopleStatusError = false;

  // ── Groups state ──────────────────────────────────────────────────────────
  List<AltumPersonGroup> _groups       = [];
  bool   _loadingGroups  = true;
  bool   _savingGroup    = false;
  String _groupNameInput  = '';
  PersonGroupType _groupTypeInput = PersonGroupType.senior;
  String? _groupStatus;
  bool    _groupStatusError = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _groupService = AltumPersonGroupService(accessToken: widget.accessToken);
    _loadPeople();
    _loadGroups();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _loadPeople() async {
    setState(() { _loadingPeople = true; _peopleStatus = null; });
    try {
      final list = await widget.personService.getPeople();
      if (mounted) setState(() { _people = list; _loadingPeople = false; });
    } catch (e) {
      if (mounted) setState(() {
        _loadingPeople = false;
        _peopleStatus = 'Error loading people: $e';
        _peopleStatusError = true;
      });
    }
  }

  Future<void> _loadGroups() async {
    setState(() { _loadingGroups = true; _groupStatus = null; });
    try {
      final list = await _groupService.getGroups();
      if (mounted) setState(() { _groups = list; _loadingGroups = false; });
    } catch (e) {
      if (mounted) setState(() {
        _loadingGroups = false;
        _groupStatus = 'Error loading groups: $e';
        _groupStatusError = true;
      });
    }
  }

  // ── People actions ────────────────────────────────────────────────────────

  Future<void> _addPerson() async {
    if (_nameInput.trim().isEmpty) {
      setState(() { _peopleStatus = 'Please enter a name'; _peopleStatusError = true; });
      return;
    }
    setState(() { _savingPerson = true; _peopleStatus = null; });
    try {
      // We use the raw HTTP call to include person_group_id because the base
      // service doesn't expose it — or you can extend AltumPersonService.
      // Using the service's createPerson for simplicity, then patch if group chosen.
      final id = await widget.personService.createPerson(_nameInput.trim());

      // Assign group if user selected one
      if (_selectedGroupId != null) {
        try {
          await widget.personService.assignGroup(
              personId: id, groupId: _selectedGroupId!);
        } catch (e) {
          log('⚠️ Group assign after create failed: $e');
        }
      }

      if (mounted) setState(() {
        _peopleStatus = '✅ ${_nameInput.trim()} added. Upload their face photo below.';
        _peopleStatusError = false;
        _nameInput = '';
        _selectedGroupId = null;
        _savingPerson = false;
      });
      await _loadPeople();
    } catch (e) {
      if (mounted) setState(() {
        _peopleStatus = '❌ Error: $e';
        _peopleStatusError = true;
        _savingPerson = false;
      });
    }
  }

  Future<void> _uploadFace(AltumPerson person) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 90, maxWidth: 800);
    if (picked == null) return;
    setState(() { _uploadingForId = person.id; _peopleStatus = null; });
    try {
      final bytes = await picked.readAsBytes();
      await widget.personService.uploadFacePhoto(
        personId:   person.id,
        imageBytes: bytes,
        filename:   '${person.name.replaceAll(' ', '_')}_face.jpg',
      );
      if (mounted) setState(() {
        _peopleStatus = '✅ Face uploaded for ${person.name}.';
        _peopleStatusError = false;
      });
      await _loadPeople();
    } catch (e) {
      if (mounted) setState(() {
        _peopleStatus = '❌ Upload failed: $e';
        _peopleStatusError = true;
      });
    } finally {
      if (mounted) setState(() => _uploadingForId = null);
    }
  }

  Future<void> _deletePerson(AltumPerson person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF08141F),
        title: Text('Delete ${person.name}?',
            style: const TextStyle(color: Colors.white)),
        content: const Text(
          'This removes them from the system permanently.',
          style: TextStyle(color: Color(0xFF4A7FA8)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF4A7FA8)))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Color(0xFFFF4040)))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.personService.deletePerson(person.id);
      await _loadPeople();
    } catch (e) {
      if (mounted) setState(() {
        _peopleStatus = '❌ Delete failed: $e';
        _peopleStatusError = true;
      });
    }
  }

  void _openPersonDetail(AltumPerson p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AltumPersonDetailPage(
          accessToken: widget.accessToken,
          personId:    p.id,
        ),
      ),
    ).then((_) => _loadPeople()); // refresh list when coming back
  }

  // ── Group actions ─────────────────────────────────────────────────────────

  Future<void> _createGroup() async {
    if (_groupNameInput.trim().isEmpty) {
      setState(() { _groupStatus = 'Enter a group name'; _groupStatusError = true; });
      return;
    }
    setState(() { _savingGroup = true; _groupStatus = null; });
    try {
      final id = await _groupService.createGroup(
          name: _groupNameInput.trim(), type: _groupTypeInput);
      if (mounted) setState(() {
        _groupStatus = '✅ Group "${_groupNameInput.trim()}" created (ID: $id)';
        _groupStatusError = false;
        _groupNameInput = '';
        _savingGroup = false;
      });
      await _loadGroups();
    } catch (e) {
      if (mounted) setState(() {
        _groupStatus = '❌ Error: $e';
        _groupStatusError = true;
        _savingGroup = false;
      });
    }
  }

  Future<void> _editGroup(AltumPersonGroup g) async {
    String newName = g.name;
    PersonGroupType newType = g.type;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        backgroundColor: const Color(0xFF08141F),
        title: const Text('Edit Group', style: TextStyle(color: Colors.white, fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // Name
          TextField(
            controller: TextEditingController(text: g.name),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Group Name',
              labelStyle: const TextStyle(color: Color(0xFF4A7FA8)),
              filled: true,
              fillColor: const Color(0xFF0F2030),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1A3A5C))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1A3A5C))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF4A9EFF))),
            ),
            onChanged: (v) => newName = v,
          ),
          const SizedBox(height: 12),
          // Type picker
          Wrap(
            spacing: 6, runSpacing: 6,
            children: PersonGroupType.values.map((t) => GestureDetector(
              onTap: () => ss(() => newType = t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: newType == t
                      ? Color(AltumPersonGroup(id: 0, name: '', type: t).uiColour)
                      .withOpacity(0.15)
                      : const Color(0xFF0F2030),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: newType == t
                        ? Color(AltumPersonGroup(id: 0, name: '', type: t).uiColour)
                        .withOpacity(0.5)
                        : const Color(0xFF1A3A5C),
                  ),
                ),
                child: Text('${t.emoji} ${t.label}',
                    style: TextStyle(
                      color: newType == t
                          ? Color(AltumPersonGroup(id: 0, name: '', type: t).uiColour)
                          : const Color(0xFF4A7FA8),
                      fontSize: 12,
                    )),
              ),
            )).toList(),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF4A7FA8)))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _groupService.updateGroup(
                    id: g.id, name: newName.trim(), type: newType);
                await _loadGroups();
              } catch (e) {
                if (mounted) setState(() {
                  _groupStatus = '❌ Update failed: $e';
                  _groupStatusError = true;
                });
              }
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFF4A9EFF))),
          ),
        ],
      )),
    );
  }

  Future<void> _deleteGroup(AltumPersonGroup g) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF08141F),
        title: Text('Delete "${g.name}"?',
            style: const TextStyle(color: Colors.white)),
        content: const Text(
          'People in this group will become ungrouped. This cannot be undone.',
          style: TextStyle(color: Color(0xFF4A7FA8)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF4A7FA8)))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Color(0xFFFF4040)))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _groupService.deleteGroup(g.id);
      await _loadGroups();
    } catch (e) {
      if (mounted) setState(() {
        _groupStatus = '❌ Delete failed: $e';
        _groupStatusError = true;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Column(children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A5C), borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            Icon(Icons.people_rounded, color: Color(0xFF4A9EFF), size: 20),
            SizedBox(width: 10),
            Text('Manage People & Groups',
                style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ]),
        ),

        // Tab bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF08141F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF0F2030)),
          ),
          child: TabBar(
            controller: _tabs,
            labelColor: const Color(0xFF4A9EFF),
            unselectedLabelColor: const Color(0xFF2A4A6A),
            indicator: BoxDecoration(
              color: const Color(0xFF4A9EFF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFF4A9EFF).withOpacity(0.3)),
            ),
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: [
              Tab(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.person_rounded, size: 14),
                  const SizedBox(width: 6),
                  Text('People (${_people.length})'),
                ]),
              ),
              Tab(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.group_work_rounded, size: 14),
                  const SizedBox(width: 6),
                  Text('Groups (${_groups.length})'),
                ]),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _peopleTab(scrollCtrl),
              _groupsTab(scrollCtrl),
            ],
          ),
        ),
      ]),
    );
  }

  // ── PEOPLE TAB ─────────────────────────────────────────────────────────────

  Widget _peopleTab(ScrollController scrollCtrl) {
    return Column(children: [
      // Status
      if (_peopleStatus != null)
        _statusBanner(_peopleStatus!, _peopleStatusError),

      // Add person form
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Column(children: [
          // Name input + add button row
          Row(children: [
            Expanded(
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDeco("Resident's name"),
                onChanged: (v) => _nameInput = v,
                onSubmitted: (_) => _addPerson(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _savingPerson ? null : _addPerson,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A9EFF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4A9EFF).withOpacity(0.4)),
                ),
                child: _savingPerson
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF4A9EFF)))
                    : const Icon(Icons.add_rounded, color: Color(0xFF4A9EFF), size: 20),
              ),
            ),
          ]),

          // Group selector for new person
          if (_groups.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // "No group" chip
                  GestureDetector(
                    onTap: () => setState(() => _selectedGroupId = null),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _selectedGroupId == null
                            ? const Color(0xFF2A4A6A).withOpacity(0.3)
                            : const Color(0xFF08141F),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedGroupId == null
                              ? const Color(0xFF2A4A6A)
                              : const Color(0xFF0F2030),
                        ),
                      ),
                      child: const Text('No group',
                          style: TextStyle(color: Color(0xFF4A7FA8), fontSize: 11)),
                    ),
                  ),
                  ..._groups.map((g) => GestureDetector(
                    onTap: () => setState(() => _selectedGroupId = g.id),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _selectedGroupId == g.id
                            ? Color(g.uiColour).withOpacity(0.15)
                            : const Color(0xFF08141F),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedGroupId == g.id
                              ? Color(g.uiColour).withOpacity(0.5)
                              : const Color(0xFF0F2030),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(g.type.emoji, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(g.name,
                            style: TextStyle(
                              color: _selectedGroupId == g.id
                                  ? Color(g.uiColour) : const Color(0xFF4A7FA8),
                              fontSize: 11,
                            )),
                      ]),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ]),
      ),

      const SizedBox(height: 10),

      // List
      Expanded(
        child: _loadingPeople
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A9EFF)))
            : _people.isEmpty
            ? const Center(
          child: Text('No people registered yet.\nAdd one above.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF2A4A6A), fontSize: 13)),
        )
            : ListView.separated(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          itemCount: _people.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _personRow(_people[i]),
        ),
      ),
    ]);
  }

  Widget _personRow(AltumPerson p) {
    final isUploading = _uploadingForId == p.id;
    return GestureDetector(
      // ← TAP TO OPEN DETAIL PAGE
      onTap: () => _openPersonDetail(p),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF08141F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF0F2030)),
        ),
        child: Row(children: [
          // Avatar
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF4A9EFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: p.profileImageUrl != null
                ? ClipOval(child: Image.network(p.profileImageUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initials(p.name)))
                : _initials(p.name),
          ),
          const SizedBox(width: 12),

          // Name + status
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Row(children: [
                Icon(
                  p.hasFacePhoto
                      ? Icons.face_rounded : Icons.face_retouching_off_rounded,
                  color: p.hasFacePhoto
                      ? const Color(0xFF00DC78) : const Color(0xFFFF6B9D),
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  p.hasFacePhoto ? 'Face registered' : 'No face photo',
                  style: TextStyle(
                    color: p.hasFacePhoto
                        ? const Color(0xFF00DC78) : const Color(0xFFFF6B9D),
                    fontSize: 10,
                  ),
                ),
              ]),
            ]),
          ),

          // Upload face
          GestureDetector(
            onTap: isUploading ? null : () => _uploadFace(p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00DC78).withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF00DC78).withOpacity(0.3)),
              ),
              child: isUploading
                  ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF00DC78)))
                  : const Icon(Icons.upload_rounded,
                  color: Color(0xFF00DC78), size: 15),
            ),
          ),
          const SizedBox(width: 6),

          // Delete
          GestureDetector(
            onTap: () => _deletePerson(p),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4040).withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFF4040).withOpacity(0.3)),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFFF4040), size: 15),
            ),
          ),
          const SizedBox(width: 4),

          // Arrow hint
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFF2A4A6A), size: 16),
        ]),
      ),
    );
  }

  Widget _initials(String name) => Center(
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(color: Color(0xFF4A9EFF),
          fontSize: 16, fontWeight: FontWeight.bold),
    ),
  );

  // ── GROUPS TAB ─────────────────────────────────────────────────────────────

  Widget _groupsTab(ScrollController scrollCtrl) {
    return Column(children: [
      // Status
      if (_groupStatus != null)
        _statusBanner(_groupStatus!, _groupStatusError),

      // Create group form
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Name + add row
          Row(children: [
            Expanded(
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDeco('Group name (e.g. Ward A Seniors)'),
                onChanged: (v) => _groupNameInput = v,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _savingGroup ? null : _createGroup,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF00DC78).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00DC78).withOpacity(0.4)),
                ),
                child: _savingGroup
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF00DC78)))
                    : const Icon(Icons.add_rounded, color: Color(0xFF00DC78), size: 20),
              ),
            ),
          ]),

          const SizedBox(height: 10),

          // Type picker
          const Text('Type:', style: TextStyle(color: Color(0xFF2A4A6A),
              fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          StatefulBuilder(builder: (_, ss) => Wrap(
            spacing: 6, runSpacing: 6,
            children: PersonGroupType.values.map((t) => GestureDetector(
              onTap: () {
                setState(() => _groupTypeInput = t);
                ss(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _groupTypeInput == t
                      ? Color(AltumPersonGroup(id: 0, name: '', type: t).uiColour)
                      .withOpacity(0.15)
                      : const Color(0xFF08141F),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _groupTypeInput == t
                        ? Color(AltumPersonGroup(id: 0, name: '', type: t).uiColour)
                        .withOpacity(0.5)
                        : const Color(0xFF0F2030),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(t.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(t.label,
                      style: TextStyle(
                        color: _groupTypeInput == t
                            ? Color(AltumPersonGroup(id: 0, name: '', type: t).uiColour)
                            : const Color(0xFF4A7FA8),
                        fontSize: 12, fontWeight: FontWeight.w500,
                      )),
                ]),
              ),
            )).toList(),
          )),

          const SizedBox(height: 4),
          const Text(
            'Groups let you categorise residents. Cameras can then apply different '
                'detection rules per group (e.g. restricted zones only alert for Seniors).',
            style: TextStyle(color: Color(0xFF2A4A6A), fontSize: 10, height: 1.5),
          ),
        ]),
      ),

      const SizedBox(height: 10),

      // Group list
      Expanded(
        child: _loadingGroups
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00DC78)))
            : _groups.isEmpty
            ? const Center(
          child: Text('No groups yet.\nCreate one above.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF2A4A6A), fontSize: 13)),
        )
            : ListView.separated(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          itemCount: _groups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _groupRow(_groups[i]),
        ),
      ),
    ]);
  }

  Widget _groupRow(AltumPersonGroup g) {
    // Count how many people are in this group
    final count = _people
        .where((p) => p.groupId == g.id)
        .length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF08141F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Color(g.uiColour).withOpacity(0.2)),
      ),
      child: Row(children: [
        // Icon
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: Color(g.uiColour).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(g.type.emoji, style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),

        // Name + type + count
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.name, style: const TextStyle(color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(g.uiColour).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(g.type.label,
                    style: TextStyle(color: Color(g.uiColour), fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Text('$count ${count == 1 ? "person" : "people"}',
                  style: const TextStyle(color: Color(0xFF2A4A6A), fontSize: 10)),
            ]),
          ]),
        ),

        // Edit
        GestureDetector(
          onTap: () => _editGroup(g),
          child: Container(
            padding: const EdgeInsets.all(7),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: Color(g.uiColour).withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Color(g.uiColour).withOpacity(0.25)),
            ),
            child: Icon(Icons.edit_rounded, color: Color(g.uiColour), size: 15),
          ),
        ),

        // Delete
        GestureDetector(
          onTap: () => _deleteGroup(g),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4040).withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFF4040).withOpacity(0.3)),
            ),
            child: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFFF4040), size: 15),
          ),
        ),
      ]),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _statusBanner(String msg, bool isError) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (isError ? const Color(0xFFFF4040) : const Color(0xFF00DC78))
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isError ? const Color(0xFFFF4040) : const Color(0xFF00DC78))
              .withOpacity(0.3),
        ),
      ),
      child: Text(msg,
          style: TextStyle(
            color: isError ? const Color(0xFFFF4040) : const Color(0xFF00DC78),
            fontSize: 12,
          )),
    ),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
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
  );
}