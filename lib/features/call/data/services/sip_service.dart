import 'dart:io';

// sip_ua is imported with a prefix to avoid name collisions with
// our own CallState / RegistrationState domain classes.
import 'package:altum_view_sdk/features/call/config/call_config.dart';
import 'package:altum_view_sdk/features/call/domain/models/sip_account_model.dart';
import 'package:sip_ua/sip_ua.dart' as sip;

/// Wraps the sip_ua library, providing a clean interface for
/// registering, calling, and hanging up via AltumView SIP.
///
/// Add to pubspec.yaml:
///   sip_ua: ^1.1.0
class SipService implements sip.SipUaHelperListener {
  // Correct class name is SIPUAHelper (not SipUaHelper)
  final sip.SIPUAHelper _helper = sip.SIPUAHelper();
  final SipRegion region;

  sip.Call? _activeCall;
  sip.RegistrationState _registrationState =
  sip.RegistrationState(state: sip.RegistrationStateEnum.NONE);

  // Callbacks set by the controller
  void Function(sip.RegistrationState state)? onRegistrationStateChanged;
  void Function(sip.Call call, sip.CallState state)? onCallStateChanged;

  SipService({this.region = SipRegion.us}) {
    _helper.addSipUaHelperListener(this);
  }

  // ─── DNS helper ───────────────────────────────────────────────────────────

  /// Resolves [hostname] to an IPv4 address only.
  ///
  /// Android with dual-stack networking prefers AAAA (IPv6) records, but most
  /// home/office routers have no IPv6 upstream route, causing:
  ///   SocketException: Network is unreachable (errno = 101)
  ///
  /// Forcing an IPv4 lookup (A record only) avoids this entirely.
  /// The real [hostname] is still passed as the Host header so that TLS SNI
  /// and certificate validation against *.altumview.com/ca/etc. still work.
  ///
  /// Falls back to [hostname] itself if resolution fails, so the app degrades
  /// gracefully on networks that do have working IPv6.
  Future<String> _resolveIPv4(String hostname) async {
    try {
      final results = await InternetAddress.lookup(
        hostname,
        type: InternetAddressType.IPv4,
      );
      if (results.isNotEmpty) {
        return results.first.address; // e.g. "15.222.101.45"
      }
    } catch (_) {}
    return hostname; // fallback: let the OS pick
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Register to the AltumView SIP server using credentials from the API.
  Future<void> register(SipAccountModel account) async {
    final domain = SipConfig.sipDomains[region]!;
    final stunServer = SipConfig.stunServers[region]!;

    // Force IPv4 to prevent errno=101 on networks without IPv6 routing.
    // Re-resolved on every register() call so IP changes self-heal.
    final ipv4Host = await _resolveIPv4(domain);

    final settings = sip.UaSettings();

    // ─── Transport ──────────────────────────────────────────────────────────
    // AltumView's WebSocket SIP endpoint is on port 443 (WSS).
    // We connect to the resolved IPv4 address directly to avoid IPv6 routing
    // failures, but pass the real domain in the Host header so that:
    //   • TLS SNI negotiation uses the correct hostname
    //   • The server-side cert (*.altumview.ca etc.) validates correctly
    settings.transportType = sip.TransportType.WS;
    settings.webSocketUrl = 'wss://$ipv4Host:443';
    settings.webSocketSettings.allowBadCertificate = true;
    settings.webSocketSettings.extraHeaders = {'Host': domain};

    // ─── Identity ────────────────────────────────────────────────────────────
    // SIP URI and auth always use the domain name, never the raw IP.
    settings.uri = 'sip:${account.username}@$domain';
    settings.authorizationUser = account.username;
    settings.password = account.passcode;
    settings.displayName = account.username;
    settings.userAgent = 'AltumViewFlutter/1.0';

    // ─── Registration ────────────────────────────────────────────────────────
    settings.register = true;
    settings.dtmfMode = sip.DtmfMode.RFC2833;

    // ─── ICE / STUN / TURN ──────────────────────────────────────────────────
    // Used for media (audio) NAT traversal — not for SIP signalling.
    settings.iceServers = [
      {
        'urls': 'stun:$stunServer:${SipConfig.stunPort}',
        'username': SipConfig.stunUsername,
        'credential': SipConfig.stunPassword,
      },
      {
        'urls': 'turn:$stunServer:${SipConfig.stunPort}',
        'username': SipConfig.stunUsername,
        'credential': SipConfig.stunPassword,
      },
    ];

    await _helper.start(settings);
  }

  /// Initiates an outgoing call to a camera's SIP username.
  Future<void> call(String cameraSipUsername) async {
    final domain = SipConfig.sipDomains[region]!;
    final target = 'sip:$cameraSipUsername@$domain';
    await _helper.call(target, voiceOnly: true);
  }

  /// Hangs up the current active call.
  /// In sip_ua, hangup is called directly on the Call object.
  Future<void> hangUp() async {
    _activeCall?.hangup();
    _activeCall = null;
  }

  /// Toggle microphone mute on the active call.
  /// mute() is called directly on the Call object in sip_ua.
  void toggleMute(bool mute) {
    _activeCall?.mute(mute);
  }

  void unregister() {
    _helper.unregister();
    _helper.stop();
  }

  // ─── SipUaHelperListener required overrides ───────────────────────────────

  @override
  void registrationStateChanged(sip.RegistrationState state) {
    _registrationState = state;
    onRegistrationStateChanged?.call(state);
  }

  @override
  void callStateChanged(sip.Call call, sip.CallState state) {
    _activeCall = call;
    onCallStateChanged?.call(call, state);
  }

  @override
  void onNewMessage(sip.SIPMessageRequest msg) {}

  @override
  void onNewNotify(sip.Notify ntf) {}

  @override
  void onNewReinvite(sip.ReInvite event) {}

  @override
  void transportStateChanged(sip.TransportState state) {}

  // ─── Getters ──────────────────────────────────────────────────────────────

  sip.RegistrationState get registrationState => _registrationState;

  bool get isRegistered =>
      _registrationState.state == sip.RegistrationStateEnum.REGISTERED;
}