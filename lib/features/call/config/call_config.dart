/// AltumView SIP server configuration constants.
/// Values sourced from the official SIP API documentation.
class SipConfig {
  SipConfig._();

  // --- Transport ---
  static const String transportType = 'TLS';
  static const int tlsPort = 5061;

  // --- Features ---
  static const bool iceEnabled = true;
  static const bool turnEnabled = true;
  static const bool stunEnabled = true;
  static const bool ipv6Enabled = false;
  static const bool certificateVerification = false; // self-signed cert

  // --- Realm ---
  static const String realm = '*';

  // --- STUN ---
  static const int stunPort = 9347;
  static const String stunUsername = 'altumviewsip';
  static const String stunPassword = 'sipCanHelp';

  // --- Region-specific domains ---
  static const Map<SipRegion, String> sipDomains = {
    SipRegion.us: 'sip.altumview.com',
    SipRegion.canada: 'sip.altumview.ca',
    SipRegion.china: 'sip.altumview.com.cn',
  };

  static const Map<SipRegion, String> stunServers = {
    SipRegion.us: 'turn.altumview.com',
    SipRegion.canada: 'turn.altumview.ca',
    SipRegion.china: 'turn.altumview.com.cn',
  };

  static const Map<SipRegion, String> apiBaseUrls = {
    SipRegion.us: 'https://api.altumview.com/v1.0',
    SipRegion.canada: 'https://api.altumview.ca/v1.0',
    SipRegion.china: 'https://api.ailecare.cn/v1.0',
    SipRegion.europe: 'https://api.altumview.co/v1.0',
  };
}

enum SipRegion { us, canada, china, europe }