import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_constants.dart';
import '../services/scheduler/time_interval.dart';

enum SlotState { planned, notified, started, done, missed }

/// A concrete block of time a task has been placed into.
///
/// Carries the [planVersion] it was produced by. A re-plan bumps the
/// version, and anything holding an older one is discarded rather than
/// raced against — that is the whole concurrency story.
class ScheduledSlot {
  final String slotId;
  final String taskId;
  final DateTime start;
  final DateTime end;
  final SlotState state;
  final String? googleCalendarEventId;
  final int planVersion;

  const ScheduledSlot({
    required this.slotId,
    required this.taskId,
    required this.start,
    required this.end,
    this.state = SlotState.planned,
    this.googleCalendarEventId,
    required this.planVersion,
  });

  TimeInterval get interval => TimeInterval(start: start, end: end);

  Duration get duration => end.difference(start);

  /// True when the slot's window has closed without the work being done.
  bool hasElapsedUndone(DateTime now) =>
      !end.isAfter(now) &&
      (state == SlotState.planned ||
          state == SlotState.notified ||
          state == SlotState.started);

  factory ScheduledSlot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScheduledSlot(
      slotId: doc.id,
      taskId: data[FirestoreConstants.taskId] as String,
      start: (data[FirestoreConstants.start] as Timestamp).toDate().toUtc(),
      end: (data[FirestoreConstants.end] as Timestamp).toDate().toUtc(),
      state: _stateFromName(data[FirestoreConstants.state] as String?),
      googleCalendarEventId:
          data[FirestoreConstants.googleCalendarEventId] as String?,
      planVersion: data[FirestoreConstants.planVersion] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        FirestoreConstants.taskId: taskId,
        FirestoreConstants.start: Timestamp.fromDate(start),
        FirestoreConstants.end: Timestamp.fromDate(end),
        FirestoreConstants.state: state.name,
        FirestoreConstants.googleCalendarEventId: googleCalendarEventId,
        FirestoreConstants.planVersion: planVersion,
      };

  ScheduledSlot copyWith({
    SlotState? state,
    String? googleCalendarEventId,
  }) =>
      ScheduledSlot(
        slotId: slotId,
        taskId: taskId,
        start: start,
        end: end,
        state: state ?? this.state,
        googleCalendarEventId:
            googleCalendarEventId ?? this.googleCalendarEventId,
        planVersion: planVersion,
      );

  static String buildSlotId(String taskId, DateTime start) =>
      '${taskId}_${start.toUtc().millisecondsSinceEpoch}';

  static SlotState _stateFromName(String? name) => SlotState.values.firstWhere(
        (s) => s.name == name,
        orElse: () => SlotState.planned,
      );
}
