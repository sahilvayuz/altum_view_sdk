// ─────────────────────────────────────────────────────────────────────────────
// features/people/presentation/screens/people_screen.dart
// Full CRUD: list, add (with face photo + group), delete.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/people/domain/models/person_model.dart';
import 'package:altum_view_sdk/features/people/presentation/controller/person_provider.dart';
import 'package:altum_view_sdk/features/people_groups/presentation/controller/person_group_provider.dart';
import 'package:altum_view_sdk/features/people_groups/presentation/screens/person_group_screen.dart';
import 'package:altum_view_sdk/shared/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:altum_view_sdk/core/state/view_state.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PersonProvider>().loadPeople();
      context.read<PersonGroupProvider>().loadGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            backgroundColor: AppTheme.background,
            flexibleSpace: const FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'People',
                style: TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            actions: [
              CupertinoButton(
                padding: const EdgeInsets.only(right: 8),
                child: const Text('Groups',
                    style: TextStyle(color: AppTheme.primary)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PersonGroupsScreen()),
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(CupertinoIcons.person_badge_plus_fill,
                    color: AppTheme.primary, size: 26),
                onPressed: () => _showAddPersonSheet(context),
              ),
            ],
          ),
          Consumer<PersonProvider>(
            builder: (context, provider, _) {
              if (provider.peopleState is LoadingState) {
                return const SliverFillRemaining(
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary)),
                );
              }
              if (provider.people.isEmpty) {
                return SliverFillRemaining(
                  child: EmptyState(
                    icon: CupertinoIcons.person_2,
                    title: 'No People Yet',
                    subtitle:
                    'Add people to enable face recognition alerts.',
                    buttonLabel: 'Add Person',
                    onButton: () => _showAddPersonSheet(context),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, i) => _PersonTile(
                    person: provider.people[i],
                    onDelete: () => provider
                        .deletePerson(provider.people[i].id),
                    onUploadPhoto: () =>
                        _pickAndUploadPhoto(context, provider, provider.people[i]),
                  ),
                  childCount: provider.people.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddPersonSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    int? selectedGroupId;
    Uint8List? faceBytes;

    showAppBottomSheet(
      context: context,
      title: 'Add Person',
      child: StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              // Face photo picker
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final xfile = await picker.pickImage(
                      source: ImageSource.camera, imageQuality: 80);
                  if (xfile == null) return;
                  final bytes = await xfile.readAsBytes();
                  setS(() => faceBytes = bytes);
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard2,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.4), width: 2),
                  ),
                  child: faceBytes != null
                      ? ClipOval(
                      child: Image.memory(faceBytes!, fit: BoxFit.cover))
                      : const Icon(CupertinoIcons.camera_fill,
                      color: AppTheme.primary, size: 28),
                ),
              ),
              const SizedBox(height: 4),
              const Text('Tap to add face photo',
                  style: TextStyle(
                      color: AppTheme.onSurfaceSub, fontSize: 12)),
              const SizedBox(height: 16),

              // Name field
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: AppTheme.onSurface),
                decoration: const InputDecoration(
                  hintText: 'Full name',
                  prefixIcon: Icon(CupertinoIcons.person,
                      color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 12),

              // Group selector
              Consumer<PersonGroupProvider>(
                builder: (ctx, gProvider, _) {
                  if (gProvider.groups.isEmpty)
                    return const SizedBox.shrink();
                  return DropdownButtonFormField<int>(
                    value: selectedGroupId,
                    dropdownColor: AppTheme.surfaceCard,
                    style: const TextStyle(
                        color: AppTheme.onSurface, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Select group (optional)',
                      prefixIcon: Icon(CupertinoIcons.person_2,
                          color: AppTheme.primary),
                    ),
                    items: gProvider.groups
                        .map((g) => DropdownMenuItem(
                      value: g.id,
                      child: Text(g.name),
                    ))
                        .toList(),
                    onChanged: (v) => setS(() => selectedGroupId = v),
                  );
                },
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(context);
                    await context.read<PersonProvider>().createPerson(
                      friendlyName: name,
                      groupId: selectedGroupId,
                      faceImageBytes: faceBytes,
                    );
                  },
                  child: const Text('Add Person'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(
      BuildContext context, PersonProvider provider, PersonModel person) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    await provider.uploadFacePhoto(
        personId: person.id, imageBytes: bytes);
  }
}

// ── Person Tile ───────────────────────────────────────────────────────────────

class _PersonTile extends StatelessWidget {
  final PersonModel person;
  final VoidCallback onDelete;
  final VoidCallback onUploadPhoto;

  const _PersonTile({
    required this.person,
    required this.onDelete,
    required this.onUploadPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: person.profileImageUrl != null
                  ? ClipOval(
                  child: Image.network(person.profileImageUrl!,
                      fit: BoxFit.cover))
                  : const Icon(CupertinoIcons.person_fill,
                  color: AppTheme.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: const TextStyle(
                      color: AppTheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (person.groupName != null)
                    Text(
                      person.groupName!,
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
                if (v == 'photo') onUploadPhoto();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'photo',
                  child: Row(children: [
                    Icon(CupertinoIcons.photo, color: AppTheme.primary, size: 18),
                    SizedBox(width: 10),
                    Text('Update Photo',
                        style: TextStyle(color: AppTheme.onSurface)),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(CupertinoIcons.trash, color: AppTheme.error, size: 18),
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
}