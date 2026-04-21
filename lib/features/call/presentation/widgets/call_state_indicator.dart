import 'package:altum_view_sdk/features/call/presentation/state/call_state.dart';
import 'package:flutter/material.dart';

class CallStatusIndicator extends StatelessWidget {
  final CallState state;
  final String? errorMessage;

  const CallStatusIndicator({
    super.key,
    required this.state,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (state) {
      case CallState.idle:
        return _StatusChip(
          key: const ValueKey('idle'),
          label: 'Not connected',
          color: Colors.grey,
          icon: Icons.phone_disabled_rounded,
        );

      case CallState.fetchingCredentials:
      case CallState.registering:
        return _StatusChip(
          key: const ValueKey('connecting'),
          label: state == CallState.registering
              ? 'Registering SIP...'
              : 'Fetching credentials...',
          color: Colors.orange,
          icon: Icons.sync_rounded,
          isAnimating: true,
        );

      case CallState.registered:
        return _StatusChip(
          key: const ValueKey('registered'),
          label: 'Ready to call',
          color: Colors.green,
          icon: Icons.check_circle_rounded,
        );

      case CallState.calling:
        return _StatusChip(
          key: const ValueKey('calling'),
          label: 'Calling...',
          color: Colors.blue,
          icon: Icons.phone_in_talk_rounded,
          isAnimating: true,
        );

      case CallState.inCall:
        return _StatusChip(
          key: const ValueKey('inCall'),
          label: 'In call',
          color: Colors.green,
          icon: Icons.phone_in_talk_rounded,
        );

      case CallState.ending:
        return _StatusChip(
          key: const ValueKey('ending'),
          label: 'Ending call...',
          color: Colors.orange,
          icon: Icons.phone_callback_rounded,
        );

      case CallState.failed:
        return _StatusChip(
          key: const ValueKey('failed'),
          label: errorMessage ?? 'Connection failed',
          color: Colors.red,
          icon: Icons.error_rounded,
        );
    }
  }
}

class _StatusChip extends StatefulWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool isAnimating;

  const _StatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    this.isAnimating = false,
  });

  @override
  State<_StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<_StatusChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.isAnimating) _rotationController.repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: widget.isAnimating
                ? _rotationController
                : const AlwaysStoppedAnimation(0),
            child: Icon(widget.icon, color: widget.color, size: 16),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}