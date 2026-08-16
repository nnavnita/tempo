import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../models/join_request_model.dart';
import '../../core/constants/firestore_constants.dart';
import '../../core/constants/app_constants.dart';

class JoinRequestRepository {
  JoinRequestRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestoreConstants.joinRequestsCollection);

  Future<JoinRequestModel> createRequest({
    required String eventId,
    required String eventOwnerUid,
    required String requesterUid,
  }) async {
    final requestId = _uuid.v4();
    final request = JoinRequestModel(
      requestId: requestId,
      eventId: eventId,
      eventOwnerUid: eventOwnerUid,
      requesterUid: requesterUid,
      status: AppConstants.statusPending,
      requestedAt: DateTime.now(),
    );
    await _col.doc(requestId).set(request.toMap());
    return request;
  }

  Future<void> approveRequest(String requestId) async {
    await _col.doc(requestId).update({
      'status': AppConstants.statusApproved,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> denyRequest(String requestId) async {
    await _col.doc(requestId).update({
      'status': AppConstants.statusDenied,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream of pending join requests for events owned by [ownerUid].
  Stream<List<JoinRequestModel>> watchPendingRequestsForOwner(String ownerUid) {
    return _col
        .where('eventOwnerUid', isEqualTo: ownerUid)
        .where('status', isEqualTo: AppConstants.statusPending)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(JoinRequestModel.fromFirestore).toList());
  }

  /// Returns join requests for a specific event (for the event detail page).
  Stream<List<JoinRequestModel>> watchRequestsForEvent(String eventId) {
    return _col
        .where('eventId', isEqualTo: eventId)
        .where('status', isEqualTo: AppConstants.statusPending)
        .snapshots()
        .map((s) => s.docs.map(JoinRequestModel.fromFirestore).toList());
  }

  /// Returns the join request status for a specific user+event combination.
  Future<JoinRequestModel?> getRequestForUserAndEvent({
    required String requesterUid,
    required String eventId,
  }) async {
    final snapshot = await _col
        .where('requesterUid', isEqualTo: requesterUid)
        .where('eventId', isEqualTo: eventId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return JoinRequestModel.fromFirestore(snapshot.docs.first);
  }
}
