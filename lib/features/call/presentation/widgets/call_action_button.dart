import 'package:altum_view_sdk/features/call/presentation/state/call_state.dart';
import 'package:flutter/material.dart';

class CallActionButtons extends StatelessWidget {
  final CallState callState;
  final bool isMuted;
  final bool canCall;
  final VoidCallback onCallPressed;
  final VoidCallback onEndPressed;
  final VoidCallback onMutePressed;
  final VoidCallback onInitialize;

  const CallActionButtons({
    super.key,
    required this.callState,
    required this.isMuted,
    required this.canCall,
    required this.onCallPressed,
    required this.onEndPressed,
    required this.onMutePressed,
    required this.onInitialize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (callState == CallState.inCall || callState == CallState.calling)
          _buildInCallButtons()
        else
          _buildIdleButtons(),
      ],
    );
  }

  Widget _buildInCallButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CircleActionButton(
          icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: isMuted ? 'Unmute' : 'Mute',
          backgroundColor:
          isMuted ? Colors.orange.shade700 : Colors.white.withOpacity(0.15),
          iconColor: Colors.white,
          onPressed: onMutePressed,
        ),
        _CircleActionButton(
          icon: Icons.call_end_rounded,
          label: 'End',
          backgroundColor: Colors.red.shade600,
          iconColor: Colors.white,
          size: 72,
          onPressed: callState == CallState.ending ? null : onEndPressed,
        ),
        _CircleActionButton(
          icon: Icons.volume_up_rounded,
          label: 'Speaker',
          backgroundColor: Colors.white.withOpacity(0.15),
          iconColor: Colors.white,
          onPressed: () {}, // Extend with speaker toggle if needed
        ),
      ],
    );
  }

  Widget _buildIdleButtons() {
    return Column(
      children: [
        if (callState == CallState.idle || callState == CallState.failed)
          _OutlinedActionButton(
            icon: Icons.settings_ethernet_rounded,
            label: 'Connect SIP',
            onPressed: onInitialize,
            color: Colors.blueAccent,
          ),
        if (callState == CallState.registered)
          _OutlinedActionButton(
            icon: Icons.phone_rounded,
            label: 'Start Call',
            onPressed: canCall ? onCallPressed : null,
            color: Colors.green,
          ),
      ],
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color iconColor;
  final double size;
  final VoidCallback? onPressed;

  const _CircleActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.iconColor,
    this.size = 58,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
              onPressed == null ? Colors.grey.shade700 : backgroundColor,
            ),
            child: Icon(icon, color: iconColor, size: size * 0.42),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  const _OutlinedActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.6)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}