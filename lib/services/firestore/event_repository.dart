import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/event_model.dart';
import '../../core/constants/firestore_constants.dart';
import '../../core/constants/app_constants.dart';

class EventRepository {
  EventRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestoreConstants.eventsCollection);

  Future<void> createEvent(EventModel event) async {
    await _col.doc(event.eventId).set(event.toMap());
  }

  Future<void> updateEvent(EventModel event) async {
    await _col.doc(event.eventId).update(event.toMap());
  }

  Future<void> deleteEvent(String eventId) async {
    await _col.doc(eventId).delete();
  }

  Future<EventModel?> getEvent(String eventId) async {
    final doc = await _col.doc(eventId).get();
    if (!doc.exists) return null;
    return EventModel.fromFirestore(doc);
  }

  /// Stream of all events owned by [uid].
  Stream<List<EventModel>> watchOwnEvents(String uid) {
    return _col
        .where('ownerUid', isEqualTo: uid)
        .orderBy('startTime')
        .snapshots()
        .map((s) => s.docs.map(EventModel.fromFirestore).toList());
  }

  /// Returns events for a date range owned by [uid].
  Future<List<EventModel>> getOwnEventsInRange(
    String uid,
    DateTime start,
    DateTime end,
  ) async {
    final snapshot = await _col
        .where('ownerUid', isEqualTo: uid)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    return snapshot.docs.map(EventModel.fromFirestore).toList();
  }

  /// Returns events visible to [viewerUid] that are owned by [ownerUid].
  ///
  /// Visibility rules (enforced client + Firestore rules):
  /// - 'everyone' events: always returned
  /// - 'friends' events: returned only if [isFriend] is true
  /// - 'private' events: never returned (owner sees these via [watchOwnEvents])
  Future<List<EventModel>> getVisibleEventsForUser({
    required String ownerUid,
    required bool isFriend,
  }) async {
    final List<String> visibilities = [AppConstants.visibilityEveryone];
    if (isFriend) visibilities.add(AppConstants.visibilityFriends);

    final snapshot = await _col
        .where('ownerUid', isEqualTo: ownerUid)
        .where('visibility', whereIn: visibilities)
        .orderBy('startTime')
        .get();
    return snapshot.docs.map(EventModel.fromFirestore).toList();
  }

  /// Feed: returns recent public events from a list of user UIDs.
  /// Used to build the friends activity feed.
  Future<List<EventModel>> getFeedEvents({
    required List<String> friendUids,
    required DateTime after,
    int limit = 30,
  }) async {
    if (friendUids.isEmpty) return [];

    // Firestore 'whereIn' supports up to 30 values. For larger friend lists
    // you'd paginate or use a Cloud Function.
    final uidsChunk = friendUids.take(30).toList();

    final snapshot = await _col
        .where('ownerUid', whereIn: uidsChunk)
        .where('visibility', isEqualTo: AppConstants.visibilityEveryone)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(after))
        .orderBy('startTime')
        .limit(limit)
        .get();
    return snapshot.docs.map(EventModel.fromFirestore).toList();
  }
}
