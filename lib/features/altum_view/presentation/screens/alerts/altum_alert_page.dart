// ─────────────────────────────────────────────────────────────────────────────
// altum_alert_page.dart  —  UPDATED to match corrected service
//
// Changes from previous version:
//   • Uses AltumAlert.eventLabel instead of actionType
//   • Uses AltumAlertDetail.alert instead of .summary
//   • Adds filter sheet matching official AltumView app (all 6 event types)
//   • Adds "Resolve All" button matching official app
//   • Adds third resolve option: "Acknowledge" (no true/false, just resolve)
//   • Corrected timestamp display (was failing silently before)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:typed_data';

import 'package:altum_view_sdk/features/altum_view/services/altum_alert_service.dart';
import 'package:flutter/material.dart';

// Adjust path to match your project

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN 1 — ALERTS LIST
// ═════════════════════════════════════════════════════════════════════════════

class AltumAlertsPage extends StatefulWidget {
  final String accessToken;
  const AltumAlertsPage({super.key, required this.accessToken});

  @override
  State<AltumAlertsPage> createState() => _AltumAlertsPageState();
}

class _AltumAlertsPageState extends State<AltumAlertsPage> {
  late final AltumAlertService _service;

  List<AltumAlert> _alerts    = [];
  bool             _loading   = true;
  String?          _error;

  // Filter state — mirrors official AltumView app filter sheet
  Set<int> _activeEventTypes = {1, 2, 3, 4, 5, 10, 11}; // all by default
  bool     _showResolved      = true;
  bool     _showUnresolved    = true;
  bool     _sortByDate        = true; // true=Date, false=Unresolved first

  @override
  void initState() {
    super.initState();
    _service = AltumAlertService(accessToken: widget.accessToken);
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final all = await _service.getAlerts(
        eventTypes:   _activeEventTypes.toList(),
        unresolvedOnly:  _showUnresolved && !_showResolved,
        resolvedOnly:    _showResolved && !_showUnresolved,
        // both = show all (default)
      );

      if (!mounted) return;

      // Sort
      all.sort((a, b) => _sortByDate
          ? b.unixTime.compareTo(a.unixTime)           // newest first
          : (a.isResolved ? 1 : 0).compareTo(b.isResolved ? 1 : 0)); // unresolved first

      setState(() { _alerts = all; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _resolveAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF08141F),
        title: const Text('Resolve All?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This marks all unresolved alerts as resolved. This cannot be undone.',
          style: TextStyle(color: Color(0xFF4A7FA8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF4A7FA8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resolve All', style: TextStyle(color: Color(0xFFFF4040))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.resolveAllAlerts();
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[900]),
        );
      }
    }
  }

  void _openFilter() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        activeEventTypes: _activeEventTypes,
        showResolved:     _showResolved,
        showUnresolved:   _showUnresolved,
        sortByDate:       _sortByDate,
      ),
    );
    if (result != null) {
      setState(() {
        _activeEventTypes = result.eventTypes;
        _showResolved     = result.showResolved;
        _showUnresolved   = result.showUnresolved;
        _sortByDate       = result.sortByDate;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unresolved = _alerts.where((a) => !a.isResolved).length;

    return Scaffold(
      backgroundColor: const Color(0xFF07101E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07101E),
        foregroundColor: const Color(0xFF4A7FA8),
        title: Row(children: [
          const Text('Fall Alerts',
              style: TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          if (unresolved > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFFFF4040),
                  borderRadius: BorderRadius.circular(12)),
              child: Text('$unresolved',
                  style: const TextStyle(color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
        ]),
        actions: [
          // Filter button — matches official app gear icon
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Color(0xFF4A7FA8)),
            onPressed: _openFilter,
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4A7FA8)),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00DC78)))
          : _error != null
          ? _errorView()
          : _alerts.isEmpty
          ? _emptyView()
          : Column(children: [
        // Resolve All bar — only shown when there are unresolved
        if (unresolved > 0) _resolveAllBar(unresolved),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: const Color(0xFF00DC78),
            child: ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: _alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _AlertCard(
                alert: _alerts[i],
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AltumAlertDetailPage(
                      alertId:     _alerts[i].id,
                      accessToken: widget.accessToken,
                    ),
                  ));
                  _load();
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _resolveAllBar(int count) => Container(
    color: const Color(0xFF08141F),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      Text('$count unresolved',
          style: const TextStyle(color: Color(0xFF4A7FA8), fontSize: 12)),
      const Spacer(),
      GestureDetector(
        onTap: _resolveAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFF4040).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFFF4040).withOpacity(0.4)),
          ),
          child: const Text('Resolve All',
              style: TextStyle(color: Color(0xFFFF4040), fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    ]),
  );

  Widget _errorView() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.cloud_off_rounded, color: Color(0xFFFF4040), size: 48),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(_error ?? '', style: const TextStyle(color: Color(0xFF4A2020)),
            textAlign: TextAlign.center),
      ),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: _load, child: const Text('Retry')),
    ]),
  );

  Widget _emptyView() => const Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.notifications_off_outlined, color: Color(0xFF1A3A5C), size: 48),
      SizedBox(height: 16),
      Text('No alerts yet', style: TextStyle(color: Color(0xFF2A4A6A), fontSize: 14)),
      SizedBox(height: 8),
      Text('Alerts will appear here when the camera\ndetects a fall or other event',
          style: TextStyle(color: Color(0xFF1A3A5C), fontSize: 12),
          textAlign: TextAlign.center),
    ]),
  );
}

// ─── Alert card ───────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final AltumAlert   alert;
  final VoidCallback onTap;
  const _AlertCard({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnresolved = !alert.isResolved;
    final color = isUnresolved ? const Color(0xFFFF4040) : const Color(0xFF2A4A6A);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF08141F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isUnresolved
                ? const Color(0xFFFF4040).withOpacity(0.4)
                : const Color(0xFF0F2030),
            width: isUnresolved ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          // Event type icon box
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_eventIcon(alert.eventType), color: color, size: 20),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Event label
              Text(alert.eventLabel,
                  style: TextStyle(color: color, fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              // Person name
              Text(alert.personName,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              const SizedBox(height: 2),
              // Camera + time
              Text('${alert.cameraName}  •  ${_formatTime(alert.timestamp)}',
                  style: const TextStyle(color: Color(0xFF2A4A6A), fontSize: 11)),
            ]),
          ),

          // Status badge
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (alert.isTrueAlert)
              _badge('CONFIRMED', const Color(0xFFFF4040))
            else if (alert.isFalseAlert)
              _badge('FALSE ALARM', const Color(0xFF2A6FAA))
            else if (alert.isResolved)
                _badge('RESOLVED', const Color(0xFF2A4A6A))
              else
                _badge('UNRESOLVED', const Color(0xFFFF4040)),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF2A4A6A), size: 18),
          ]),
        ]),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold,
            letterSpacing: 0.8)),
  );

  IconData _eventIcon(int eventType) {
    switch (eventType) {
      case AltumEventType.fall:       return Icons.warning_amber_rounded;
      case AltumEventType.restricted: return Icons.block_rounded;
      case AltumEventType.fight:      return Icons.sports_mma_rounded;
      case AltumEventType.fire:       return Icons.local_fire_department_rounded;
      case AltumEventType.handWave:   return Icons.back_hand_rounded;
      case AltumEventType.overstay:   return Icons.timer_rounded;
      case AltumEventType.absence:    return Icons.person_off_rounded;
      default:                        return Icons.notifications_rounded;
    }
  }

  String _formatTime(DateTime t) {
    final now  = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${t.day}/${t.month}/${t.year}';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FILTER SHEET — matches official AltumView app filter UI
// ═════════════════════════════════════════════════════════════════════════════

class _FilterResult {
  final Set<int> eventTypes;
  final bool     showResolved;
  final bool     showUnresolved;
  final bool     sortByDate;
  _FilterResult({
    required this.eventTypes,
    required this.showResolved,
    required this.showUnresolved,
    required this.sortByDate,
  });
}

class _FilterSheet extends StatefulWidget {
  final Set<int> activeEventTypes;
  final bool     showResolved;
  final bool     showUnresolved;
  final bool     sortByDate;

  const _FilterSheet({
    required this.activeEventTypes,
    required this.showResolved,
    required this.showUnresolved,
    required this.sortByDate,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<int> _eventTypes;
  late bool     _showResolved;
  late bool     _showUnresolved;
  late bool     _sortByDate;

  static const _eventDefs = [
    (type: AltumEventType.fall,       label: 'Fall',       icon: Icons.warning_amber_rounded),
    (type: AltumEventType.restricted, label: 'Restricted', icon: Icons.block_rounded),
    (type: AltumEventType.handWave,   label: 'Help',       icon: Icons.back_hand_rounded),
    (type: AltumEventType.overstay,   label: 'Overstayed', icon: Icons.timer_rounded),
    (type: AltumEventType.absence,    label: 'Absent',     icon: Icons.person_off_rounded),
    (type: AltumEventType.fire,       label: 'Bed Exit',   icon: Icons.single_bed_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _eventTypes    = Set.from(widget.activeEventTypes);
    _showResolved  = widget.showResolved;
    _showUnresolved = widget.showUnresolved;
    _sortByDate    = widget.sortByDate;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Show by Event Type',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Event type checkboxes — matches official app exactly
            ..._eventDefs.map((def) => CheckboxListTile(
              value:       _eventTypes.contains(def.type),
              onChanged:   (v) => setState(() {
                if (v == true) _eventTypes.add(def.type);
                else            _eventTypes.remove(def.type);
              }),
              title:       Text(def.label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              secondary:   Icon(def.icon, color: Colors.blue),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: Colors.blue,
            )),

            const Divider(height: 24),
            const Text('Sort By', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Sort options — matches official app
            Row(children: [
              _sortOption('Date',       selected: _sortByDate,
                  onTap: () => setState(() => _sortByDate = true)),
              const SizedBox(width: 24),
              _sortOption('Unresolved', selected: !_sortByDate,
                  onTap: () => setState(() => _sortByDate = false)),
            ]),

            const SizedBox(height: 24),

            // Cancel / Accept / Resolve All — matches official app
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, null),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _FilterResult(
                    eventTypes:    _eventTypes,
                    showResolved:  _showResolved,
                    showUnresolved: _showUnresolved,
                    sortByDate:    _sortByDate,
                  )),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Accept', style: TextStyle(color: Colors.white)),
                ),
              ),
            ]),

            // Resolve All text button — matches official app
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, _FilterResult(
                  eventTypes:    _eventTypes,
                  showResolved:  true,
                  showUnresolved: true,
                  sortByDate:    _sortByDate,
                )),
                child: const Text('Resolve All', style: TextStyle(color: Colors.blue)),
              ),
            ),
          ]),
    );
  }

  Widget _sortOption(String label, {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Icon(
          selected ? Icons.keyboard_arrow_up_rounded : Icons.remove,
          color: selected ? Colors.blue : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
              fontSize: 15,
              color: selected ? Colors.blue : Colors.grey,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            )),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN 2 — ALERT DETAIL
// ═════════════════════════════════════════════════════════════════════════════

class AltumAlertDetailPage extends StatefulWidget {
  final String alertId;
  final String accessToken;

  const AltumAlertDetailPage({
    super.key,
    required this.alertId,
    required this.accessToken,
  });

  @override
  State<AltumAlertDetailPage> createState() => _AltumAlertDetailPageState();
}

class _AltumAlertDetailPageState extends State<AltumAlertDetailPage> {
  late final AltumAlertService _service;
  AltumAlertDetail? _detail;
  bool    _loading   = true;
  String? _error;
  bool    _resolving = false;

  @override
  void initState() {
    super.initState();
    _service = AltumAlertService(accessToken: widget.accessToken);
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final detail = await _service.getAlertById(widget.alertId);
      if (mounted) setState(() { _detail = detail; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── THREE resolve options ─────────────────────────────────────────────────
  // 1. Real Fall (is_true_alert=true)
  // 2. False Alarm (is_false_alert=true)
  // 3. Acknowledge only (neither flag — just resolves it)

  Future<void> _resolve({
    bool   isTrueAlert  = false,
    bool   isFalseAlert = false,
    String label        = 'Resolved',
  }) async {
    if (_resolving) return;

    // Optional: ask for a comment
    String? comment;
    if (isTrueAlert) {
      comment = await _promptComment(context, hint: 'Notes (e.g. called ambulance)');
    }

    setState(() => _resolving = true);
    try {
      await _service.resolveAlert(
        alertId:     widget.alertId,
        isTrueAlert: isTrueAlert,
        isFalseAlert: isFalseAlert,
        comment:     comment,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Marked as $label'),
            backgroundColor: isTrueAlert
                ? Colors.red[800]
                : isFalseAlert
                ? Colors.blue[800]
                : Colors.green[800],
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[900]),
        );
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<String?> _promptComment(BuildContext context, {String hint = ''}) async {
    String comment = '';
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add comment (optional)'),
        content: TextField(
          decoration: InputDecoration(hintText: hint),
          onChanged: (v) => comment = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null),
              child: const Text('Skip')),
          TextButton(onPressed: () => Navigator.pop(context, comment),
              child: const Text('Add')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07101E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07101E),
        foregroundColor: const Color(0xFF4A7FA8),
        title: const Text('Alert Detail',
            style: TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00DC78)))
          : _error != null
          ? Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              style: const TextStyle(color: Color(0xFF4A2020)),
              textAlign: TextAlign.center)))
          : _buildDetail(),
    );
  }

  Widget _buildDetail() {
    final d = _detail!;
    final a = d.alert; // CORRECTED field name

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Snapshot image
        if (d.backgroundUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              d.backgroundUrl!,
              width: double.infinity, height: 200, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 200, color: const Color(0xFF0A1828),
                child: const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Color(0xFF2A4A6A), size: 48),
                ),
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Info card
        _infoCard(children: [
          _infoRow('Event',     a.eventLabel),  // uses corrected field
          _infoRow('Person',    a.personName),
          _infoRow('Camera',    a.cameraName),
          _infoRow('Room',      a.roomName),
          _infoRow('Time',      _fullTime(a.timestamp)),
          _infoRow('Status',
              a.isTrueAlert  ? 'Confirmed Real Event' :
              a.isFalseAlert ? 'False Alarm' :
              a.isResolved   ? 'Resolved' : 'UNRESOLVED'),
          if (a.resolvedBy != null)
            _infoRow('Resolved by', a.resolvedBy!),
        ]),

        const SizedBox(height: 16),

        // Skeleton file indicator
        if (d.skeletonFileB64 != null)
          _infoCard(children: [
            Row(children: [
              const Icon(Icons.animation_rounded, color: Color(0xFF00DC78), size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Skeleton animation available',
                    style: TextStyle(color: Color(0xFF00DC78), fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              'Size: ${(base64Decode(d.skeletonFileB64!).length / 1024).toStringAsFixed(1)} KB',
              style: const TextStyle(color: Color(0xFF2A4A6A), fontSize: 11),
            ),
            // Uncomment when ready:
            // AltumAlertSkeletonPlayer(skeletonBytes: base64Decode(d.skeletonFileB64!))
          ]),

        const SizedBox(height: 24),

        // Resolve buttons — only show if not yet resolved
        if (!a.isResolved) ...[
          const Text('REVIEW THIS ALERT',
              style: TextStyle(color: Color(0xFF2A4A6A), fontSize: 11,
                  fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 10),

          // Real Fall button
          _resolveButton(
            label:   'Real Fall — Needed Attention',
            icon:    Icons.warning_amber_rounded,
            color:   const Color(0xFFFF4040),
            loading: _resolving,
            onTap:   () => _resolve(isTrueAlert: true, label: 'Real Fall'),
          ),
          const SizedBox(height: 8),

          // False Alarm button
          _resolveButton(
            label:   'False Alarm — No Action Needed',
            icon:    Icons.check_circle_outline_rounded,
            color:   const Color(0xFF4A9EFF),
            loading: _resolving,
            onTap:   () => _resolve(isFalseAlert: true, label: 'False Alarm'),
          ),
          const SizedBox(height: 8),

          // Acknowledge button (no category)
          _resolveButton(
            label:   'Acknowledge — Already Handled',
            icon:    Icons.done_rounded,
            color:   const Color(0xFF00DC78),
            loading: _resolving,
            onTap:   () => _resolve(label: 'Acknowledged'),
          ),
        ],

        // SIP call button
        if (d.isCallAvailable && d.sipUsername != null) ...[
          const SizedBox(height: 16),
          _resolveButton(
            label:   'Call Camera (2-Way Audio)',
            icon:    Icons.call_rounded,
            color:   const Color(0xFFFFD700),
            loading: false,
            onTap:   () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('SIP: ${d.sipUsername}')),
            ),
          ),
        ],

        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _infoCard({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF08141F),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF0F2030)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      SizedBox(
        width: 100,
        child: Text(label,
            style: const TextStyle(color: Color(0xFF2A4A6A), fontSize: 12)),
      ),
      Expanded(
        child: Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.w500)),
      ),
    ]),
  );

  Widget _resolveButton({
    required String   label,
    required IconData icon,
    required Color    color,
    required bool     loading,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: loading
          ? Center(child: SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: color)))
          : Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(color: color, fontSize: 12,
                fontWeight: FontWeight.bold)),
      ]),
    ),
  );

  String _fullTime(DateTime t) {
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${t.day}/${t.month}/${t.year}  ${pad(t.hour)}:${pad(t.minute)}:${pad(t.second)}';
  }
}