class LocalizedDurationFormatter {
  const LocalizedDurationFormatter._();

  /// Formats remaining time into natural, grammatically correct phrasing
  /// for both Arabic and English with full plural support.
  static String formatRemainingTime(Duration remaining, {required bool isArabic}) {
    if (remaining.inSeconds <= 0) {
      return isArabic ? 'انتهت الجلسة' : 'Session ended';
    }

    final hours = remaining.inHours;
    final mins = remaining.inMinutes % 60;
    final secs = remaining.inSeconds % 60;

    if (isArabic) {
      return _formatArabicRemaining(hours, mins, secs);
    } else {
      return _formatEnglishRemaining(hours, mins, secs);
    }
  }

  /// Formats total play duration (e.g. for session summaries)
  static String formatPlayDuration(int durationMinutes, {required bool isArabic}) {
    if (durationMinutes <= 0) {
      return isArabic ? '0 دقيقة' : '0 mins';
    }

    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;

    if (isArabic) {
      if (hours > 0 && mins > 0) {
        return '${_arabicHours(hours)} و ${_arabicMinutes(mins)}';
      } else if (hours > 0) {
        return _arabicHours(hours);
      } else {
        return _arabicMinutes(mins);
      }
    } else {
      if (hours > 0 && mins > 0) {
        return '$hours hr $mins min';
      } else if (hours > 0) {
        return hours == 1 ? '1 hour' : '$hours hours';
      } else {
        return '$mins mins';
      }
    }
  }

  static String _formatArabicRemaining(int hours, int mins, int secs) {
    if (hours > 0 && mins > 0) {
      return 'متبقي ${_arabicHours(hours)} و ${_arabicMinutes(mins)}';
    } else if (hours > 0) {
      return 'متبقي ${_arabicHours(hours)}';
    } else if (mins > 0 && secs > 0) {
      return 'متبقي ${_arabicMinutes(mins)} و ${_arabicSeconds(secs)}';
    } else if (mins > 0) {
      return 'متبقي ${_arabicMinutes(mins)}';
    } else {
      return 'متبقي ${_arabicSeconds(secs)}';
    }
  }

  static String _formatEnglishRemaining(int hours, int mins, int secs) {
    if (hours > 0 && mins > 0) {
      return '$hours h $mins m remaining';
    } else if (hours > 0) {
      return hours == 1 ? '1 hour remaining' : '$hours hours remaining';
    } else if (mins > 0 && secs > 0) {
      return '$mins m ${secs}s remaining';
    } else if (mins > 0) {
      return mins == 1 ? '1 min remaining' : '$mins mins remaining';
    } else {
      return '${secs}s remaining';
    }
  }

  static String _arabicHours(int count) {
    if (count == 1) return 'ساعة واحدة';
    if (count == 2) return 'ساعتان';
    if (count >= 3 && count <= 10) return '$count ساعات';
    return '$count ساعة';
  }

  static String _arabicMinutes(int count) {
    if (count == 1) return 'دقيقة واحدة';
    if (count == 2) return 'دقيقتان';
    if (count >= 3 && count <= 10) return '$count دقائق';
    return '$count دقيقة';
  }

  static String _arabicSeconds(int count) {
    if (count == 1) return 'ثانية واحدة';
    if (count == 2) return 'ثانيتان';
    if (count >= 3 && count <= 10) return '$count ثوانٍ';
    return '$count ثانية';
  }
}
