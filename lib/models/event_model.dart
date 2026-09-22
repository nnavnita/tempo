import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class EventModel {
  final String eventId;
  final String ownerUid;
  final String title;
  final String? description;
  final String? location;
  final DateTime startTime;
  final DateTime endTime;
  final String visibility; // 'private' | 'friends' | 'everyone'
  final String? googleCalendarEventId;
  final List<String> attendeeUids;

  // Authored visibility targeting — what the owner picked in the UI.
  final List<String> includeGroupIds;
  final List<String> includeFriendUids;
  final List<String> excludeGroupIds;
  final List<String> excludeFriendUids;

  // Denormalized resolution of the above, written on every event write.
  // Firestore rules can only do membership checks against flat arrays.
  final List<String> visibleUids;
  final List<String> excludeUids;

  final DateTime createdAt;
  final DateTime updatedAt;

  const EventModel({
    required this.eventId,
    required this.ownerUid,
    required this.title,
    this.description,
    this.location,
    required this.startTime,
    required this.endTime,
    required this.visibility,
    this.googleCalendarEventId,
    this.attendeeUids = const [],
    this.includeGroupIds = const [],
    this.includeFriendUids = const [],
    this.excludeGroupIds = const [],
    this.excludeFriendUids = const [],
    this.visibleUids = const [],
    this.excludeUids = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPrivate => visibility == AppConstants.visibilityPrivate;
  bool get isFriendsOnly => visibility == AppConstants.visibilityFriends;
  bool get isPublic => visibility == AppConstants.visibilityEveryone;

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventModel(
      eventId: data['eventId'] as String,
      ownerUid: data['ownerUid'] as String,
      title: data['title'] as String,
      description: data['description'] as String?,
      location: data['location'] as String?,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      visibility: data['visibility'] as String,
      googleCalendarEventId: data['googleCalendarEventId'] as String?,
      attendeeUids: List<String>.from(data['attendeeUids'] as List? ?? []),
      includeGroupIds: List<String>.from(data['includeGroupIds'] as List? ?? []),
      includeFriendUids:
          List<String>.from(data['includeFriendUids'] as List? ?? []),
      excludeGroupIds: List<String>.from(data['excludeGroupIds'] as List? ?? []),
      excludeFriendUids:
          List<String>.from(data['excludeFriendUids'] as List? ?? []),
      visibleUids: List<String>.from(data['visibleUids'] as List? ?? []),
      excludeUids: List<String>.from(data['excludeUids'] as List? ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'eventId': eventId,
        'ownerUid': ownerUid,
        'title': title,
        'description': description,
        'location': location,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'visibility': visibility,
        'googleCalendarEventId': googleCalendarEventId,
        'attendeeUids': attendeeUids,
        'includeGroupIds': includeGroupIds,
        'includeFriendUids': includeFriendUids,
        'excludeGroupIds': excludeGroupIds,
        'excludeFriendUids': excludeFriendUids,
        'visibleUids': visibleUids,
        'excludeUids': excludeUids,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  EventModel copyWith({
    String? title,
    String? description,
    String? location,
    DateTime? startTime,
    DateTime? endTime,
    String? visibility,
    String? googleCalendarEventId,
    List<String>? attendeeUids,
    List<String>? includeGroupIds,
    List<String>? includeFriendUids,
    List<String>? excludeGroupIds,
    List<String>? excludeFriendUids,
    List<String>? visibleUids,
    List<String>? excludeUids,
  }) {
    return EventModel(
      eventId: eventId,
      ownerUid: ownerUid,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      visibility: visibility ?? this.visibility,
      googleCalendarEventId:
          googleCalendarEventId ?? this.googleCalendarEventId,
      attendeeUids: attendeeUids ?? this.attendeeUids,
      includeGroupIds: includeGroupIds ?? this.includeGroupIds,
      includeFriendUids: includeFriendUids ?? this.includeFriendUids,
      excludeGroupIds: excludeGroupIds ?? this.excludeGroupIds,
      excludeFriendUids: excludeFriendUids ?? this.excludeFriendUids,
      visibleUids: visibleUids ?? this.visibleUids,
      excludeUids: excludeUids ?? this.excludeUids,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
