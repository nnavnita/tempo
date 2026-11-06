class AppConstants {
  AppConstants._();

  static const String appName = 'Tempo';

  // Google OAuth scopes
  static const List<String> googleScopes = [
    'email',
    'profile',
    'https://www.googleapis.com/auth/calendar',
  ];

  /// How many slot notifications to register with the OS at once.
  ///
  /// iOS caps pending local notifications at 64 per app and silently drops
  /// the rest, so the client only ever holds the near horizon. Everything
  /// beyond this — and every re-plan alert — arrives by FCM from the
  /// scheduled Cloud Function.
  static const int localNotificationHorizon = 20;

  /// Fallback zone when the device zone cannot be resolved.
  static const String fallbackTimeZone = 'Australia/Melbourne';
}
