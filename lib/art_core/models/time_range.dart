class TimeRange {
  final DateTime start;
  final DateTime end;

  TimeRange({required this.start, required this.end});

  bool overlaps(int hourStart, int hourEnd) {

    
    final checkStart = DateTime(start.year, start.month, start.day, hourStart);
    var checkEnd = DateTime(start.year, start.month, start.day, hourEnd);
    
    if (hourEnd <= hourStart) {
      checkEnd = checkEnd.add(const Duration(days: 1));
    }

    return start.isBefore(checkEnd) && end.isAfter(checkStart);
  }

  double get durationInHours => end.difference(start).inMinutes / 60.0;
}
