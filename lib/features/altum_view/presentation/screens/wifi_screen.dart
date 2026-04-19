import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../controllers/setup_controller.dart';

///3️⃣ Wi-Fi Selection Screen
// What user sees
// List of Wi-Fi networks
// Password field
// “Continue” button
// What app does before showing this screen
// Sends /GET network_list
// Parses responses
// Decodes HEX → text

class WifiScreen extends StatefulWidget {
  final List<String> wifiList;
  final void Function(String ssid, String password) onSubmit;

  const WifiScreen({
    super.key,
    required this.wifiList,
    required this.onSubmit,
  });

  @override
  State<WifiScreen> createState() => _WifiScreenState();
}

class _WifiScreenState extends State<WifiScreen> {
  String? selectedWifi;
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect Wi-Fi')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButton<String>(
              hint: const Text('Select Wi-Fi'),
              value: selectedWifi,
              items: widget.wifiList
                  .map((w) => DropdownMenuItem(
                value: w,
                child: Text(w),
              ))
                  .toList(),
              onChanged: (v) => setState(() => selectedWifi = v),
            ),
            TextField(
              controller: passwordController,
              decoration:
              const InputDecoration(labelText: 'Wi-Fi Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                widget.onSubmit(
                  selectedWifi!,
                  passwordController.text,
                );
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}


///User gives Wi-Fi → app takes control again
