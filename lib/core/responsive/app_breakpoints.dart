import 'package:flutter/material.dart';

class AppBreakpoints {
  static const double mobileMax = 600;
  static const double tabletMax = 1024;
  static const double desktopMin = 1024;
  static bool isMobileWidth(double width) => width < mobileMax;
  static bool isTabletWidth(double width) =>
      width >= mobileMax && width < tabletMax;
  static bool isDesktopWidth(double width) => width >= desktopMin;
  static bool isMobile(BuildContext context) =>
      isMobileWidth(MediaQuery.sizeOf(context).width);
  static bool isTablet(BuildContext context) =>
      isTabletWidth(MediaQuery.sizeOf(context).width);
  static bool isDesktop(BuildContext context) =>
      isDesktopWidth(MediaQuery.sizeOf(context).width);
}
