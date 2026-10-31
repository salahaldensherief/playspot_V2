import 'package:equatable/equatable.dart';

class LoungeOperatingStatus extends Equatable {
  final String status;
  final bool canBookOnline;
  final String? contactPhone;
  final DateTime? futureBookingDateFrom;

  const LoungeOperatingStatus({
    required this.status,
    required this.canBookOnline,
    this.contactPhone,
    this.futureBookingDateFrom,
  });

  bool get isOpen => status == 'open';
  bool get isTechnicalIssue => status == 'technical_issue';
  bool get isClosed => status == 'closed' || status == 'unavailable';

  bool canBookOnDate(DateTime? date) {
    if (isOpen && canBookOnline) {
      return true;
    }
    final earliest = futureBookingDateFrom;
    if (status == 'unavailable' || date == null || earliest == null) {
      return false;
    }
    final calendarDate = DateTime.utc(date.year, date.month, date.day);
    return !calendarDate.isBefore(
      DateTime.utc(earliest.year, earliest.month, earliest.day),
    );
  }

  factory LoungeOperatingStatus.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    final canBook = json['can_book_online'];
    final futureDate = json['future_booking_date_from'];
    final parsedFutureDate = futureDate is String
        ? DateTime.tryParse(futureDate)
        : null;
    if (!const {
          'open',
          'closed',
          'technical_issue',
          'unavailable',
        }.contains(status) ||
        canBook is! bool ||
        (canBook && status != 'open') ||
        (futureDate != null &&
            (futureDate is! String ||
                futureDate.length != 10 ||
                parsedFutureDate == null ||
                parsedFutureDate.toIso8601String().substring(0, 10) !=
                    futureDate ||
                status == 'unavailable')) ||
        (json['contact_phone'] != null && json['contact_phone'] is! String)) {
      throw const FormatException('invalid_lounge_operating_status');
    }
    return LoungeOperatingStatus(
      status: status as String,
      canBookOnline: canBook,
      contactPhone: json['contact_phone']?.toString().trim(),
      futureBookingDateFrom: parsedFutureDate,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'can_book_online': canBookOnline,
    if (contactPhone != null) 'contact_phone': contactPhone,
    if (futureBookingDateFrom != null)
      'future_booking_date_from': futureBookingDateFrom
          ?.toIso8601String()
          .substring(0, 10),
  };

  @override
  List<Object?> get props => [
    status,
    canBookOnline,
    contactPhone,
    futureBookingDateFrom,
  ];
}
