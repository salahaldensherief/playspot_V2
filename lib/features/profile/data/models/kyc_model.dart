import 'package:equatable/equatable.dart';

enum KycStatus { notSubmitted, pending, approved, rejected }

class KycModel extends Equatable {
  final String? id;
  final String userId;
  final String? nationalId;
  final String? documentPath;
  final String? signedUrl;
  final KycStatus status;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const KycModel({
    this.id,
    required this.userId,
    this.nationalId,
    this.documentPath,
    this.signedUrl,
    this.status = KycStatus.notSubmitted,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  factory KycModel.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status']?.toString().toLowerCase() ?? '';
    KycStatus status;
    if (statusStr == 'approved') {
      status = KycStatus.approved;
    } else if (statusStr == 'rejected') {
      status = KycStatus.rejected;
    } else if (statusStr == 'pending' || statusStr == 'submitted') {
      status = KycStatus.pending;
    } else {
      status = KycStatus.notSubmitted;
    }

    return KycModel(
      id: json['id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      nationalId: json['national_id']?.toString() ?? json['id_number']?.toString(),
      documentPath: json['document_url']?.toString() ?? json['document_path']?.toString(),
      signedUrl: json['signed_url']?.toString(),
      status: status,
      rejectionReason: json['rejection_reason']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      if (nationalId != null) 'national_id': nationalId,
      if (documentPath != null) 'document_url': documentPath,
      'status': status.name,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  KycModel copyWith({
    String? id,
    String? userId,
    String? nationalId,
    String? documentPath,
    String? signedUrl,
    KycStatus? status,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KycModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      nationalId: nationalId ?? this.nationalId,
      documentPath: documentPath ?? this.documentPath,
      signedUrl: signedUrl ?? this.signedUrl,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        nationalId,
        documentPath,
        signedUrl,
        status,
        rejectionReason,
        createdAt,
        updatedAt,
      ];
}
