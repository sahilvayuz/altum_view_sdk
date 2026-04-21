/// Represents the current state of a SIP call.
enum CallState {
  idle,
  fetchingCredentials,
  registering,
  registered,
  calling,
  inCall,
  ending,
  failed,
}

/// Holds all info needed to display the call UI and manage the call lifecycle.
class CallSession {
  final String cameraId;
  final String? cameraSipUsername;
  final String? sipUsername;
  final CallState state;
  final String? errorMessage;
  final Duration callDuration;

  const CallSession({
    required this.cameraId,
    this.cameraSipUsername,
    this.sipUsername,
    this.state = CallState.idle,
    this.errorMessage,
    this.callDuration = Duration.zero,
  });

  bool get isActive =>
      state == CallState.calling || state == CallState.inCall;

  bool get hasError => state == CallState.failed && errorMessage != null;

  CallSession copyWith({
    String? cameraId,
    String? cameraSipUsername,
    String? sipUsername,
    CallState? state,
    String? errorMessage,
    Duration? callDuration,
  }) {
    return CallSession(
      cameraId: cameraId ?? this.cameraId,
      cameraSipUsername: cameraSipUsername ?? this.cameraSipUsername,
      sipUsername: sipUsername ?? this.sipUsername,
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      callDuration: callDuration ?? this.callDuration,
    );
  }
}