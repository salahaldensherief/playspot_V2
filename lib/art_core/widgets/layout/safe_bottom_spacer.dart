import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SafeBottomSpacer extends StatelessWidget {
  final double extraPadding;
  final bool androidOnly;

  const SafeBottomSpacer({
    super.key,
    this.extraPadding = 20,
    this.androidOnly = true,
  });

  @override
  Widget build(BuildContext context) {
    if (androidOnly && !Platform.isAndroid) return const SizedBox.shrink();

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // On Android, system navigation buttons can sometimes overlap content.
    // We add the system padding plus an extra buffer for better UX.
    return SizedBox(height: bottomPadding + extraPadding.h);
  }
}

class SliverSafeBottomSpacer extends StatelessWidget {
  final double extraPadding;
  final bool androidOnly;

  const SliverSafeBottomSpacer({
    super.key,
    this.extraPadding = 20,
    this.androidOnly = true,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SafeBottomSpacer(
        extraPadding: extraPadding,
        androidOnly: androidOnly,
      ),
    );
  }
}
