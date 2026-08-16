class FirestoreConstants {
  FirestoreConstants._();

  // Collections
  static const String usersCollection = 'users';
  static const String eventsCollection = 'events';
  static const String friendshipsCollection = 'friendships';
  static const String joinRequestsCollection = 'join_requests';
  static const String invitationsCollection = 'invitations';
  static const String busySlotsCollection = 'busy_slots';

  // User fields
  static const String uid = 'uid';
  static const String displayName = 'displayName';
  static const String email = 'email';
  static const String photoURL = 'photoURL';
  static const String fcmToken = 'fcmToken';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';

  // Event fields
  static const String eventId = 'eventId';
  static const String ownerUid = 'ownerUid';
  static const String title = 'title';
  static const String description = 'description';
  static const String location = 'location';
  static const String startTime = 'startTime';
  static const String endTime = 'endTime';
  static const String visibility = 'visibility';
  static const String googleCalendarEventId = 'googleCalendarEventId';
  static const String attendeeUids = 'attendeeUids';

  // Friendship fields
  static const String users = 'users';
  static const String status = 'status';
  static const String requestedBy = 'requestedBy';
  static const String requestedAt = 'requestedAt';
  static const String acceptedAt = 'acceptedAt';

  // Join request / invitation fields
  static const String requestId = 'requestId';
  static const String invitationId = 'invitationId';
  static const String eventOwnerUid = 'eventOwnerUid';
  static const String requesterUid = 'requesterUid';
  static const String inviteeUid = 'inviteeUid';
  static const String resolvedAt = 'resolvedAt';
  static const String respondedAt = 'respondedAt';
  static const String sentAt = 'sentAt';
}
