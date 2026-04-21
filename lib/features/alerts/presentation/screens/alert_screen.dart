// ─────────────────────────────────────────────────────────────────────────────
// features/alerts/presentation/screens/alerts_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/alerts/domain/models/alert_model.dart';
import 'package:altum_view_sdk/features/alerts/presentation/controller/alert_provider.dart';
import 'package:altum_view_sdk/shared/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:altum_view_sdk/core/state/view_state.dart';

class AlertsScreen extends StatefulWidget {
  final int? cameraId;
  const AlertsScreen({super.key, this.cameraId});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _unresolvedOnly = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      setState(() => _unresolvedOnly = _tabs.index == 0);
      _load();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    context.read<AlertProvider>().loadAlerts(
      unresolvedOnly: _unresolvedOnly,
      resolvedOnly: !_unresolvedOnly,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Alerts',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.chevron_back, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<AlertProvider>(
            builder: (context, provider, _) {
              if (provider.alerts.isEmpty) return const SizedBox.shrink();
              return CupertinoButton(
                padding: const EdgeInsets.only(right: 16),
                child: const Text('Resolve All',
                    style: TextStyle(color: AppTheme.error, fontSize: 15)),
                onPressed: () => _confirmResolveAll(context, provider),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.onSurfaceSub,
          tabs: const [
            Tab(text: 'Unresolved'),
            Tab(text: 'Resolved'),
          ],
        ),
      ),
      body: Consumer<AlertProvider>(
        builder: (context, provider, _) {
          if (provider.alertsState is LoadingState) {
            return const Center(
                child:
                CircularProgressIndicator(color: AppTheme.primary));
          }

          if (provider.alertsState is ErrorState) {
            return EmptyState(
              icon: CupertinoIcons.exclamationmark_triangle,
              title: 'Failed to load alerts',
              subtitle:
              (provider.alertsState as ErrorState).message,
              buttonLabel: 'Retry',
              onButton: _load,
            );
          }

          if (provider.alerts.isEmpty) {
            return EmptyState(
              icon: CupertinoIcons.bell_slash,
              title: _unresolvedOnly
                  ? 'No Unresolved Alerts'
                  : 'No Resolved Alerts',
              subtitle: _unresolvedOnly
                  ? 'All clear! No alerts need your attention.'
                  : 'Resolved alerts will appear here.',
            );
          }

          return RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surfaceCard,
            onRefresh: () async => _load,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.alerts.length,
              itemBuilder: (context, i) {
                final alert = provider.alerts[i];
                return _AlertTile(
                  alert: alert,
                  onTap: () =>
                      _showAlertDetail(context, provider, alert),
                  onResolve: _unresolvedOnly
                      ? () => _showResolveSheet(
                      context, provider, alert)
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showAlertDetail(
      BuildContext context, AlertProvider provider, AlertModel alert) {
    provider.loadAlertDetail(alert.id);
    showAppBottomSheet(
      context: context,
      title: alert.eventLabel ?? 'Alert Detail',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Consumer<AlertProvider>(
          builder: (context, p, _) {
            if (p.detailState is LoadingState) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child:
                Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'Person', value: alert.personName ?? '—'),
                _DetailRow(label: 'Event', value: alert.eventLabel ?? '—'),
                _DetailRow(
                    label: 'Time',
                    value: alert.timestamp.toString() ?? '—'),
                if (_unresolvedOnly) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showResolveSheet(context, p, alert);
                      },
                      child: const Text('Resolve Alert'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showResolveSheet(
      BuildContext context, AlertProvider provider, AlertModel alert) {
    bool isTrueAlert = false;
    bool isFalseAlert = false;
    final commentCtrl = TextEditingController();

    showAppBottomSheet(
      context: context,
      title: 'Resolve Alert',
      child: StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              // True / False radio
              Row(
                children: [
                  Expanded(
                    child: _ToggleChip(
                      label: '✅ True Alert',
                      selected: isTrueAlert,
                      onTap: () => setS(
                              () {isTrueAlert = true; isFalseAlert = false;}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ToggleChip(
                      label: '❌ False Alert',
                      selected: isFalseAlert,
                      onTap: () => setS(
                              () {isFalseAlert = true; isTrueAlert = false;}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: commentCtrl,
                style: const TextStyle(color: AppTheme.onSurface),
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Add a comment (optional)',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await provider.resolveAlert(
                      alertId: alert.id,
                      isTrueAlert: isTrueAlert,
                      isFalseAlert: isFalseAlert,
                      comment: commentCtrl.text.trim().isEmpty
                          ? null
                          : commentCtrl.text.trim(),
                    );
                  },
                  child: const Text('Confirm Resolve'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmResolveAll(BuildContext context, AlertProvider provider) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Resolve All Alerts'),
        content: const Text(
            'This will mark all current alerts as resolved. This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              provider.resolveAllAlerts();
            },
            child: const Text('Resolve All'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

// ── Alert Tile ───────────────────────────────────────────────────────────────

class _AlertTile extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback onTap;
  final VoidCallback? onResolve;

  const _AlertTile({
    required this.alert,
    required this.onTap,
    this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(CupertinoIcons.bell_fill,
                    color: AppTheme.warning, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.eventLabel ?? 'Alert',
                      style: const TextStyle(
                        color: AppTheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      alert.personName ?? 'Unknown person',
                      style: const TextStyle(
                        color: AppTheme.onSurfaceSub,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (onResolve != null)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onResolve,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Resolve',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.onSurfaceSub, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withOpacity(0.2)
              : AppTheme.surfaceCard2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppTheme.primary : AppTheme.onSurfaceSub,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}