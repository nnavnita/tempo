import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/busy_slot_model.dart';
import '../../core/constants/firestore_constants.dart';

class BusySlotRepository {
  BusySlotRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestoreConstants.busySlotsCollection);

  Future<void> upsertBusySlot(BusySlotModel slot) async {
    await _col.doc(slot.slotId).set(slot.toMap());
  }

  Future<void> deleteBusySlot(String slotId) async {
    await _col.doc(slotId).delete();
  }

  /// Returns all busy slots for [ownerUid] in a given date range.
  /// Any authenticated user can call this — slots have no sensitive detail.
  Future<List<BusySlotModel>> getBusySlotsInRange(
    String ownerUid,
    DateTime start,
    DateTime end,
  ) async {
    final snapshot = await _col
        .where('ownerUid', isEqualTo: ownerUid)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    return snapshot.docs.map(BusySlotModel.fromFirestore).toList();
  }
}
