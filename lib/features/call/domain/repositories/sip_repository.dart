import 'dart:convert';
import 'package:altum_view_sdk/features/call/domain/models/sip_account_model.dart';
import 'package:http/http.dart' as http;

class SipRepository {
  final String baseUrl;
  final String accessToken;

  SipRepository({
    required this.baseUrl,
    required this.accessToken,
  });

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };

  /// Fetches SIP account credentials from the server.
  /// Call this before registering to the SIP server.
  Future<SipAccountModel> getSipAccount() async {
    final uri = Uri.parse('$baseUrl/sipAccount');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SipAccountModel.fromJson(json);
    } else {
      throw SipException(
        'Failed to fetch SIP account: ${response.statusCode}',
        response.statusCode,
      );
    }
  }

  /// Fetches the SIP username for a specific camera/sensor.
  /// [cameraId] — the camera's ID from your cameras list.
  Future<String> getCameraSipUsername(String cameraId) async {
    final uri = Uri.parse('$baseUrl/cameras/$cameraId');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      final sipUsername = data['sip_username'] as String?;
      if (sipUsername == null || sipUsername.isEmpty) {
        throw const SipException('Camera does not have a SIP username', 404);
      }
      return sipUsername;
    } else {
      throw SipException(
        'Failed to fetch camera info: ${response.statusCode}',
        response.statusCode,
      );
    }
  }
}

class SipException implements Exception {
  final String message;
  final int? statusCode;

  const SipException(this.message, [this.statusCode]);

  @override
  String toString() => 'SipException($statusCode): $message';
}