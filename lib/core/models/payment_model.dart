import 'package:equatable/equatable.dart';

class PaymentModel extends Equatable {
  final String id;
  final String bookingId;
  final double amount;
  final double? discountAmount;
  final String paymentMethod;
  final String status;
  final DateTime? paidAt;
  final DateTime? createdAt;

  const PaymentModel({
    required this.id,
    required this.bookingId,
    required this.amount,
    this.discountAmount,
    required this.paymentMethod,
    required this.status,
    this.paidAt,
    this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id']?.toString() ?? '',
      bookingId: json['booking_id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble(),
      paymentMethod: json['payment_method']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'booking_id': bookingId,
        'amount': amount,
        if (discountAmount != null) 'discount_amount': discountAmount,
        'payment_method': paymentMethod,
        'status': status,
        if (paidAt != null) 'paid_at': paidAt!.toIso8601String(),
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  PaymentModel copyWith({
    String? id,
    String? bookingId,
    double? amount,
    double? discountAmount,
    String? paymentMethod,
    String? status,
    DateTime? paidAt,
    DateTime? createdAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      amount: amount ?? this.amount,
      discountAmount: discountAmount ?? this.discountAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        bookingId,
        amount,
        discountAmount,
        paymentMethod,
        status,
        paidAt,
        createdAt,
      ];
}
