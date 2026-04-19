import 'package:altum_view_sdk/features/altum_view/presentation/screens/success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../controllers/setup_controller.dart';

class AltumViewScreen extends StatelessWidget {
  const AltumViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SetupController>();

   return const SuccessScreen();
   //  switch (c.step) {
   //    case SetupStep.scan:
   //      return ScanScreen(onDeviceFound: c.onDeviceFound);
   //    case SetupStep.connecting:
   //      return const ConnectingScreen();
   //    case SetupStep.wifi:
   //      return WifiScreen(
   //        wifiList: c.wifiList,
   //        onSubmit: c.submitWifi,
   //      );
   //    case SetupStep.progress:
   //      return const ProgressScreen();
   //    case SetupStep.success:
   //      return const SuccessScreen();
   //    case SetupStep.error:
   //      return Center(child: Text(c.status));
   //  }
  }
}
