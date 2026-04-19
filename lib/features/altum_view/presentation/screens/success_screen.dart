import 'package:altum_view_sdk/features/altum_view/presentation/controllers/altum_view_controller.dart';
import 'package:altum_view_sdk/features/altum_view/presentation/screens/alerts/altum_alert_dashboard.dart';
import 'package:altum_view_sdk/features/altum_view/presentation/screens/altum_camera_stream_screen.dart';
import 'package:flutter/material.dart';

///5️⃣ Success / Failure Screen
class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle,
                color: Colors.green, size: 80),
            const SizedBox(height: 12),
            const Text('Device added successfully'),
            ElevatedButton(
                onPressed:() => runFullCalibration(),
                child: const Text('Calibrate the sensor')
            ),
            const SizedBox(height: 10,),
            ElevatedButton(
                onPressed:() =>Navigator.push(context,  MaterialPageRoute(
                  builder: (context) => AltumSkeletonStreamPage(
                    cameraId:     11303,
                    serialNumber: '230C4C2056C9D0EE',
                    accessToken: authToken,
                  ),
                ),
                ),
                child: const Text('get stream')
            ),
            ElevatedButton(
                onPressed:() => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AltumDashboardPage(
                    accessToken:  authToken,
                    cameraId:     11303,
                    serialNumber: '230C4C2056C9D0EE',
                  ),
                )),
                child: const Text('Altum Alert Dashboard')
            )
          ],
        ),
      ),
    );
  }
}

