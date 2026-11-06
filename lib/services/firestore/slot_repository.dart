import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_constants.dart';
import '../../models/scheduled_slot.dart';

class SlotRepository {
  SlotRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _slots(String uid) =>
      _firestore
          .collection(FirestoreConstants.usersCollection)
          .doc(uid)
          .collection(FirestoreConstants.slotsCollection);

  /// Writes a fresh plan: drops future slots belonging to older plan
  /// versions, then writes the new ones, in one batch.
  ///
  /// Past slots are left alone deliberately — they are the record of what
  /// actually happened, and slip detection needs them.
  Future<void> replaceFuturePlan({
    required String uid,
    required List<ScheduledSlot> slots,
    required DateTime from,
  }) async {
    final batch = _firestore.batch();

    final stale = await _slots(uid)
        .where(FirestoreConstants.start,
            isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .get();
    for (final doc in stale.docs) {
      batch.delete(doc.reference);
    }

    for (final slot in slots) {
      batch.set(_slots(uid).doc(slot.slotId), slot.toMap());
    }

    await batch.commit();
  }

  Stream<List<ScheduledSlot>> watchBetween(
    String uid,
    DateTime from,
    DateTime to,
  ) =>
      _slots(uid)
          .where(FirestoreConstants.start,
              isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where(FirestoreConstants.start, isLessThan: Timestamp.fromDate(to))
          .orderBy(FirestoreConstants.start)
          .snapshots()
          .map((s) => s.docs.map(ScheduledSlot.fromFirestore).toList());

  /// Slots whose window has closed but which were never completed. The
  /// slip detector reads this.
  Future<List<ScheduledSlot>> fetchElapsedUndone(
    String uid,
    DateTime now,
  ) async {
    final snapshot = await _slots(uid)
        .where(FirestoreConstants.end, isLessThan: Timestamp.fromDate(now))
        .where(FirestoreConstants.state, whereIn: [
          SlotState.planned.name,
          SlotState.notified.name,
          SlotState.started.name,
        ])
        .get();

    return snapshot.docs.map(ScheduledSlot.fromFirestore).toList();
  }

  /// The next slots due to start, used to decide which notifications to
  /// register locally. iOS caps pending local notifications, so callers
  /// pass a [limit] rather than scheduling the whole horizon.
  Future<List<ScheduledSlot>> fetchUpcoming(
    String uid,
    DateTime now, {
    required int limit,
  }) async {
    final snapshot = await _slots(uid)
        .where(FirestoreConstants.start,
            isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy(FirestoreConstants.start)
        .limit(limit)
        .get();

    return snapshot.docs.map(ScheduledSlot.fromFirestore).toList();
  }

  Future<void> setState(String uid, String slotId, SlotState state) =>
      _slots(uid).doc(slotId).update({FirestoreConstants.state: state.name});
}
