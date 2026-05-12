import 'package:flutter/material.dart';

enum DeviceType { phone, tablet }

class DeviceTypeHelper {
  /// Returns [DeviceType.tablet] if the device width is >= 600dp.
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.shortestSide;
    return width >= 600 ? DeviceType.tablet : DeviceType.phone;
  }

  static bool isTablet(BuildContext context) {
    return getDeviceType(context) == DeviceType.tablet;
  }

  static bool isPhone(BuildContext context) {
    return getDeviceType(context) == DeviceType.phone;
  }

  static Size getSize(BuildContext context) {
    if (isTablet(context)) {
      return const Size(800, 1500);
    }
    return const Size(375, 812);
  }
}
