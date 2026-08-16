import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/friendship_model.dart';
import '../../core/constants/firestore_constants.dart';
import '../../core/constants/app_constants.dart';

class FriendRepository {
  FriendRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestoreConstants.friendshipsCollection);

  /// Sends a friend request from [fromUid] to [toUid].
  /// Uses a deterministic doc ID to prevent duplicates.
  Future<void> sendFriendRequest({
    required String fromUid,
    required String toUid,
  }) async {
    final docId = FriendshipModel.buildDocId(fromUid, toUid);
    final now = DateTime.now();
    final friendship = FriendshipModel(
      docId: docId,
      users: [fromUid, toUid],
      status: AppConstants.friendshipPending,
      requestedBy: fromUid,
      requestedAt: now,
    );
    await _col.doc(docId).set(friendship.toMap());
  }

  Future<void> acceptFriendRequest(String docId) async {
    await _col.doc(docId).update({
      'status': AppConstants.friendshipAccepted,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> declineFriendRequest(String docId) async {
    await _col.doc(docId).delete();
  }

  Future<void> removeFriend(String uid1, String uid2) async {
    final docId = FriendshipModel.buildDocId(uid1, uid2);
    await _col.doc(docId).delete();
  }

  /// Gets the friendship document between two users, or null if none.
  Future<FriendshipModel?> getFriendship(String uid1, String uid2) async {
    final docId = FriendshipModel.buildDocId(uid1, uid2);
    final doc = await _col.doc(docId).get();
    if (!doc.exists) return null;
    return FriendshipModel.fromFirestore(doc);
  }

  Future<bool> areFriends(String uid1, String uid2) async {
    final friendship = await getFriendship(uid1, uid2);
    return friendship?.isAccepted ?? false;
  }

  /// Stream of all accepted friendships for [uid].
  Stream<List<FriendshipModel>> watchFriends(String uid) {
    return _col
        .where('users', arrayContains: uid)
        .where('status', isEqualTo: AppConstants.friendshipAccepted)
        .snapshots()
        .map((s) => s.docs.map(FriendshipModel.fromFirestore).toList());
  }

  /// Stream of pending incoming friend requests for [uid].
  Stream<List<FriendshipModel>> watchIncomingRequests(String uid) {
    return _col
        .where('users', arrayContains: uid)
        .where('status', isEqualTo: AppConstants.friendshipPending)
        .snapshots()
        .map((s) => s.docs
            .map(FriendshipModel.fromFirestore)
            .where((f) => f.requestedBy != uid) // only incoming
            .toList());
  }
}
