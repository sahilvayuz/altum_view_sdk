# ─────────────────────────────────────────────
# AltumView Call Feature – Setup & Usage Notes
# ─────────────────────────────────────────────

## 1. Add to pubspec.yaml

dependencies:
flutter_sip_ua: ^0.4.5      # SIP library
provider: ^6.1.2             # State management
http: ^1.2.1                 # HTTP calls (already used in your app)


## 2. Android permissions – android/app/src/main/AndroidManifest.xml

<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />


## 3. iOS permissions – ios/Runner/Info.plist

<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for 2-way audio calls with the sensor.</string>


## 4. Request mic permission before opening CallScreen
Use permission_handler package:

import 'package:permission_handler/permission_handler.dart';

Future<void> openCallScreen(BuildContext context, String cameraId) async {
final status = await Permission.microphone.request();
if (status.isGranted) {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => CallScreen(
cameraId: cameraId,
accessToken: 'YOUR_BEARER_TOKEN',
region: SipRegion.us,  // Change to your server region
),
),
);
} else {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Microphone permission is required for calls.')),
);
}
}


## 5. Folder structure produced

features/
└── call/
├── data/
│   ├── sip_account_model.dart   ← API response model
│   └── sip_repository.dart      ← HTTP calls: /sipAccount, /cameras/:id
├── domain/
│   ├── call_state.dart          ← CallState enum + CallSession entity
│   └── call_controller.dart     ← ChangeNotifier, drives UI
├── helpers/
│   ├── sip_config.dart          ← All SIP constants from API docs
│   └── sip_service.dart         ← flutter_sip_ua wrapper
└── presentation/
├── screens/
│   └── call_screen.dart     ← Main screen, wires up Provider
└── widgets/
├── call_action_buttons.dart  ← Call/End/Mute buttons
├── call_status_indicator.dart ← Animated status badge
├── call_timer_display.dart   ← MM:SS / HH:MM:SS timer
└── camera_call_header.dart  ← Avatar + name + pulse ring


## 6. Call flow (matches SIP API docs exactly)

CallScreen opened
│
▼
[Connect SIP] button tapped
│
├── GET /sipAccount          → SipAccountModel (username + passcode)
├── GET /cameras/:id         → cameraSipUsername
│
▼
SipService.register(sipAccount)
→ Connects to sip.altumview.com (or regional equivalent) on TLS:5061
→ Uses STUN/TURN at turn.altumview.com:9347
│
▼ (onRegistered callback)
CallState.registered → [Start Call] button appears
│
▼
SipService.call(cameraSipUsername)
→ Sends SIP INVITE to <sip_username>@sip.altumview.com
│
▼ (onCallAccepted)
CallState.inCall → timer starts, mute/end buttons visible
│
▼
[End] tapped → SipService.hangUp() → CallState.registered