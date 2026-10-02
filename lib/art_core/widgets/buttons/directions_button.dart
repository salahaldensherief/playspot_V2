import 'package:flutter/material.dart';
import 'directions_button_state.dart';

class DirectionsButton extends StatefulWidget {
  final double? lat;
  final double? lng;
  final double? height;
  final double? width;
  final bool isFullWidth;
  final bool isPrimary;
  final VoidCallback? onBeforeLaunch;
  const DirectionsButton({
    super.key,
    this.lat,
    this.lng,
    this.height,
    this.width,
    this.isFullWidth = false,
    this.isPrimary = false,
    this.onBeforeLaunch,
  });

  @override
  State<DirectionsButton> createState() => DirectionsButtonState();
}
