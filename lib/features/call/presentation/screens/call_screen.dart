import 'package:altum_view_sdk/features/call/config/call_config.dart';
import 'package:altum_view_sdk/features/call/presentation/controller/call_controller.dart';
import 'package:altum_view_sdk/features/call/presentation/state/call_state.dart';
import 'package:altum_view_sdk/features/call/presentation/widgets/call_action_button.dart';
import 'package:altum_view_sdk/features/call/presentation/widgets/call_state_indicator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/call_timer_display.dart';
import '../widgets/camera_call_header.dart';

/// The main screen for initiating and managing a 2-way audio call with
/// an AltumView Sentinare sensor via SIP.
///
/// Usage:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => CallScreen(
///     cameraId: 'your-camera-id',
///     accessToken: 'your-bearer-token',
///     region: SipRegion.us,
///   ),
/// ));
/// ```
class CallScreen extends StatelessWidget {
  final String cameraId;
  final String accessToken;
  final SipRegion region;

  const CallScreen({
    super.key,
    required this.cameraId,
    required this.accessToken,
    this.region = SipRegion.canada,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CallController(
        cameraId: cameraId,
        accessToken: accessToken,
        region: region,
      ),
      child: const _CallScreenBody(),
    );
  }
}

class _CallScreenBody extends StatelessWidget {
  const _CallScreenBody();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CallController>();
    final session = controller.session;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Audio Call',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Camera avatar + name
              CameraCallHeader(
                cameraId: session.cameraId,
                cameraSipUsername: session.cameraSipUsername,
                callState: session.state,
              ),

              const SizedBox(height: 20),

              // Status badge
              CallStatusIndicator(
                state: session.state,
                errorMessage: session.errorMessage,
              ),

              const SizedBox(height: 16),

              // Timer (visible only during a call)
              AnimatedOpacity(
                opacity: session.state == CallState.inCall ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: CallTimerDisplay(duration: session.callDuration),
              ),

              const Spacer(),

              // Action buttons
              CallActionButtons(
                callState: session.state,
                isMuted: controller.isMuted,
                canCall: controller.canCall,
                onInitialize: () => controller.initialize(),
                onCallPressed: () => controller.startCall(),
                onEndPressed: () => controller.endCall(),
                onMutePressed: () => controller.toggleMute(),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}