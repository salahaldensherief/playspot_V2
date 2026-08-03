class BookingModel {
  final String id;
  final String loungeName;
  final String loungeLocation;
  final String roomName;
  final int controllersCount;
  final String screenSize;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String status; // upcoming, past, cancelled
  final double totalPrice;

  BookingModel({
    required this.id,
    required this.loungeName,
    required this.loungeLocation,
    required this.roomName,
    required this.controllersCount,
    required this.screenSize,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.totalPrice,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'].toString(),
      loungeName: json['lounges']['name'],
      loungeLocation: json['lounges']['location'],
      roomName: json['rooms']['name_en'] ?? json['rooms']['name'] ?? '',
      controllersCount: json['rooms']['controllers_count'] ?? 0,
      screenSize: json['rooms']['screen_size'] ?? '',
      date: DateTime.parse(json['date']),
      startTime: json['start_time'],
      endTime: json['end_time'],
      status: json['status'],
      totalPrice: (json['total_price'] as num).toDouble(),
    );
  }
}
