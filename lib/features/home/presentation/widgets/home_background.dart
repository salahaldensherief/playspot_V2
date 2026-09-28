import 'package:flutter/material.dart';
import 'package:playspot/art_core/theme/app_colors.dart';

class HomeBackground extends StatelessWidget {
  const HomeBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.8, -0.8),
          radius: 1.5,
          colors: [
            AppColors.neonBlue.withValues(alpha: 0.03),
            AppColors.scaffoldBackground,
          ],
        ),
      ),
    );
  }
}
