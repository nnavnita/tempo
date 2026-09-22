import '../firestore/friend_group_repository.dart';

/// Loads membership for [groupIds], keyed by group id. Groups that no longer
/// exist are simply absent from the result.
typedef GroupMemberLoader = Future<Map<String, List<String>>> Function(
  List<String> groupIds,
);

/// The denormalized uid sets written onto an event document.
///
/// [visibleUids] grants access to uids the event's tier would not otherwise
/// reach. [excludeUids] subtracts from the tier — it is what lets an owner
/// publish an event to `friends` or `everyone` while keeping one person out.
class ResolvedVisibility {
  final List<String> visibleUids;
  final List<String> excludeUids;

  const ResolvedVisibility({
    required this.visibleUids,
    required this.excludeUids,
  });

  bool get isEmpty => visibleUids.isEmpty && excludeUids.isEmpty;
}

/// Expands group and individual targeting into deduped, sorted uid sets.
///
/// Pure — takes group membership as data rather than a repository, so the
/// semantics below can be tested without Firebase.
///
/// Three rules govern the result:
///  * **Exclusion wins.** A uid named on both sides is excluded, and is
///    removed from [ResolvedVisibility.visibleUids] as well as listed in
///    [ResolvedVisibility.excludeUids]. Subtracting eagerly means a rules bug
///    cannot resurrect access the owner revoked.
///  * **The owner is never listed.** Owners reach their own events through the
///    ownership check in the security rules, so naming them here would be
///    redundant in `visibleUids` and actively wrong in `excludeUids`.
///  * **Unknown group ids are skipped.** A group deleted after an event was
///    targeted at it contributes no members rather than throwing.
///
/// Both lists are sorted so that re-resolving unchanged input produces an
/// identical document and writes no spurious Firestore diff.
ResolvedVisibility expandVisibility({
  required String ownerUid,
  List<String> includeGroupIds = const [],
  List<String> includeFriendUids = const [],
  List<String> excludeGroupIds = const [],
  List<String> excludeFriendUids = const [],
  Map<String, List<String>> groupMembers = const {},
}) {
  Set<String> expand(List<String> groupIds, List<String> friendUids) {
    final uids = <String>{...friendUids};
    for (final groupId in groupIds) {
      uids.addAll(groupMembers[groupId] ?? const []);
    }
    return uids..remove(ownerUid);
  }

  final excluded = expand(excludeGroupIds, excludeFriendUids);
  final visible = expand(includeGroupIds, includeFriendUids)
    ..removeAll(excluded);

  return ResolvedVisibility(
    visibleUids: visible.toList()..sort(),
    excludeUids: excluded.toList()..sort(),
  );
}

/// Resolves an event's authored targeting into the uid sets stored on it.
///
/// Wraps [expandVisibility] with the one piece of I/O it needs — loading group
/// membership — so callers hand over selections and get back sets to write.
class VisibilityResolver {
  VisibilityResolver({required GroupMemberLoader loadGroupMembers})
      : _loadGroupMembers = loadGroupMembers;

  /// Builds a resolver backed by the owner's real friend groups.
  factory VisibilityResolver.fromRepository(FriendGroupRepository repository) {
    return VisibilityResolver(
      loadGroupMembers: (groupIds) async {
        final groups = await Future.wait(groupIds.map(repository.getGroup));
        return {
          for (final group in groups)
            if (group != null) group.groupId: group.memberUids,
        };
      },
    );
  }

  final GroupMemberLoader _loadGroupMembers;

  Future<ResolvedVisibility> resolve({
    required String ownerUid,
    List<String> includeGroupIds = const [],
    List<String> includeFriendUids = const [],
    List<String> excludeGroupIds = const [],
    List<String> excludeFriendUids = const [],
  }) async {
    final referenced = {...includeGroupIds, ...excludeGroupIds};

    // Individual-only targeting is the common case; don't pay a read for it.
    final groupMembers = referenced.isEmpty
        ? const <String, List<String>>{}
        : await _loadGroupMembers(referenced.toList());

    return expandVisibility(
      ownerUid: ownerUid,
      includeGroupIds: includeGroupIds,
      includeFriendUids: includeFriendUids,
      excludeGroupIds: excludeGroupIds,
      excludeFriendUids: excludeFriendUids,
      groupMembers: groupMembers,
    );
  }
}
