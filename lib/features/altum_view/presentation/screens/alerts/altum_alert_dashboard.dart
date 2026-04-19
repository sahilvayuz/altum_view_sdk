// ─────────────────────────────────────────────────────────────────────────────
// altum_dashboard_page.dart
//
// The MASTER HUB screen that connects every AltumView feature.
// Navigate here after login with just the accessToken and cameraId.
//
// HOW TO OPEN THIS SCREEN:
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => AltumDashboardPage(
//       accessToken: myToken,
//       cameraId:    11237,
//       serialNumber: '230C4C2056C9D0EE',
//     ),
//   ));
//
// WHAT THIS FILE CONTAINS:
//   1. AltumDashboardPage       — master hub with all feature buttons
//   2. _PersonManagementSheet   — bottom sheet: add person, upload face, list people
//   3. _CameraSettingsSheet     — bottom sheet: fall sensitivity, filters
//   4. How notifications are wired (see initState)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:developer';
import 'package:altum_view_sdk/features/altum_view/helpers/altum_notification_helper.dart';
import 'package:altum_view_sdk/features/altum_view/presentation/screens/alerts/altum_alert_page.dart';
import 'package:altum_view_sdk/features/altum_view/presentation/screens/widgets/altum_person_management_sheet.dart';
import 'package:altum_view_sdk/features/altum_view/services/altum_alert_service.dart';
import 'package:altum_view_sdk/features/altum_view/services/altum_person_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ── Adjust these import paths to match your project structure ─────────────────
import 'package:http/http.dart' as http;
// ─────────────────────────────────────────────────────────────────────────────

const String _baseApi = 'https://api.altumview.ca/v1.0';

// ═════════════════════════════════════════════════════════════════════════════
// CAMERA SETTINGS MODEL
// What settings the camera supports (from AltumView API PATCH /cameras/:id)
// ═════════════════════════════════════════════════════════════════════════════

class CameraSettings {
  // Fall detection sensitivity: 'OFF', 'LOW', 'MED', 'HIGH'
  String fallSensitivity;

  // AI filter to reduce false positives — requires subscription
  // 'ON' means camera double-checks before sending alert
  bool aiFilter;

  // Whether the camera is currently online
  bool isOnline;

  // Whether the camera is currently streaming skeleton data
  bool isStreaming;

  CameraSettings({
    this.fallSensitivity = 'MED',
    this.aiFilter = false,
    this.isOnline = false,
    this.isStreaming = false,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// MASTER DASHBOARD
// ═════════════════════════════════════════════════════════════════════════════

class AltumDashboardPage extends StatefulWidget {
  final String accessToken;
  final int    cameraId;
  final String serialNumber;

  const AltumDashboardPage({
    super.key,
    required this.accessToken,
    required this.cameraId,
    required this.serialNumber,
  });

  @override
  State<AltumDashboardPage> createState() => _AltumDashboardPageState();
}

class _AltumDashboardPageState extends State<AltumDashboardPage> {
  late final AltumAlertService  _alertService;
  late final AltumPersonService _personService;

  int    _unresolvedCount = 0;
  bool   _notificationsWired = false;
  CameraSettings _camSettings = CameraSettings();

  @override
  void initState() {
    super.initState();

    _alertService  = AltumAlertService(accessToken: widget.accessToken);
    _personService = AltumPersonService(accessToken: widget.accessToken);

    // ── STEP 1: Wire up notifications ──────────────────────────────────────
    // This is how notifications get triggered automatically:
    //   • alertService polls every 30s
    //   • when a NEW alert ID appears that we haven't seen before,
    //     onNewAlert fires
    //   • we call showFallAlert which shows the push notification on device
    //   • we also update the red badge count on the dashboard button
    _alertService.startPolling();
    _alertService.onNewAlert.listen((alert) {
      // Show phone push notification
      AltumNotificationHelper.showFallAlert(alert);
      // Update the red badge on the Alerts button
      if (mounted) setState(() => _unresolvedCount++);
      log('🚨 New alert received: ${alert.personName} — ${alert.eventType}');
    });
    _notificationsWired = true;

    // Load initial unresolved count and camera settings
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // Get current unresolved count
      final alerts = await _alertService.getAlerts(unresolvedOnly: true);
      // Get camera settings
      final settings = await _fetchCameraSettings();
      if (mounted) {
        setState(() {
          _unresolvedCount = alerts.isEmpty ? 0 : alerts.first.unresolvedCount;
          _camSettings = settings;
        });
      }
    } catch (e) {
      log('⚠️ Dashboard init error: $e');
    }
  }

  Future<CameraSettings> _fetchCameraSettings() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseApi/cameras/${widget.cameraId}'),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );
      if (resp.statusCode == 200) {
        final body   = jsonDecode(resp.body) as Map<String, dynamic>;
        final camera = body['data']?['camera'] as Map<String, dynamic>? ?? {};
        return CameraSettings(
          // fall_detection_sensitivity field from AltumView API
          fallSensitivity: camera['fall_detection_sensitivity'] as String? ?? 'MED',
          // ai_fall_alert_filter field
          aiFilter:   (camera['ai_fall_alert_filter'] as String?) == 'ON',
          isOnline:   (camera['is_online']    as bool?) ?? false,
          isStreaming: (camera['is_streaming'] as bool?) ?? false,
        );
      }
    } catch (e) {
      log('⚠️ fetchCameraSettings error: $e');
    }
    return CameraSettings();
  }

  @override
  void dispose() {
    _alertService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07101E),
      body: SafeArea(
        child: Column(children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [

                // ── Camera status card ──────────────────────────────────────
                _cameraStatusCard(),
                const SizedBox(height: 20),

                // ── Section: Monitoring ─────────────────────────────────────
                _sectionLabel('MONITORING'),
                const SizedBox(height: 10),
                Row(children: [
                  // Fall Alerts button — has red badge for unresolved count
                  Expanded(child: _featureButton(
                    icon:    Icons.warning_amber_rounded,
                    label:   'Fall Alerts',
                    sublabel: _unresolvedCount > 0
                        ? '$_unresolvedCount unresolved'
                        : 'No pending alerts',
                    color:   _unresolvedCount > 0
                        ? const Color(0xFFFF4040)
                        : const Color(0xFF2A6FAA),
                    badge:   _unresolvedCount > 0 ? '$_unresolvedCount' : null,
                    onTap:   _openAlerts,
                  )),
                  const SizedBox(width: 12),
                  // Live stream button
                  Expanded(child: _featureButton(
                    icon:    Icons.sensors_rounded,
                    label:   'Live Stream',
                    sublabel: _camSettings.isStreaming ? 'Camera active' : 'Camera idle',
                    color:   const Color(0xFF00DC78),
                    onTap:   _openLiveStream,
                  )),
                ]),

                const SizedBox(height: 20),

                // ── Section: People ─────────────────────────────────────────
                _sectionLabel('PEOPLE & RECOGNITION'),
                const SizedBox(height: 10),
                _featureButtonWide(
                  icon:    Icons.person_add_rounded,
                  label:   'Manage People',
                  sublabel: 'Add residents, upload face photos for name recognition',
                  color:   const Color(0xFF4A9EFF),
                  onTap:   _openPersonManagement,
                ),

                const SizedBox(height: 20),

                // ── Section: Camera ─────────────────────────────────────────
                _sectionLabel('CAMERA SETTINGS'),
                const SizedBox(height: 10),
                _featureButtonWide(
                  icon:    Icons.tune_rounded,
                  label:   'Detection Settings',
                  sublabel: 'Sensitivity: ${_camSettings.fallSensitivity}  •  '
                      'AI Filter: ${_camSettings.aiFilter ? "ON" : "OFF"}',
                  color:   const Color(0xFFFFD700),
                  onTap:   _openCameraSettings,
                ),

                const SizedBox(height: 20),

                // ── Section: Testing ────────────────────────────────────────
                _sectionLabel('TESTING'),
                const SizedBox(height: 10),
                _featureButtonWide(
                  icon:    Icons.bug_report_rounded,
                  label:   'Test Alert Flow',
                  sublabel: 'How to manually trigger a test alert',
                  color:   const Color(0xFFFF6B9D),
                  onTap:   _showTestGuide,
                ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFF0F2030))),
    ),
    child: Row(children: [
      const Icon(Icons.sensors_rounded, color: Color(0xFF00DC78), size: 20),
      const SizedBox(width: 10),
      const Expanded(
        child: Text('AltumView',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      // Notification wired indicator
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _notificationsWired
              ? const Color(0xFF00DC78).withOpacity(0.1)
              : const Color(0xFFFF4040).withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _notificationsWired
                ? const Color(0xFF00DC78).withOpacity(0.3)
                : const Color(0xFFFF4040).withOpacity(0.3),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _notificationsWired
                  ? const Color(0xFF00DC78)
                  : const Color(0xFFFF4040),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _notificationsWired ? 'WATCHING' : 'OFFLINE',
            style: TextStyle(
              color: _notificationsWired
                  ? const Color(0xFF00DC78)
                  : const Color(0xFFFF4040),
              fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2,
            ),
          ),
        ]),
      ),
    ]),
  );

  // ── Camera status card ──────────────────────────────────────────────────────

  Widget _cameraStatusCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF08141F),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF0F2030)),
    ),
    child: Row(children: [
      // Online dot
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _camSettings.isOnline
              ? const Color(0xFF00DC78)
              : const Color(0xFFFF4040),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'CAM #${widget.cameraId}  •  ${widget.serialNumber}',
            style: const TextStyle(color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 3),
          Text(
            _camSettings.isOnline ? 'Online' : 'Offline — alerts will not work',
            style: TextStyle(
              color: _camSettings.isOnline
                  ? const Color(0xFF2A6FAA)
                  : const Color(0xFFFF4040),
              fontSize: 11,
            ),
          ),
        ]),
      ),
      // Refresh
      GestureDetector(
        onTap: _loadInitialData,
        child: const Icon(Icons.refresh_rounded, color: Color(0xFF2A4A6A), size: 18),
      ),
    ]),
  );

  // ── Section label ───────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Align(
    alignment: Alignment.centerLeft,
    child: Text(label,
        style: const TextStyle(
            color: Color(0xFF2A4A6A), fontSize: 10,
            fontWeight: FontWeight.bold, letterSpacing: 1.5)),
  );

  // ── Feature button (half width) ─────────────────────────────────────────────

  Widget _featureButton({
    required IconData icon,
    required String   label,
    required String   sublabel,
    required Color    color,
    required VoidCallback onTap,
    String?           badge,
  }) => GestureDetector(
    onTap: onTap,
    child: Stack(clipBehavior: Clip.none, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF08141F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(sublabel,
              style: const TextStyle(color: Color(0xFF2A4A6A), fontSize: 11),
              maxLines: 2),
        ]),
      ),
      if (badge != null)
        Positioned(
          top: -6, right: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4040),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(badge,
                style: const TextStyle(color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ),
    ]),
  );

  // ── Feature button (full width) ─────────────────────────────────────────────

  Widget _featureButtonWide({
    required IconData icon,
    required String   label,
    required String   sublabel,
    required Color    color,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF08141F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(sublabel,
                style: const TextStyle(color: Color(0xFF2A4A6A), fontSize: 11)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFF2A4A6A)),
      ]),
    ),
  );

  // ── Navigation actions ──────────────────────────────────────────────────────

  void _openAlerts() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AltumAlertsPage(accessToken: widget.accessToken),
    )).then((_) => _loadInitialData()); // refresh badge after coming back
  }

  void _openLiveStream() {
    // Navigate to your existing live stream page
    // Navigator.push(context, MaterialPageRoute(
    //   builder: (_) => AltumSkeletonStreamPage(
    //     cameraId:     widget.cameraId,
    //     serialNumber: widget.serialNumber,
    //     accessToken:  widget.accessToken,
    //   ),
    // ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to your AltumSkeletonStreamPage here')),
    );
  }

  void _openPersonManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF07101E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          AltumPersonManagementSheet(
        accessToken:   widget.accessToken,
        personService: _personService,
      ),
    );
  }

  void _openCameraSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF07101E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CameraSettingsSheet(
        accessToken: widget.accessToken,
        cameraId:    widget.cameraId,
        current:     _camSettings,
        onSaved: (updated) {
          setState(() => _camSettings = updated);
        },
      ),
    );
  }

  void _showTestGuide() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF07101E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _TestGuideSheet(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET 1 — PERSON MANAGEMENT
// Register people + upload face photos
// ═════════════════════════════════════════════════════════════════════════════

class _PersonManagementSheet extends StatefulWidget {
  final String            accessToken;
  final AltumPersonService personService;

  const _PersonManagementSheet({
    required this.accessToken,
    required this.personService,
  });

  @override
  State<_PersonManagementSheet> createState() => _PersonManagementSheetState();
}

class _PersonManagementSheetState extends State<_PersonManagementSheet> {
  List<AltumPerson> _people = [];
  bool   _loading    = true;
  bool   _saving     = false;
  String _nameInput  = '';
  String? _statusMsg;
  bool    _isError   = false;

  // For face upload: which person ID is being uploaded to
  int?   _uploadingForId;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    setState(() { _loading = true; _statusMsg = null; });
    try {
      final list = await widget.personService.getPeople();
      log('persons list ${list[0].name} ${list[0].id}');
      if (mounted) setState(() { _people = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _statusMsg = 'Error loading people: $e';
        _isError   = true;
      });
    }
  }

  Future<void> _addPerson() async {
    if (_nameInput.trim().isEmpty) {
      setState(() { _statusMsg = 'Please enter a name first'; _isError = true; });
      return;
    }
    setState(() { _saving = true; _statusMsg = null; });
    try {
      final id = await widget.personService.createPerson(_nameInput.trim());
      setState(() {
        _statusMsg = '✅ ${_nameInput.trim()} added (ID: $id). Now upload their face photo below.';
        _isError   = false;
        _nameInput = '';
      });
      await _loadPeople(); // refresh list
    } catch (e) {
      setState(() { _statusMsg = '❌ Error: $e'; _isError = true; });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadFace(AltumPerson person) async {
    // Pick a photo from gallery or camera
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,        // JPEG quality
      maxWidth:     800,       // don't upload a giant file
    );
    if (picked == null) return; // user cancelled

    setState(() { _uploadingForId = person.id; _statusMsg = null; });
    try {
      final bytes = await picked.readAsBytes();
      await widget.personService.uploadFacePhoto(
        personId:   person.id,
        imageBytes: bytes,
        filename:   '${person.name.replaceAll(' ', '_')}_face.jpg',
      );
      if (mounted) setState(() {
        _statusMsg = '✅ Face photo uploaded for ${person.name}. '
            'Camera will now recognise them in future alerts.';
        _isError = false;
      });
      await _loadPeople();
    } catch (e) {
      log('error while uploading image: $e');
      if (mounted) setState(() { _statusMsg = '❌ Upload failed: $e'; _isError = true; });
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
          'This removes them from the system. Future alerts will show "Unknown" '
              'if the camera sees them.',
          style: TextStyle(color: Color(0xFF4A7FA8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF4A7FA8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF4040))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.personService.deletePerson(person.id);
      await _loadPeople();
    } catch (e) {
      if (mounted) setState(() { _statusMsg = '❌ Delete failed: $e'; _isError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A5C),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Title
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: [
            Icon(Icons.person_add_rounded, color: Color(0xFF4A9EFF), size: 20),
            SizedBox(width: 10),
            Text('Manage People',
                style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ]),
        ),

        // Plain-english explanation
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Add a resident here and upload their face photo. '
                'Once done, the camera will say their name when it detects a fall instead of "Unknown".',
            style: TextStyle(color: Color(0xFF4A7FA8), fontSize: 12),
          ),
        ),
        const SizedBox(height: 14),

        // Status message
        if (_statusMsg != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_isError ? const Color(0xFFFF4040) : const Color(0xFF00DC78))
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (_isError ? const Color(0xFFFF4040) : const Color(0xFF00DC78))
                      .withOpacity(0.3),
                ),
              ),
              child: Text(_statusMsg!,
                  style: TextStyle(
                    color: _isError ? const Color(0xFFFF4040) : const Color(0xFF00DC78),
                    fontSize: 12,
                  )),
            ),
          ),

        // ── Add new person form ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Resident's full name (e.g. John Smith)",
                  hintStyle: const TextStyle(color: Color(0xFF2A4A6A), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF08141F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0F2030)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0F2030)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF4A9EFF)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (v) => _nameInput = v,
                onSubmitted: (_) => _addPerson(),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _saving ? null : _addPerson,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A9EFF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4A9EFF).withOpacity(0.4)),
                ),
                child: _saving
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4A9EFF)))
                    : const Icon(Icons.add_rounded, color: Color(0xFF4A9EFF), size: 20),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 14),

        // ── People list ──────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A9EFF)))
              : _people.isEmpty
              ? const Center(
            child: Text('No people registered yet.\nAdd one above.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF2A4A6A), fontSize: 13)),
          )
              : ListView.separated(
            controller: controller,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            itemCount: _people.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = _people[i];
              final isUploading = _uploadingForId == p.id;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF08141F),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF0F2030)),
                ),
                child: Row(children: [
                  // Avatar circle
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A9EFF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Color(0xFF4A9EFF), fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name + face status
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 3),
                          Row(children: [
                            Icon(
                              p.hasFacePhoto
                                  ? Icons.face_rounded
                                  : Icons.face_retouching_off_rounded,
                              color: p.hasFacePhoto
                                  ? const Color(0xFF00DC78)
                                  : const Color(0xFFFF6B9D),
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              p.hasFacePhoto ? 'Face registered' : 'No face photo',
                              style: TextStyle(
                                color: p.hasFacePhoto
                                    ? const Color(0xFF00DC78)
                                    : const Color(0xFFFF6B9D),
                                fontSize: 11,
                              ),
                            ),
                          ]),
                        ]),
                  ),

                  // Upload face button
                  GestureDetector(
                    onTap: isUploading ? null : () => _uploadFace(p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00DC78).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFF00DC78).withOpacity(0.3)),
                      ),
                      child: isUploading
                          ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF00DC78)))
                          : const Icon(Icons.upload_rounded,
                          color: Color(0xFF00DC78), size: 16),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Delete button
                  GestureDetector(
                    onTap: () => _deletePerson(p),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4040).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFFFF4040).withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFFF4040), size: 16),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),

        const SizedBox(height: 20),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET 2 — CAMERA DETECTION SETTINGS
//
// What each setting does (plain English):
//   fallSensitivity:
//     OFF  = camera never sends fall alerts (useful for testing/maintenance)
//     LOW  = only alerts on very obvious falls (fewer false alarms, may miss real falls)
//     MED  = balanced — recommended for most environments
//     HIGH = alerts on any suspicious posture (more alerts, more false alarms possible)
//
//   aiFilter (ai_fall_alert_filter):
//     ON  = camera's AI double-checks before sending alert — reduces false alarms significantly
//           Requires a paid subscription from AltumView
//     OFF = sends alert immediately on detection
// ═════════════════════════════════════════════════════════════════════════════

class _CameraSettingsSheet extends StatefulWidget {
  final String         accessToken;
  final int            cameraId;
  final CameraSettings current;
  final Function(CameraSettings) onSaved;

  const _CameraSettingsSheet({
    required this.accessToken,
    required this.cameraId,
    required this.current,
    required this.onSaved,
  });

  @override
  State<_CameraSettingsSheet> createState() => _CameraSettingsSheetState();
}

class _CameraSettingsSheetState extends State<_CameraSettingsSheet> {
  late String _sensitivity;
  late bool   _aiFilter;
  bool   _saving  = false;
  String? _msg;
  bool    _isErr  = false;

  @override
  void initState() {
    super.initState();
    _sensitivity = widget.current.fallSensitivity;
    _aiFilter    = widget.current.aiFilter;
  }

  Future<void> _save() async {
    setState(() { _saving = true; _msg = null; });
    try {
      final resp = await http.patch(
        Uri.parse('$_baseApi/cameras/${widget.cameraId}'),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({
          'fall_detection_sensitivity': _sensitivity,
          'ai_fall_alert_filter':       _aiFilter ? 'ON' : 'OFF',
        }),
      );

      log('⚙️ PATCH /cameras/${widget.cameraId} → ${resp.statusCode}  ${resp.body}');

      if (resp.statusCode == 200) {
        final updated = CameraSettings(
          fallSensitivity: _sensitivity,
          aiFilter:        _aiFilter,
          isOnline:        widget.current.isOnline,
          isStreaming:      widget.current.isStreaming,
        );
        widget.onSaved(updated);
        setState(() { _msg = '✅ Settings saved successfully'; _isErr = false; });
      } else {
        setState(() { _msg = '❌ Save failed: ${resp.statusCode} ${resp.body}'; _isErr = true; });
      }
    } catch (e) {
      setState(() { _msg = '❌ Error: $e'; _isErr = true; });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A5C),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: [
            Icon(Icons.tune_rounded, color: Color(0xFFFFD700), size: 20),
            SizedBox(width: 10),
            Text('Detection Settings',
                style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ]),
        ),

        if (_msg != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_isErr ? const Color(0xFFFF4040) : const Color(0xFF00DC78))
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_msg!,
                  style: TextStyle(
                    color: _isErr ? const Color(0xFFFF4040) : const Color(0xFF00DC78),
                    fontSize: 12,
                  )),
            ),
          ),

        // ── Fall Sensitivity ────────────────────────────────────────────────
        _settingBlock(
          label:       'Fall Detection Sensitivity',
          description: 'How aggressively the camera looks for falls.\n'
              'LOW = fewer alerts, fewer false alarms.\n'
              'HIGH = catches more falls but may trigger on normal movements.',
          child: Wrap(spacing: 8, children: ['OFF', 'LOW', 'MED', 'HIGH'].map((opt) {
            final selected = _sensitivity == opt;
            return GestureDetector(
              onTap: () => setState(() => _sensitivity = opt),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFFFD700).withOpacity(0.15)
                      : const Color(0xFF08141F),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFFFD700).withOpacity(0.6)
                        : const Color(0xFF0F2030),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(opt,
                    style: TextStyle(
                      color: selected ? const Color(0xFFFFD700) : const Color(0xFF4A7FA8),
                      fontSize: 13, fontWeight: FontWeight.bold,
                    )),
              ),
            );
          }).toList()),
        ),

        // ── AI Filter ────────────────────────────────────────────────────────
        _settingBlock(
          label:       'AI False-Alert Filter',
          description: 'Requires subscription. When ON, the camera AI double-checks '
              'before sending an alert. Significantly reduces false alarms from '
              'normal activities like bending or sitting quickly.',
          child: Row(children: [
            Switch(
              value:           _aiFilter,
              onChanged:       (v) => setState(() => _aiFilter = v),
              activeColor:     const Color(0xFF00DC78),
              inactiveThumbColor: const Color(0xFF2A4A6A),
              inactiveTrackColor: const Color(0xFF0F2030),
            ),
            const SizedBox(width: 8),
            Text(
              _aiFilter ? 'ON — double-checking before alerting' : 'OFF — alert immediately',
              style: TextStyle(
                color: _aiFilter ? const Color(0xFF00DC78) : const Color(0xFF4A7FA8),
                fontSize: 12,
              ),
            ),
          ]),
        ),

        const SizedBox(height: 10),

        // Save button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                ),
                child: _saving
                    ? const Center(child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        color: Color(0xFFFFD700))))
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.save_rounded, color: Color(0xFFFFD700), size: 16),
                  SizedBox(width: 8),
                  Text('Save Settings',
                      style: TextStyle(color: Color(0xFFFFD700), fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _settingBlock({
    required String label,
    required String description,
    required Widget child,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(description,
              style: const TextStyle(color: Color(0xFF4A7FA8), fontSize: 11)),
          const SizedBox(height: 10),
          child,
          const Divider(color: Color(0xFF0F2030), height: 24),
        ]),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET 3 — HOW TO TEST ALERT FLOW
// ═════════════════════════════════════════════════════════════════════════════

class _TestGuideSheet extends StatelessWidget {
  const _TestGuideSheet();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A5C), borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        const Row(children: [
          Icon(Icons.bug_report_rounded, color: Color(0xFFFF6B9D), size: 20),
          SizedBox(width: 10),
          Text('How to Test Alert Flow',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),

        _step('1', 'Set sensitivity to HIGH',
            'Go to Detection Settings and set Fall Detection Sensitivity to HIGH. '
                'This makes the camera very sensitive so it will alert on any suspicious movement.'),

        _step('2', 'Turn AI Filter OFF',
            'Also in Detection Settings, turn the AI False-Alert Filter OFF. '
                'This ensures every detection immediately creates an alert without double-checking.'),

        _step('3', 'Trigger a detection',
            'Walk in front of the camera and then quickly sit or crouch down. '
                'At HIGH sensitivity, this is enough to trigger a fall detection. '
                'You can also try lying down on the floor briefly.'),

        _step('4', 'Wait 30 seconds',
            'Your app polls every 30 seconds. Within 30 seconds you should see '
                'a push notification on your phone AND the red badge on the Alerts button '
                'will update. This is how the notification flow works automatically.'),

        _step('5', 'Check the Alerts screen',
            'Tap "Fall Alerts" on the dashboard. The new alert will appear at the top '
                'with a red border. Tap it to see the detail screen with the snapshot photo '
                'and resolve buttons.'),

        _step('6', 'Resolve the test alert',
            'On the detail screen, tap "False Alarm" to mark it as resolved. '
                'This removes it from the unresolved queue and the badge count drops.'),

        _step('7', 'Restore settings',
            'After testing, go back to Detection Settings and set sensitivity '
                'back to MED and AI Filter back to ON. This is the recommended '
                'setting for real use.'),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF4A9EFF).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF4A9EFF).withOpacity(0.3)),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Important for testing notifications:',
                style: TextStyle(color: Color(0xFF4A9EFF), fontSize: 12,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(
              '• Your app must be running (background or foreground) for the 30s poll to work.\n'
                  '• On iOS, you must grant notification permission when the app first asks.\n'
                  '• On Android 13+, you must grant notification permission in device settings.\n'
                  '• Notifications only fire for NEW alert IDs not seen before in this app session.',
              style: TextStyle(color: Color(0xFF2A6FAA), fontSize: 11, height: 1.6),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _step(String num, String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B9D).withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFF6B9D).withOpacity(0.4)),
        ),
        child: Center(
          child: Text(num,
              style: const TextStyle(color: Color(0xFFFF6B9D), fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(body,
              style: const TextStyle(color: Color(0xFF4A7FA8), fontSize: 12, height: 1.5)),
        ]),
      ),
    ]),
  );
}