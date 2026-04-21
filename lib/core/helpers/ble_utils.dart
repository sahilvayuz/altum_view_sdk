// ─────────────────────────────────────────────────────────────────────────────
// core/utils/ble_utils.dart
//
// Shared BLE helper functions and the structured BLE log.
// Extracted from altum_view_controller.dart to be used by any BLE feature.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';
import 'dart:io' show Platform;

/// Mirrors Android logcat timestamp format: MM-DD HH:MM:SS.mmm
String bleTimestamp() {
  final n  = DateTime.now();
  final mo = n.month.toString().padLeft(2, '0');
  final d  = n.day.toString().padLeft(2, '0');
  final h  = n.hour.toString().padLeft(2, '0');
  final mi = n.minute.toString().padLeft(2, '0');
  final s  = n.second.toString().padLeft(2, '0');
  final ms = n.millisecond.toString().padLeft(3, '0');
  return '$mo-$d $h:$mi:$s.$ms';
}

/// In-memory BLE log buffer — matches vendor's Android reference format.
final List<String> bleLog = [];

void bleWrite(String level, String tag, String msg) {
  final line = '${bleTimestamp()} $level $tag: $msg';
  log(line);
  bleLog.add(line);
}

void bleV(String tag, String msg) => bleWrite('V', tag, msg);
void bleD(String tag, String msg) => bleWrite('D', tag, msg);
void bleI(String tag, String msg) => bleWrite('I', tag, msg);
void bleW(String tag, String msg) => bleWrite('W', tag, msg);

// ── Hex helpers ───────────────────────────────────────────────────────────────

/// Byte list → "AA-BB-CC" format (for BLE notification logs)
String bytesToHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join('-');

/// UTF-8 string → compact hex (for SSID/PSK encoding in /SET command)
String toHex(String input) =>
    input.codeUnits.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

/// Compact hex string → UTF-8 string
String hexToString(String hex) {
  final bytes = <int>[];
  for (int i = 0; i + 1 < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return String.fromCharCodes(bytes);
}

// ── Log export ────────────────────────────────────────────────────────────────

/// Exports the BLE log in the format the camera vendor expects.
String exportBleLogs() {
  final header = [
    '>>>> Flutter BLE log',
    'Android version: ${Platform.operatingSystemVersion}',
    'flutter_blue_plus library',
    '════════════════════════════════════════',
    '',
  ];
  return [...header, ...bleLog].join('\n');
}