class TimeRange {
  final DateTime start;
  final DateTime end;

  TimeRange({required this.start, required this.end});

  /// يتحقق مما إذا كانت الساعة المعطاة تقع ضمن هذا النطاق الزمني.
  /// يتم اعتبار الساعة محجوزة إذا كان هناك أي تداخل.
  bool overlaps(int hourStart, int hourEnd) {
    // نحول الساعات المعطاة إلى DateTime في نفس يوم النطاق للمقارنة
    // ملحوظة: هذا المنطق يفترض أننا نقارن ساعات في نفس اليوم.
    // الـ RPC يرجع التواريخ كاملة (Timestamptz) لذا المقارنة ستكون دقيقة.
    
    final checkStart = DateTime(start.year, start.month, start.day, hourStart);
    var checkEnd = DateTime(start.year, start.month, start.day, hourEnd);
    
    // إذا كان وقت النهاية 0 (منتصف الليل) أو أصغر من البداية، فهو لليوم التالي
    if (hourEnd <= hourStart) {
      checkEnd = checkEnd.add(const Duration(days: 1));
    }

    return start.isBefore(checkEnd) && end.isAfter(checkStart);
  }

  double get durationInHours => end.difference(start).inMinutes / 60.0;
}
