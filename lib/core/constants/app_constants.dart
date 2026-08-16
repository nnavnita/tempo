class AppConstants {
  AppConstants._();

  static const String appName = 'Tempo';

  // Google OAuth scopes
  static const List<String> googleScopes = [
    'email',
    'profile',
    'https://www.googleapis.com/auth/calendar',
  ];

  // Event visibility values
  static const String visibilityPrivate = 'private';
  static const String visibilityFriends = 'friends';
  static const String visibilityEveryone = 'everyone';

  // Friendship status values
  static const String friendshipPending = 'pending';
  static const String friendshipAccepted = 'accepted';

  // Request/invitation status values
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusDenied = 'denied';
  static const String statusAccepted = 'accepted';
  static const String statusRejected = 'rejected';
}
