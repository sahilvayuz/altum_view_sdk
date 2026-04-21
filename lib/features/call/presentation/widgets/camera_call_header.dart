import 'package:altum_view_sdk/features/call/presentation/state/call_state.dart';
import 'package:flutter/material.dart';

class CameraCallHeader extends StatelessWidget {
  final String cameraId;
  final String? cameraSipUsername;
  final CallState callState;

  const CameraCallHeader({
    super.key,
    required this.cameraId,
    this.cameraSipUsername,
    required this.callState,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildAvatar(),
        const SizedBox(height: 16),
        Text(
          'Camera $cameraId',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (cameraSipUsername != null) ...[
          const SizedBox(height: 4),
          Text(
            cameraSipUsername!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildAvatar() {
    final isActive = callState == CallState.inCall ||
        callState == CallState.calling;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (isActive)
          _PulsingRing(color: callState == CallState.inCall
              ? Colors.green
              : Colors.blue),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.videocam_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
      ],
    );
  }
}

class _PulsingRing extends StatefulWidget {
  final Color color;
  const _PulsingRing({required this.color});

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _animation = Tween(begin: 95.0, end: 115.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        width: _animation.value,
        height: _animation.value,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.color.withOpacity(0.4),
            width: 2,
          ),
        ),
      ),
    );
  }
}