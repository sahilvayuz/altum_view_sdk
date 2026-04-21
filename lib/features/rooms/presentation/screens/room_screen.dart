// ─────────────────────────────────────────────────────────────────────────────
// features/rooms/presentation/screens/rooms_screen.dart
//
// Lists all rooms. Tap → DevicesScreen. FAB → add room sheet.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/camera/presentation/screens/camera_screen.dart';
import 'package:altum_view_sdk/features/rooms/presentation/controllers/room_provider.dart';
import 'package:altum_view_sdk/shared/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:altum_view_sdk/core/state/view_state.dart';
import '../../../rooms/domain/models/room_model.dart';


class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoomProvider>().loadRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── Large title app bar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: AppTheme.background,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text(
                'Rooms',
                style: TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(CupertinoIcons.plus_circle_fill,
                    color: AppTheme.primary, size: 28),
                onPressed: () => _showAddRoomSheet(context),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Consumer<RoomProvider>(
            builder: (context, provider, _) {
              if (provider.roomState is LoadingState) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                );
              }

              if (provider.roomState is ErrorState) {
                final msg =
                    (provider.roomState as ErrorState).message;
                return SliverFillRemaining(
                  child: EmptyState(
                    icon: CupertinoIcons.exclamationmark_circle,
                    title: 'Something went wrong',
                    subtitle: msg,
                    buttonLabel: 'Retry',
                    onButton: provider.loadRooms,
                  ),
                );
              }

              if (provider.rooms.isEmpty) {
                return SliverFillRemaining(
                  child: EmptyState(
                    icon: CupertinoIcons.house,
                    title: 'No Rooms Yet',
                    subtitle:
                    'Add a room to start organising your cameras.',
                    buttonLabel: 'Add Room',
                    onButton: () => _showAddRoomSheet(context),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, i) {
                    final room = provider.rooms[i];
                    return _RoomTile(
                      room: room,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DevicesScreen(room: room),
                        ),
                      ),
                      onEdit: () => _showEditRoomSheet(context, room),
                      onDelete: () => _confirmDelete(context, provider, room),
                    );
                  },
                  childCount: provider.rooms.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Add room bottom sheet ─────────────────────────────────────────────────

  void _showAddRoomSheet(BuildContext context) {
    final ctrl = TextEditingController();
    showAppBottomSheet(
      context: context,
      title: 'New Room',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: AppTheme.onSurface),
              decoration: const InputDecoration(
                hintText: 'Room name (e.g. Living Room)',
                prefixIcon: Icon(CupertinoIcons.house, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final name = ctrl.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(context);
                  await context.read<RoomProvider>().createRoom(name);
                },
                child: const Text('Create Room'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit room bottom sheet ────────────────────────────────────────────────

  void _showEditRoomSheet(BuildContext context, RoomModel room) {
    final ctrl = TextEditingController(text: room.name);
    showAppBottomSheet(
      context: context,
      title: 'Rename Room',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: AppTheme.onSurface),
              decoration: const InputDecoration(
                prefixIcon: Icon(CupertinoIcons.pencil, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final name = ctrl.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(context);
                  await context
                      .read<RoomProvider>()
                      .updateRoom(room.id, name);
                },
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete confirmation ───────────────────────────────────────────────────

  void _confirmDelete(
      BuildContext context, RoomProvider provider, RoomModel room) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Room'),
        content: Text(
            'Are you sure you want to delete "${room.name}"? All cameras in this room will be unassigned.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              provider.deleteRoom(room.id);
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

// ── Room Tile ─────────────────────────────────────────────────────────────

class _RoomTile extends StatelessWidget {
  final RoomModel room;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoomTile({
    required this.room,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
              // ── Icon ─────────────────────────────────────────────────────
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(CupertinoIcons.house_fill,
                    color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 14),

              // ── Info ──────────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(
                        color: AppTheme.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${room.cameraCount ?? 0} camera${(room.cameraCount ?? 0) == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppTheme.onSurfaceSub,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Actions ──────────────────────────────────────────────────
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
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.pencil, color: AppTheme.primary, size: 18),
                        SizedBox(width: 10),
                        Text('Rename', style: TextStyle(color: AppTheme.onSurface)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.trash, color: AppTheme.error, size: 18),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: AppTheme.error)),
                      ],
                    ),
                  ),
                ],
              ),

              const Icon(CupertinoIcons.chevron_right,
                  color: AppTheme.onSurfaceSub, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}