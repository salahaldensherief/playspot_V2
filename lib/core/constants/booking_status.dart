enum BookingStatus {
  pending('pending'),
  upcoming('upcoming'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  final String value;
  const BookingStatus(this.value);

  // Constants for direct string reference if needed
  static const String pendingVal = 'pending';
  static const String upcomingVal = 'upcoming';
  static const String inProgressVal = 'in_progress';
  static const String completedVal = 'completed';
  static const String cancelledVal = 'cancelled';

  /// Parses any status string (including 'rejected', 'declined', 'refused')
  /// into a type-safe [BookingStatus] enum.
  static BookingStatus fromString(String? status) {
    if (status == null) return BookingStatus.pending;
    final normalized = status.toLowerCase().trim();
    switch (normalized) {
      case 'pending':
        return BookingStatus.pending;
      case 'upcoming':
      case 'confirmed':
      case 'approved':
        return BookingStatus.upcoming;
      case 'in_progress':
      case 'inprogress':
      case 'active':
        return BookingStatus.inProgress;
      case 'completed':
      case 'finished':
      case 'done':
        return BookingStatus.completed;
      case 'rejected':
      case 'declined':
      case 'refused':
      case 'cancelled':
      case 'canceled':
        return BookingStatus.cancelled;
      default:
        return BookingStatus.pending;
    }
  }

  /// Ensures any input status string (such as 'rejected', 'declined') is automatically mapped to
  /// a valid database status ('cancelled', 'upcoming', 'in_progress', 'completed', 'pending').
  static String mapToDbStatus(String? status) {
    return fromString(status).value;
  }
}
