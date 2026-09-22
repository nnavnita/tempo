/// Returns whether [uidA] and [uidB] have an accepted friendship.
typedef FriendshipCheck = Future<bool> Function(String uidA, String uidB);

/// Thrown when a uid is added to a friend group without an accepted friendship.
class NotAFriendException implements Exception {
  final String memberUid;

  const NotAFriendException(this.memberUid);

  @override
  String toString() =>
      'NotAFriendException: $memberUid is not an accepted friend and cannot '
      'join a friend group.';
}

/// Guards group membership against uids the owner is not friends with.
///
/// Group membership feeds `visibleUids` on events, so an unfriended member
/// would be granted visibility that the `friends` tier itself would deny —
/// two contradicting definitions of who may see an event. Enforcing the
/// friendship here keeps the resolution service free to treat membership as
/// already-trusted.
Future<void> assertMayJoinGroup({
  required String ownerUid,
  required String memberUid,
  required FriendshipCheck isFriend,
}) async {
  if (memberUid == ownerUid) {
    throw ArgumentError.value(
      memberUid,
      'memberUid',
      'an owner is already implicitly in every group they own',
    );
  }

  if (!await isFriend(ownerUid, memberUid)) {
    throw NotAFriendException(memberUid);
  }
}
