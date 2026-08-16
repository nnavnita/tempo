import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../models/invitation_model.dart';
import '../../core/constants/firestore_constants.dart';
import '../../core/constants/app_constants.dart';

class InvitationRepository {
  InvitationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestoreConstants.invitationsCollection);

  Future<InvitationModel> createInvitation({
    required String eventId,
    required String eventOwnerUid,
    required String inviteeUid,
  }) async {
    final invitationId = _uuid.v4();
    final invitation = InvitationModel(
      invitationId: invitationId,
      eventId: eventId,
      eventOwnerUid: eventOwnerUid,
      inviteeUid: inviteeUid,
      status: AppConstants.statusPending,
      sentAt: DateTime.now(),
    );
    await _col.doc(invitationId).set(invitation.toMap());
    return invitation;
  }

  Future<void> acceptInvitation(String invitationId) async {
    await _col.doc(invitationId).update({
      'status': AppConstants.statusAccepted,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectInvitation(String invitationId) async {
    await _col.doc(invitationId).update({
      'status': AppConstants.statusRejected,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream of pending invitations sent to [inviteeUid].
  Stream<List<InvitationModel>> watchPendingInvitationsForUser(
      String inviteeUid) {
    return _col
        .where('inviteeUid', isEqualTo: inviteeUid)
        .where('status', isEqualTo: AppConstants.statusPending)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(InvitationModel.fromFirestore).toList());
  }

  /// Returns invitations sent for a specific event.
  Future<List<InvitationModel>> getInvitationsForEvent(String eventId) async {
    final snapshot = await _col
        .where('eventId', isEqualTo: eventId)
        .get();
    return snapshot.docs.map(InvitationModel.fromFirestore).toList();
  }

  Future<InvitationModel?> getInvitation(String invitationId) async {
    final doc = await _col.doc(invitationId).get();
    if (!doc.exists) return null;
    return InvitationModel.fromFirestore(doc);
  }
}
