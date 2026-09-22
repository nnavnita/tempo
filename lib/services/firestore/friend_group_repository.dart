import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/friend_group_model.dart';
import '../../core/constants/firestore_constants.dart';
import 'friend_group_policy.dart';
import 'friend_repository.dart';

/// CRUD over `friend_groups`, an owner-private collection of friend groupings.
///
/// Security rules scope every operation to the owner, so no method here takes
/// a caller uid — the signed-in user is always the owner by construction.
class FriendGroupRepository {
  FriendGroupRepository({
    FirebaseFirestore? firestore,
    FriendshipCheck? isFriend,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _isFriend = isFriend ??
            FriendRepository(firestore: firestore).areFriends;

  final FirebaseFirestore _firestore;
  final FriendshipCheck _isFriend;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestoreConstants.friendGroupsCollection);

  Future<FriendGroupModel> createGroup({
    required String ownerUid,
    required String name,
  }) async {
    final ref = _col.doc();
    final now = DateTime.now();
    final group = FriendGroupModel(
      groupId: ref.id,
      ownerUid: ownerUid,
      name: name,
      memberUids: const [],
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(group.toMap());
    return group;
  }

  Future<void> renameGroup(String groupId, String name) async {
    await _col.doc(groupId).update({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes the group document only.
  ///
  /// Events that targeted this group keep a stale id in `includeGroupIds` /
  /// `excludeGroupIds`. Their denormalized `visibleUids` / `excludeUids` are
  /// unaffected, so visibility does not silently change on delete — but a
  /// re-save of such an event will drop the vanished group. Cascade cleanup,
  /// if wanted, belongs with the resolution service in T2.4/T2.7.
  Future<void> deleteGroup(String groupId) async {
    await _col.doc(groupId).delete();
  }

  /// Adds [memberUid] to the group. Uses arrayUnion so concurrent adds from
  /// two devices can't clobber each other via read-modify-write.
  ///
  /// Throws [NotAFriendException] if the owner is not friends with [memberUid],
  /// and [StateError] if the group does not exist.
  Future<void> addMember(String groupId, String memberUid) async {
    final group = await getGroup(groupId);
    if (group == null) {
      throw StateError('Friend group $groupId does not exist.');
    }
    await assertMayJoinGroup(
      ownerUid: group.ownerUid,
      memberUid: memberUid,
      isFriend: _isFriend,
    );
    await _col.doc(groupId).update({
      'memberUids': FieldValue.arrayUnion([memberUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeMember(String groupId, String memberUid) async {
    await _col.doc(groupId).update({
      'memberUids': FieldValue.arrayRemove([memberUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<FriendGroupModel>> watchGroups(String ownerUid) {
    return _col
        .where('ownerUid', isEqualTo: ownerUid)
        .snapshots()
        .map((s) => s.docs.map(FriendGroupModel.fromFirestore).toList());
  }

  Future<FriendGroupModel?> getGroup(String groupId) async {
    final doc = await _col.doc(groupId).get();
    if (!doc.exists) return null;
    return FriendGroupModel.fromFirestore(doc);
  }
}
