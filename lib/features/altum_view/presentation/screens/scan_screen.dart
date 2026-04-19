import 'package:altum_view_sdk/features/altum_view/presentation/controllers/altum_view_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

///1️⃣ Scan Screen (Start Point)
// What user sees
// Button: “Scan for Device”
// Loader
// List of nearby sensors (optional)
// What app does
// Starts BLE scan
// Finds Sentinare device
// When found → move to next screen
class ScanScreen extends StatelessWidget {
  final void Function(BluetoothDevice device) onDeviceFound;

  const ScanScreen({
    super.key,
    required this.onDeviceFound,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Device')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            startScan(onDeviceFound);
          },
          child: const Text('Scan for Device'),
        ),
      ),
    );
  }
}
///User clicks → app starts scanning
