class TimeRange {
  final DateTime start;
  final DateTime end;

  TimeRange({required this.start, required this.end});

  bool overlaps(double hourStart, double hourEnd) {
    final startHour = hourStart.toInt();
    final startMinute = ((hourStart - startHour) * 60).round();
    
    final endHour = hourEnd.toInt();
    final endMinute = ((hourEnd - endHour) * 60).round();

    final checkStart = DateTime(start.year, start.month, start.day, startHour, startMinute);
    var checkEnd = DateTime(start.year, start.month, start.day, endHour, endMinute);
    
    if (hourEnd <= hourStart) {
      checkEnd = checkEnd.add(const Duration(days: 1));
    }

    return start.isBefore(checkEnd) && end.isAfter(checkStart);
  }

  double get durationInHours => end.difference(start).inMinutes / 60.0;
}
