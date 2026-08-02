import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

extension SpacingExtension on num {
  /// Creates a vertical space
  Widget get verticalSpace => SizedBox(height: toDouble().h);

  /// Creates a horizontal space
  Widget get horizontalSpace => SizedBox(width: toDouble().w);
}
