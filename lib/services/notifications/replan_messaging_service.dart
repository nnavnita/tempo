import 'package:firebase_messaging/firebase_messaging.dart';

/// Message type the slip-detection Cloud Function sends when the plan has
/// gone stale. Must match the `type` field in functions/index.js.
const String replanRequiredMessageType = 'replan_required';

/// Listens for the server's "your plan is stale" push and registers this
/// device's FCM token.
///
/// The server marks missed slots but deliberately does not re-place work —
/// placement has one implementation, the Dart solver, and duplicating it in
/// the function would guarantee drift. So the server tells the client when
/// to re-plan, and this is what hears it.
class ReplanMessagingService {
  ReplanMessagingService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  Future<void> requestPermission() async {
    await _messaging.requestPermission(alert: true, badge: false, sound: true);
  }

  Future<String?> currentToken() => _messaging.getToken();

  /// Fires [onReplanRequired] for foreground messages and for a message that
  /// opened the app. Terminated-state delivery needs a top-level background
  /// handler registered in main.dart.
  void listen(void Function() onReplanRequired) {
    FirebaseMessaging.onMessage.listen((message) {
      if (_isReplanRequest(message)) onReplanRequired();
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (_isReplanRequest(message)) onReplanRequired();
    });
  }

  /// Token rotation is not rare — reinstalls, restores and cache clears all
  /// mint a new one. Missing a rotation means the server silently stops being
  /// able to reach this device.
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  bool _isReplanRequest(RemoteMessage message) =>
      message.data['type'] == replanRequiredMessageType;
}
