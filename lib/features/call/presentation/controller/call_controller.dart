import 'dart:async';
import 'package:altum_view_sdk/features/call/config/call_config.dart';
import 'package:altum_view_sdk/features/call/data/services/sip_service.dart';
import 'package:altum_view_sdk/features/call/domain/models/sip_account_model.dart';
import 'package:altum_view_sdk/features/call/domain/repositories/sip_repository.dart';
import 'package:altum_view_sdk/features/call/presentation/state/call_state.dart';
import 'package:flutter/foundation.dart';
import 'package:sip_ua/sip_ua.dart' as sip;

class CallController extends ChangeNotifier {
  final SipRepository _repository;
  final SipService _sipService;

  CallSession _session;
  Timer? _durationTimer;
  bool _isMuted = false;

  CallController({
    required String cameraId,
    required String accessToken,
    SipRegion region = SipRegion.canada,
  })  : _repository = SipRepository(
    baseUrl: SipConfig.apiBaseUrls[region]!,
    accessToken: accessToken,
  ),
        _sipService = SipService(region: region),
        _session = CallSession(cameraId: cameraId) {
    _sipService.onRegistrationStateChanged = _onRegistrationStateChanged;
    _sipService.onCallStateChanged = _onCallStateChanged;
  }

  // ─── Getters ──────────────────────────────────────────────────────────────

  CallSession get session => _session;
  bool get isMuted => _isMuted;
  bool get canCall =>
      _session.state == CallState.registered &&
          _session.cameraSipUsername != null;

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Step 1: Fetch SIP account creds + camera SIP username, then register.
  Future<void> initialize() async {
    _updateState(CallState.fetchingCredentials);

    try {
      final results = await Future.wait([
        _repository.getSipAccount(),
        _repository.getCameraSipUsername(_session.cameraId),
      ]);

      final sipAccount = results[0] as SipAccountModel;
      final cameraSipUsername = results[1] as String;

      _session = _session.copyWith(
        cameraSipUsername: cameraSipUsername,
        sipUsername: sipAccount.username,
      );

      _updateState(CallState.registering);
      await _sipService.register(sipAccount);
      // Registration result comes via _onRegistrationStateChanged callback
    } on SipException catch (e) {
      _updateState(CallState.failed, error: e.message);
    } catch (e) {
      _updateState(CallState.failed, error: e.toString());
    }
  }

  /// Step 2: Place the call (only valid after state == registered).
  Future<void> startCall() async {
    if (!canCall) return;
    _updateState(CallState.calling);
    try {
      await _sipService.call(_session.cameraSipUsername!);
    } on Exception catch (e) {
      _updateState(CallState.failed, error: e.toString());
    }
  }

  Future<void> endCall() async {
    _updateState(CallState.ending);
    _stopTimer();
    await _sipService.hangUp();
    _updateState(CallState.registered);
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _sipService.toggleMute(_isMuted); // ✅ passes bool
    notifyListeners();
  }

  // ─── Private callbacks from SipService ────────────────────────────────────

  void _onRegistrationStateChanged(sip.RegistrationState state) {
    switch (state.state) {
      case sip.RegistrationStateEnum.REGISTERED:
        _updateState(CallState.registered);
        break;
      case sip.RegistrationStateEnum.UNREGISTERED:
        if (_session.state != CallState.failed) {
          _updateState(CallState.idle);
        }
        break;
      case sip.RegistrationStateEnum.REGISTRATION_FAILED:
      // ✅ Fixed: state.cause is String?, NOT an object — no .cause property
        _updateState(
          CallState.failed,
          error: state.cause?.cause ?? 'Registration failed',
        );
        break;
      default:
        break;
    }
  }

  void _onCallStateChanged(sip.Call call, sip.CallState sipState) {
    final stateStr = call.state.toString();

    if (stateStr.contains('ACCEPTED') || stateStr.contains('CONFIRMED')) {
      _updateState(CallState.inCall);
      _startTimer();
    } else if (stateStr.contains('ENDED') || stateStr.contains('FAILED')) {
      _stopTimer();
      _updateState(CallState.registered);
    } else if (stateStr.contains('PROGRESS')) {
      _updateState(CallState.calling);
    }
  }

  // ─── Timer ────────────────────────────────────────────────────────────────

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _session = _session.copyWith(
        callDuration: _session.callDuration + const Duration(seconds: 1),
      );
      notifyListeners();
    });
  }

  void _stopTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _session = _session.copyWith(callDuration: Duration.zero);
  }

  void _updateState(CallState state, {String? error}) {
    _session = _session.copyWith(
      state: state,
      errorMessage: error,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTimer();
    _sipService.unregister();
    super.dispose();
  }
}