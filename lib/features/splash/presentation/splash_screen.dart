import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../art_core/theme/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TablerIcons.device_gamepad, size: 100,color: AppColors.lightBlue,shadows: [
              Shadow(
                color: AppColors.lightBlue.withOpacity(0.5),
                blurRadius: 20,
                offset: Offset(0, 0),
              ),
            ],),
            SizedBox(height: 20),
            Text("PlaySpot", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.lightBlue, shadows: [
              Shadow(
                color: AppColors.lightBlue.withOpacity(0.5),
                blurRadius: 20,
                offset: Offset(0, 0),
              ),
            ])),

          ],
        ),
      ),
    );
  }
}
