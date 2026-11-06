import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../core/constants/app_constants.dart';
import '../../models/scheduled_slot.dart';

/// Registers OS-level notifications for upcoming slots.
///
/// Only ever holds [AppConstants.localNotificationHorizon] pending
/// notifications. iOS allows 64 per app and silently drops the overflow,
/// so scheduling a whole 14-day plan would quietly lose the far end — and
/// you would not find out until a reminder failed to arrive. Everything
/// past the near horizon is delivered by FCM from the Cloud Function.
class SlotNotificationScheduler {
  SlotNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'tempo_slots';
  static const _channelName = 'Scheduled work';
  static const _channelDescription =
      'Fires when a block of planned work is due to start.';

  Future<void> init() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: false,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(settings);
  }

  /// Replaces all pending slot notifications with ones for [slots].
  ///
  /// Cancel-then-reschedule rather than diffing: a re-plan can move every
  /// slot, and a stale notification firing for a slot that no longer
  /// exists is worse than a moment with none registered.
  Future<void> syncUpcoming({
    required List<ScheduledSlot> slots,
    required Map<String, String> taskTitles,
    required DateTime now,
  }) async {
    await _plugin.cancelAll();

    final upcoming = slots.where((s) => s.start.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    for (final slot in upcoming.take(AppConstants.localNotificationHorizon)) {
      await _schedule(slot, taskTitles[slot.taskId] ?? 'Planned work');
    }
  }

  Future<void> _schedule(ScheduledSlot slot, String title) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      _notificationIdFor(slot),
      title,
      _subtitleFor(slot),
      tz.TZDateTime.from(slot.start, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: slot.slotId,
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  static String _subtitleFor(ScheduledSlot slot) {
    final minutes = slot.duration.inMinutes;
    return minutes >= 60 && minutes % 60 == 0
        ? 'Starting now · ${minutes ~/ 60}h'
        : 'Starting now · ${minutes}m';
  }

  /// Stable 31-bit id derived from the slot id, since the plugin keys
  /// notifications by int. Collisions only cost a replaced notification
  /// for a slot that is being rescheduled anyway.
  static int _notificationIdFor(ScheduledSlot slot) =>
      slot.slotId.hashCode & 0x7fffffff;
}
