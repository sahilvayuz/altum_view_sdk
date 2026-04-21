// ─────────────────────────────────────────────────────────────────────────────
// app/presentation/shell/main_shell.dart
//
// Root scaffold after login. Bottom navigation with 4 tabs:
//   0. Rooms   (→ Devices → BLE scan → Name → WiFi → Camera detail → …)
//   1. Alerts
//   2. People  (→ Person groups)
//   3. Profile / logout
//
// MultiProvider lives in bootstrap.dart (root of the tree) using lazy
// create: lambdas, so every pushed route inherits all providers automatically.
//
// This widget's only DI job is to call ServiceLocator.init(token) in
// initState() — BEFORE any provider is first read — so all late fields
// are guaranteed to be set when the lazy create: lambdas fire.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/app/service_locator.dart';
import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/alerts/presentation/controller/alert_provider.dart';
import 'package:altum_view_sdk/features/alerts/presentation/screens/alert_screen.dart';
import 'package:altum_view_sdk/features/camera/presentation/controllers/camera_provider.dart';
import 'package:altum_view_sdk/features/people/presentation/controller/person_provider.dart';
import 'package:altum_view_sdk/features/people/presentation/screens/people_screen.dart';
import 'package:altum_view_sdk/features/people_groups/presentation/controller/person_group_provider.dart';
import 'package:altum_view_sdk/features/profile/presentation/screens/profile_screen.dart';
import 'package:altum_view_sdk/features/rooms/presentation/controllers/room_provider.dart';
import 'package:altum_view_sdk/features/rooms/presentation/screens/room_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MainShell extends StatefulWidget {
  final String accessToken;
  const MainShell({super.key, required this.accessToken});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    // ── Wire all dependencies with the live token ────────────────────────────
    // Must be called here, synchronously, before build() runs.
    // The lazy create: lambdas in bootstrap.dart's MultiProvider will fire
    // only after this — guaranteeing ServiceLocator fields are initialised.
    ServiceLocator.init(widget.accessToken);

    // ── Kick off initial data loads ──────────────────────────────────────────
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RoomProvider>().loadRooms();
      context.read<CameraProvider>().loadCameras();
      context.read<PersonProvider>().loadPeople();
      context.read<PersonGroupProvider>().loadGroups();
      context.read<AlertProvider>().startPolling();
    });
  }

  @override
  void dispose() {
    context.read<AlertProvider>().stopPolling();
    super.dispose();
  }

  // ── Tab metadata ──────────────────────────────────────────────────────────

  static const _tabs = [
    _TabMeta(icon: CupertinoIcons.house_fill,              label: 'Rooms'),
    _TabMeta(icon: CupertinoIcons.bell_fill,               label: 'Alerts'),
    _TabMeta(icon: CupertinoIcons.person_2_fill,           label: 'People'),
    _TabMeta(icon: CupertinoIcons.person_crop_circle_fill, label: 'Account'),
  ];

  Widget _body() => switch (_currentIndex) {
    0 => const RoomsScreen(),
    1 => const AlertsScreen(),
    2 => const PeopleScreen(),
    _ => ProfileScreen(accessToken: widget.accessToken),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _body(),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        tabs: _tabs,
        alertBadge: context.watch<AlertProvider>().unresolvedCount,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── Bottom Nav ────────────────────────────────────────────────────────────────

class _TabMeta {
  final IconData icon;
  final String   label;
  const _TabMeta({required this.icon, required this.label});
}

class _BottomNav extends StatelessWidget {
  final int               currentIndex;
  final List<_TabMeta>    tabs;
  final int               alertBadge;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.tabs,
    required this.alertBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.divider, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabs.length, (i) {
              final tab      = tabs[i];
              final selected = i == currentIndex;
              final isAlerts = i == 1;

              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 70,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.primary.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              tab.icon,
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.onSurfaceSub,
                              size: 24,
                            ),
                          ),
                          if (isAlerts && alertBadge > 0)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppTheme.error,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  alertBadge > 99 ? '99+' : '$alertBadge',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab.label,
                        style: TextStyle(
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.onSurfaceSub,
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}