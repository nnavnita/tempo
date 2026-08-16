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
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
