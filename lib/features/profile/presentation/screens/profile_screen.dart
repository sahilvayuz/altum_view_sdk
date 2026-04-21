// ─────────────────────────────────────────────────────────────────────────────
// features/auth/presentation/screens/profile_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/login/login_screen.dart';
import 'package:altum_view_sdk/shared/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class ProfileScreen extends StatelessWidget {
  final String accessToken;
  const ProfileScreen({super.key, required this.accessToken});

  // Show only first 24 chars of token for security
  String get _maskedToken {
    if (accessToken.length <= 24) return accessToken;
    return '${accessToken.substring(0, 24)}…';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            backgroundColor: AppTheme.background,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Account',
                style: TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Avatar area ─────────────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primary.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.person_fill,
                            color: AppTheme.primary,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'AltumView User',
                          style: TextStyle(
                            color: AppTheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StatusBadge(
                          label: 'Authenticated',
                          color: AppTheme.success,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Token info ──────────────────────────────────────────
                  SectionHeader(title: 'SESSION'),
                  CardGroup(
                    children: [
                      ListTile(
                        leading: const Icon(CupertinoIcons.lock_fill,
                            color: AppTheme.primary, size: 20),
                        title: const Text('Access Token',
                            style: TextStyle(
                                color: AppTheme.onSurfaceSub, fontSize: 13)),
                        subtitle: Text(
                          _maskedToken,
                          style: const TextStyle(
                            color: AppTheme.onSurface,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(CupertinoIcons.globe,
                            color: AppTheme.primary, size: 20),
                        title: const Text('Token Endpoint',
                            style: TextStyle(
                                color: AppTheme.onSurfaceSub, fontSize: 13)),
                        subtitle: const Text(
                          'oauth.altumview.ca/v1.0/token',
                          style: TextStyle(
                            color: AppTheme.onSurface,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(CupertinoIcons.shield_lefthalf_fill,
                            color: AppTheme.primary, size: 20),
                        title: const Text('Grant Type',
                            style: TextStyle(
                                color: AppTheme.onSurfaceSub, fontSize: 13)),
                        subtitle: const Text(
                          'client_credentials',
                          style: TextStyle(
                            color: AppTheme.onSurface,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── App info ─────────────────────────────────────────────
                  SectionHeader(title: 'APP'),
                  CardGroup(
                    children: [
                      const ListTile(
                        leading: Icon(CupertinoIcons.info_circle,
                            color: AppTheme.primary, size: 20),
                        title: Text('Version',
                            style: TextStyle(
                                color: AppTheme.onSurfaceSub, fontSize: 13)),
                        trailing: Text('1.0.0',
                            style: TextStyle(
                                color: AppTheme.onSurface, fontSize: 14)),
                      ),
                      const ListTile(
                        leading: Icon(CupertinoIcons.camera_viewfinder,
                            color: AppTheme.primary, size: 20),
                        title: Text('SDK',
                            style: TextStyle(
                                color: AppTheme.onSurfaceSub, fontSize: 13)),
                        trailing: Text('AltumView SDK',
                            style: TextStyle(
                                color: AppTheme.onSurface, fontSize: 14)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ── Sign out ─────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: const Icon(CupertinoIcons.square_arrow_left,
                          size: 18),
                      label: const Text('Sign Out',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error.withOpacity(0.15),
                        foregroundColor: AppTheme.error,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _confirmSignOut(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
            'Your session will be cleared and you\'ll return to the login screen.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
              );
            },
            child: const Text('Sign Out'),
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