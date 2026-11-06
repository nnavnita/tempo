class FirestoreConstants {
  FirestoreConstants._();

  // Collections. Tasks, slots, plan state and the busy cache are all
  // subcollections of users/{uid} — this product has no cross-user reads.
  static const String usersCollection = 'users';
  static const String tasksCollection = 'tasks';
  static const String slotsCollection = 'slots';
  static const String planStateCollection = 'planState';
  static const String busyCacheCollection = 'busyCache';

  /// Single document id under [planStateCollection].
  static const String planStateCurrentDoc = 'current';

  // User fields
  static const String uid = 'uid';
  static const String displayName = 'displayName';
  static const String email = 'email';
  static const String photoURL = 'photoURL';
  static const String fcmToken = 'fcmToken';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';

  // Task fields
  static const String taskId = 'taskId';
  static const String title = 'title';
  static const String notes = 'notes';
  static const String durationMinutes = 'durationMinutes';
  static const String deadline = 'deadline';
  static const String priority = 'priority';
  static const String status = 'status';
  static const String splittable = 'splittable';
  static const String minChunkMinutes = 'minChunkMinutes';
  static const String slipCount = 'slipCount';
  static const String completedAt = 'completedAt';

  // Slot fields
  static const String slotId = 'slotId';
  static const String start = 'start';
  static const String end = 'end';
  static const String state = 'state';
  static const String googleCalendarEventId = 'googleCalendarEventId';
  static const String planVersion = 'planVersion';

  // Plan state fields (reuses planVersion)
  static const String generatedAt = 'generatedAt';
  static const String horizonStart = 'horizonStart';
  static const String horizonEnd = 'horizonEnd';
  static const String lastReplanReason = 'lastReplanReason';

  // Busy cache fields
  static const String dayKey = 'dayKey';
  static const String intervals = 'intervals';
  static const String cachedAt = 'cachedAt';
}
