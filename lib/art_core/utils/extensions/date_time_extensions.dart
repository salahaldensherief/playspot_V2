import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension DateTimeExtensions on DateTime {
  /// Formats date to: "Today, MMMM d" or "EEEE, MMMM d"
  String toAppDateString() {
    if (DateFormat('yyyy-MM-dd').format(this) == DateFormat('yyyy-MM-dd').format(DateTime.now())) {
      return "Today, ${DateFormat('MMMM d').format(this)}";
    }
    return DateFormat('EEEE, MMMM d').format(this);
  }
}

extension StringTimeExtensions on String {
  /// Formats a time string (HH:mm) to "h:mm AM/PM"
  String toAppTimeString() {
    if (!contains(':')) return this;
    try {
      final parts = split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final tod = TimeOfDay(hour: hour, minute: minute);
      
      final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
      final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
      return "$h:${tod.minute.toString().padLeft(2, '0')} $period";
    } catch (e) {
      return this;
    }
  }

  /// Formats a time string (HH:mm) to "h AM/PM" (omitting minutes)
  String to12HourFormat() {
    if (!contains(':')) return this;
    try {
      final parts = split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final timeOfDay = TimeOfDay(hour: hour, minute: minute);

      final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
      final hourOfPeriod =
          timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;

      return "$hourOfPeriod $period";
    } catch (e) {
      return this;
    }
  }

  bool get isNotNullOrEmpty => this.isNotEmpty;
}

extension TimeOfDayExtensions on TimeOfDay {
  /// Formats TimeOfDay to "h:mm AM/PM"
  String toAppTimeString() {
    final h = hourOfPeriod == 0 ? 12 : hourOfPeriod;
    final period = this.period == DayPeriod.am ? 'AM' : 'PM';
    return "$h:${minute.toString().padLeft(2, '0')} $period";
  }
}
