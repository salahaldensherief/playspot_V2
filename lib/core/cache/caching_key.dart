class CachingKey {
  // Legacy reviewedBookings also stored prompts, so it cannot prove persistence.
  static const String confirmedReviewedBookings =
      'CONFIRMED_REVIEWED_BOOKINGS_V1';
  static const String token = 'TOKEN';
  static const String fcmToken = 'FCM_TOKEN';
  static const String authToken = 'AUTH_TOKEN';
  static const String fullName = 'fullName';
  static const String phoneNumber = 'phoneNumber';
  static const String userId = 'UserId';
  static const String userData = 'UserData';

  static const String userDataBackup = 'UserDataBackup';
  static const String appleProfilePrefix = 'AppleProfile_';

  static const String activeCountry = 'ActiveCountry';
  static const String isLoggedIn = 'IS_LOGGED_IN';
  static const String language = 'LANGUAGE';
  static const String isFirstTime = 'IS_FIRST_TIME';
  static const String isGuestUser = 'IS_GUEST_USER';
  static const String userModel = 'USER_MODEL';
  static const String isDarkMode = 'IS_DARK_MODE';
  static const String pendingReferralCode = 'PENDING_REFERRAL_CODE';

  static const String latitude = 'LATITUDE';
  static const String longitude = 'LONGITUDE';

  // Notification Settings
  static const String pushNotifEnabled = 'PUSH_NOTIF_ENABLED';
  static const String bookingUpdatesEnabled = 'BOOKING_UPDATES_ENABLED';
  static const String offersEnabled = 'OFFERS_ENABLED';
  static const String systemNotifEnabled = 'SYSTEM_NOTIF_ENABLED';
  static const String tournamentsEnabled = 'TOURNAMENTS_ENABLED';

  // Cache-First Cache Keys
  static const String loungeProfilesPrefix = 'CACHED_LOUNGE_PROFILE_';
  static const String loungeRoomsPrefix = 'CACHED_LOUNGE_ROOMS_';
  static const String loungeExtrasPrefix = 'CACHED_LOUNGE_EXTRAS_';
  static const String categoriesCache = 'CACHED_CATEGORIES';
  static const String promotionsCache = 'CACHED_PROMOTIONS';
  static const String cachedLounges = 'CACHED_LOUNGES';
  static const String currentAddress = 'CURRENT_ADDRESS';
  static const String reviewedBookings = 'REVIEWED_BOOKINGS';
}
