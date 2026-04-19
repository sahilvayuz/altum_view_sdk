class WifiResponse {
  final String status;
  final String requestType;
  final List<WifiNetwork> result;

  WifiResponse({
    required this.status,
    required this.requestType,
    required this.result,
  });

  factory WifiResponse.fromJson(Map<String, dynamic> json) {
    return WifiResponse(
      status: json['status']?.toString() ?? '',
      requestType: json['request_type']?.toString() ?? '',
      result: (json['result'] as List<dynamic>? ?? [])
          .map((e) => WifiNetwork.fromJson(e))
          .toList(),
    );
  }
}


class WifiNetwork {
  final String ssid;
  final bool isPrivate;
  final int strength;
  final int rssiAvg;
  final int age;
  final String apMac;

  WifiNetwork({
    required this.ssid,
    required this.isPrivate,
    required this.strength,
    required this.rssiAvg,
    required this.age,
    required this.apMac,
  });

  factory WifiNetwork.fromJson(Map<String, dynamic> json) {
    final hexName = json['name']?.toString() ?? '';

    return WifiNetwork(
      ssid: _hexToStringSafe(hexName),
      isPrivate: json['private'] == true,
      strength: _toInt(json['strength']),
      rssiAvg: _toInt(json['rssi_avg']),
      age: _toInt(json['age']),
      apMac: json['ap_mac']?.toString() ?? '',
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static String _hexToStringSafe(String hex) {
    if (hex.isEmpty || hex.length % 2 != 0) return '';
    try {
      final bytes = <int>[];
      for (int i = 0; i < hex.length; i += 2) {
        bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
      }
      return String.fromCharCodes(bytes).trim();
    } catch (_) {
      return '';
    }
  }
}
