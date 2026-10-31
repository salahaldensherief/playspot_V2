class BookingDatesDecoder {
  final Map<String, dynamic> json;
  late final date = _date();
  BookingDatesDecoder(this.json);

  DateTime _date() {
    final direct = DateTime.tryParse('${json['date']}');
    if (direct != null) return direct;
    final range = (json['booking_period'] ?? json['time_range'])?.toString();
    if (range == null) return DateTime.now();
    // PostgreSQL range: ["2026-10-02 10:00:00+00","2026-10-02 11:00:00+00").
    final start = range.replaceAll(RegExp(r'["\[\])]'), '').split(',').first;
    return DateTime.tryParse(start.trim()) ?? DateTime.now();
  }

  String get startTime => json['start_time']?.toString() ?? '';

  DateTime get startDateTime {
    if (startTime.contains('T')) return DateTime.tryParse(startTime) ?? date;
    final parts = startTime.split(':');
    if (parts.length < 2) return date;
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
    );
  }

  DateTime? optional(String key) => DateTime.tryParse('${json[key]}');
  DateTime? get holdExpiresAt =>
      DateTime.tryParse('${json['hold_expires_at'] ?? json['expires_at']}');
}
