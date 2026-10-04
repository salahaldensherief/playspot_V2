import 'package:equatable/equatable.dart';

class LoungeOperatingStatus extends Equatable {
  final String status;
  final bool canBookOnline;
  final String? contactPhone;

  const LoungeOperatingStatus({
    required this.status,
    required this.canBookOnline,
    this.contactPhone,
  });

  bool get isOpen => status == 'open';
  bool get isTechnicalIssue => status == 'technical_issue';
  bool get isClosed => status == 'closed' || status == 'unavailable';

  factory LoungeOperatingStatus.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    final canBook = json['can_book_online'];
    if (!const {
          'open',
          'closed',
          'technical_issue',
          'unavailable',
        }.contains(status) ||
        canBook is! bool ||
        (canBook && status != 'open') ||
        (json['contact_phone'] != null && json['contact_phone'] is! String)) {
      throw const FormatException('invalid_lounge_operating_status');
    }
    return LoungeOperatingStatus(
      status: status as String,
      canBookOnline: canBook,
      contactPhone: json['contact_phone']?.toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'can_book_online': canBookOnline,
    if (contactPhone != null) 'contact_phone': contactPhone,
  };

  @override
  List<Object?> get props => [status, canBookOnline, contactPhone];
}
