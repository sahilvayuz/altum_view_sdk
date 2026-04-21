// ─────────────────────────────────────────────────────────────────────────────
// features/auth/presentation/screens/login_screen.dart
//
// OAuth2 client_credentials login.
// POST https://oauth.altumview.ca/v1.0/token
//   grant_type    = client_credentials
//   client_id     = <user input>
//   client_secret = <user input>
//   scope         = camera:write room:write alert:write … (user input)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:altum_view_sdk/app/bootstrap.dart';
import 'package:altum_view_sdk/app/service_locator.dart';
import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/dashboard/presentation/screens/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _clientIdCtrl  = TextEditingController(text: 'nkJ1HznwgxwGBnB6');
  final _secretCtrl    = TextEditingController(text: 'm2HGxuNuzUk4JiKloTBOAlulv2odRhj9OkM6hzFKJQsSeBtcyLtYBDtGjxonfV3f');
  final _scopeCtrl     = TextEditingController(
    text: 'camera:write room:write alert:write person:write user:write group:write invitation:write person_info:write',
  );

  bool   _obscureSecret = true;
  bool   _loading       = false;
  String? _errorMsg;

  // ── OAuth2 token endpoint ──────────────────────────────────────────────────
  static const _tokenUrl = 'https://oauth.altumview.ca/v1.0/token';

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMsg = null; });

    try {
      final resp = await http.post(
        Uri.parse(_tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type':    'client_credentials',
          'client_id':     _clientIdCtrl.text.trim(),
          'client_secret': _secretCtrl.text.trim(),
          'scope':         _scopeCtrl.text.trim(),
        },
      );

      if (resp.statusCode == 200) {
        final body        = jsonDecode(resp.body) as Map<String, dynamic>;
        final accessToken = body['access_token'] as String?;
        ServiceLocator.init(accessToken ?? '');
        // setState(() {
        //   accessTokenBootStrap=accessToken ?? '';
        // });
        if (accessToken == null || accessToken.isEmpty) {
          throw Exception('access_token missing in response');
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MainShell(accessToken: accessToken),
          ),
        );
      } else {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        throw Exception(
          body['error_description'] ?? body['message'] ?? 'Login failed (${resp.statusCode})',
        );
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _clientIdCtrl.dispose();
    _secretCtrl.dispose();
    _scopeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),

                // ── Logo / brand ───────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.camera_viewfinder,
                          color: AppTheme.primary,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'AltumView',
                        style: TextStyle(
                          color: AppTheme.onBackground,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in with your API credentials',
                        style: TextStyle(
                          color: AppTheme.onSurfaceSub,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // ── grant_type label (read-only info) ──────────────────────
                _FieldLabel('Grant Type'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'client_credentials',
                    style: TextStyle(
                      color: AppTheme.onSurfaceSub,
                      fontSize: 15,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Client ID ──────────────────────────────────────────────
                _FieldLabel('Client ID'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _clientIdCtrl,
                  style: const TextStyle(
                      color: AppTheme.onSurface, fontSize: 15),
                  keyboardType: TextInputType.text,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: 'e.g. nkJ1HznwgxwGBnB6',
                    prefixIcon: const Icon(CupertinoIcons.person_crop_circle,
                        color: AppTheme.primary),
                    filled: true,
                    fillColor: AppTheme.surfaceCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Client ID is required'
                      : null,
                ),

                const SizedBox(height: 20),

                // ── Client Secret ──────────────────────────────────────────
                _FieldLabel('Client Secret'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _secretCtrl,
                  obscureText: _obscureSecret,
                  style: const TextStyle(
                      color: AppTheme.onSurface, fontSize: 15),
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: 'Your client secret',
                    prefixIcon: const Icon(CupertinoIcons.lock_fill,
                        color: AppTheme.primary),
                    suffixIcon: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => setState(
                              () => _obscureSecret = !_obscureSecret),
                      child: Icon(
                        _obscureSecret
                            ? CupertinoIcons.eye
                            : CupertinoIcons.eye_slash,
                        color: AppTheme.onSurfaceSub,
                        size: 20,
                      ),
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Client secret is required'
                      : null,
                ),

                const SizedBox(height: 20),

                // ── Scope ──────────────────────────────────────────────────
                _FieldLabel('Scope'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _scopeCtrl,
                  style: const TextStyle(
                      color: AppTheme.onSurface, fontSize: 13),
                  maxLines: 3,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: 'camera:write room:write …',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(CupertinoIcons.shield_lefthalf_fill,
                          color: AppTheme.primary),
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Scope is required'
                      : null,
                ),

                const SizedBox(height: 12),

                // ── Scope chips ────────────────────────────────────────────
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _defaultScopes
                      .map((s) => GestureDetector(
                    onTap: () {
                      final current = _scopeCtrl.text;
                      if (!current.contains(s)) {
                        _scopeCtrl.text =
                        current.isEmpty ? s : '$current $s';
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.25),
                        ),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ))
                      .toList(),
                ),

                const SizedBox(height: 32),

                // ── Error message ──────────────────────────────────────────
                if (_errorMsg != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.xmark_circle,
                            color: AppTheme.error, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMsg!,
                            style: const TextStyle(
                                color: AppTheme.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Sign In button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                        : const Text(
                      'Sign In',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Footer ─────────────────────────────────────────────────
                Center(
                  child: Text(
                    'Credentials are used only to obtain an access token\nand are never stored.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.onSurfaceSub.withOpacity(0.6),
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Default scope chips ───────────────────────────────────────────────────────

const _defaultScopes = [
  'camera:write',
  'room:write',
  'alert:write',
  'person:write',
  'group:write',
  'device:write',
];

// ── Field label helper ────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.onSurfaceSub,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }
}