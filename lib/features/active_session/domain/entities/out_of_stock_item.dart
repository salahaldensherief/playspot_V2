import 'package:equatable/equatable.dart';

class OutOfStockItem extends Equatable {
  final String id;
  final String name;
  final int available;
  final int requested;

  const OutOfStockItem({
    required this.id,
    required this.name,
    required this.available,
    required this.requested,
  });

  factory OutOfStockItem.fromJson(Map<String, dynamic> json) {
    return OutOfStockItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      available: (json['available'] as num?)?.toInt() ?? 0,
      requested: (json['requested'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  List<Object?> get props => [id, name, available, requested];
}
