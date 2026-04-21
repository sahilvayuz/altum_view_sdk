// ─────────────────────────────────────────────────────────────────────────────
// features/people_groups/presentation/screens/person_groups_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/people_groups/presentation/controller/person_group_provider.dart';
import 'package:altum_view_sdk/shared/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../domain/models/person_group_model.dart';
import 'package:altum_view_sdk/core/state/view_state.dart';

class PersonGroupsScreen extends StatefulWidget {
  const PersonGroupsScreen({super.key});

  @override
  State<PersonGroupsScreen> createState() => _PersonGroupsScreenState();
}

class _PersonGroupsScreenState extends State<PersonGroupsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PersonGroupProvider>().loadGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('People Groups',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.chevron_back, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(CupertinoIcons.plus_circle_fill,
                color: AppTheme.primary, size: 26),
            onPressed: () => _showAddGroupSheet(context),
          ),
        ],
      ),
      body: Consumer<PersonGroupProvider>(
        builder: (context, provider, _) {
          if (provider.groupsState is LoadingState) {
            return const Center(
                child:
                CircularProgressIndicator(color: AppTheme.primary));
          }
          if (provider.groups.isEmpty) {
            return EmptyState(
              icon: CupertinoIcons.person_2_fill,
              title: 'No Groups Yet',
              subtitle: 'Create groups to categorise people.',
              buttonLabel: 'Create Group',
              onButton: () => _showAddGroupSheet(context),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            itemCount: provider.groups.length,
            itemBuilder: (context, i) {
              final group = provider.groups[i];
              return _GroupTile(
                group: group,
                onEdit: () => _showEditGroupSheet(context, provider, group),
                onDelete: () =>
                    _confirmDelete(context, provider, group),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddGroupSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    PersonGroupType selectedType = PersonGroupType.senior;

    showAppBottomSheet(
      context: context,
      title: 'New Group',
      child: StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: AppTheme.onSurface),
                decoration: const InputDecoration(
                  hintText: 'Group name',
                  prefixIcon: Icon(CupertinoIcons.person_2,
                      color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Group Type',
                  style: TextStyle(
                      color: AppTheme.onSurfaceSub, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: PersonGroupType.values.map((type) {
                  final isSelected = selectedType == type;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setS(() => selectedType = type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withOpacity(0.2)
                                : AppTheme.surfaceCard2,
                            borderRadius:
                            BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              type.name.capitalize(),
                              style: TextStyle(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.onSurfaceSub,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(context);
                    await context.read<PersonGroupProvider>().createGroup(
                      name: name,
                      type: selectedType,
                    );
                  },
                  child: const Text('Create Group'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditGroupSheet(
      BuildContext context, PersonGroupProvider provider, PersonGroupModel group) {
    final nameCtrl = TextEditingController(text: group.name);

    showAppBottomSheet(
      context: context,
      title: 'Edit Group',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: AppTheme.onSurface),
              decoration: const InputDecoration(
                prefixIcon: Icon(CupertinoIcons.pencil,
                    color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(context);
                  await provider.updateGroup(id: group.id, name: name);
                },
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, PersonGroupProvider provider,
      PersonGroupModel group) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Group'),
        content: Text('Delete "${group.name}"? Members will be unassigned.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              provider.deleteGroup(group.id);
            },
            child: const Text('Delete'),
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

// ── Group Tile ────────────────────────────────────────────────────────────────

class _GroupTile extends StatelessWidget {
  final PersonGroupModel group;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GroupTile({
    required this.group,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                color: _typeColor(group.type).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(CupertinoIcons.person_2_fill,
                  color: _typeColor(group.type), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      color: AppTheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    group.type?.name.capitalize() ?? 'Standard',
                    style: const TextStyle(
                      color: AppTheme.onSurfaceSub,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              color: AppTheme.surfaceCard2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              icon: const Icon(CupertinoIcons.ellipsis,
                  color: AppTheme.onSurfaceSub),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(CupertinoIcons.pencil,
                        color: AppTheme.primary, size: 18),
                    SizedBox(width: 10),
                    Text('Edit', style: TextStyle(color: AppTheme.onSurface)),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(CupertinoIcons.trash,
                        color: AppTheme.error, size: 18),
                    SizedBox(width: 10),
                    Text('Delete', style: TextStyle(color: AppTheme.error)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(PersonGroupType? type) {
    switch (type) {
      case PersonGroupType.senior:
        return AppTheme.warning;
      case PersonGroupType.staff:
        return AppTheme.primary;
      default:
        return AppTheme.success;
    }
  }
}

extension StringExt on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}