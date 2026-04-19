import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../controllers/setup_controller.dart';

///4️⃣ Setup Progress Screen (MOST IMPORTANT UX)
// What user sees
// A checklist like:
//✓ Connecting to device
// ✓ Verifying permission
// ⏳ Setting server
// ⏳ Connecting to Wi-Fi

///What app does
// /DISCONNECT
// /SERVER
// POST /cameras
// /SET
// Waits for success

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SetupController>();

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
           // const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(controller.status),
          ],
        ),
      ),
    );
  }
}
///Update status like:
// "Getting permission…"
// "Setting server…"
// "Connecting to Wi-Fi…"
