import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Note: horizontalSpace and verticalSpace are already provided by flutter_screenutil.
// We only keep the padding extensions here to avoid conflicts.

extension PaddingExtension on num {
  EdgeInsets get allPadding => EdgeInsets.all(w);
  EdgeInsets get horizontalPadding => EdgeInsets.symmetric(horizontal: w);
  EdgeInsets get verticalPadding => EdgeInsets.symmetric(vertical: h);
}
