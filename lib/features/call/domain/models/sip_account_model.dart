class SipAccountModel {
  final String username;
  final String passcode;

  const SipAccountModel({
    required this.username,
    required this.passcode,
  });

  factory SipAccountModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final sipAccount = data['sip_account'] as Map<String, dynamic>;
    return SipAccountModel(
      username: sipAccount['username'] as String,
      passcode: sipAccount['passcode'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'username': username,
    'passcode': passcode,
  };
}