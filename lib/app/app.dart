import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/altum_view/presentation/screens/success_screen.dart';
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const App({super.key,});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
     debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.light,
      home: SuccessScreen(),
    );
  }
}
