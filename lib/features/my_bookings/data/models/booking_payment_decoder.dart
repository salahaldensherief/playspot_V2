import 'package:playspot/core/constants/app_config.dart';
import 'package:playspot/core/models/payment_model.dart';

class BookingPaymentDecoder {
  final Map<String, dynamic> json;
  late final Map<String, dynamic>? data = _data();
  BookingPaymentDecoder(this.json);

  Map<String, dynamic>? _data() {
    final raw = json['payments'];
    final item = raw is List ? (raw.isEmpty ? null : raw.first) : raw;
    return item is Map ? Map<String, dynamic>.from(item) : null;
  }

  PaymentModel? get payment {
    final current = data;
    return current == null ? null : PaymentModel.fromJson(current);
  }

  DateTime? get paidAt =>
      DateTime.tryParse('${json['paid_at'] ?? data?['paid_at']}');

  String? get proofImageUrl {
    final raw =
        _proof(json, [
          'proof_image_url',
          'receipt_url',
          'proof_url',
          'receipt_image_url',
          'payment_receipt_url',
          'payment_proof_url',
          'receipt_image',
          'proof_image',
          'receipt',
          'proof',
          'image_url',
        ]) ??
        _proof(data ?? {}, [
          'proof_image_url',
          'receipt_url',
          'proof_url',
          'receipt_image_url',
          'image_url',
        ]);
    if (raw == null || raw.isEmpty || raw == 'null' || raw == 'undefined') {
      return null;
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    // receipts/proof.jpg or payment-proofs/proof.jpg -> proof.jpg.
    final path = raw.replaceAll(RegExp(r'^(receipts/|payment-proofs/)'), '');
    return '${AppConfig.supabaseUrl}/storage/v1/object/public/receipts/$path';
  }

  String? _proof(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      if (source[key] != null) return source[key].toString().trim();
    }
    return null;
  }
}
