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
  final String? mapsLink;

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
    this.mapsLink,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final loungeData = json['lounges'] as Map<String, dynamic>?;
    final roomData = json['rooms'] as Map<String, dynamic>?;

    return BookingModel(
      id: json['id'].toString(),
      loungeName: loungeData?['name'] ?? '',
      loungeLocation: loungeData?['location'] ?? '',
      roomName: roomData?['name_en'] ?? roomData?['name'] ?? '',
      controllersCount: roomData?['controllers_count'] ?? 0,
      screenSize: roomData?['screen_size'] ?? '',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      status: json['status'] ?? 'past',
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      mapsLink: loungeData?['maps_link'],
    );
  }
}
