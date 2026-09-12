import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SafeBottomSpacer extends StatelessWidget {
  final double extraPadding;
  final bool androidOnly;

  const SafeBottomSpacer({
    super.key,
    this.extraPadding = 24,
    this.androidOnly = true,
  });

  @override
  Widget build(BuildContext context) {
    if (androidOnly && !Platform.isAndroid) return const SizedBox.shrink();

    // Calculate maximum bottom inset from system padding or viewPadding (Android System Nav Bar)
    final bottomInset = math.max(
      MediaQuery.paddingOf(context).bottom,
      MediaQuery.viewPaddingOf(context).bottom,
    );

    final effectiveInset = bottomInset > 0 ? bottomInset : 0.0;

    return SizedBox(height: effectiveInset + extraPadding.h);
  }
}

class SliverSafeBottomSpacer extends StatelessWidget {
  final double extraPadding;
  final bool androidOnly;

  const SliverSafeBottomSpacer({
    super.key,
    this.extraPadding = 24,
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
