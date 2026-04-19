import 'package:altum_view_sdk/features/altum_view/presentation/controllers/setup_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

///2️⃣ Connecting Screen
// What user sees
// Text: “Connecting to device…”
// Spinner (loading)
// What app does (automatically)
// Connects to BLE device
// Discovers services
// Subscribes to Tx characteristic
// Calls /GET info
// No buttons here.
// User just waits.

class ConnectingScreen extends StatelessWidget {
  const ConnectingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SetupController>();

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          //  const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(controller.status),
          ],
        ),
      ),
    );
  }
}


