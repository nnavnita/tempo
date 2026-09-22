import 'package:cloud_firestore/cloud_firestore.dart';

/// A private, owner-scoped grouping of friends (e.g. "Uni", "Work").
///
/// Groups are never readable by their members — only by [ownerUid]. Membership
/// leaks to a member only indirectly, via events targeted at the group.
class FriendGroupModel {
  final String groupId;
  final String ownerUid;
  final String name;
  final List<String> memberUids;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FriendGroupModel({
    required this.groupId,
    required this.ownerUid,
    required this.name,
    this.memberUids = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  int get memberCount => memberUids.length;

  bool hasMember(String uid) => memberUids.contains(uid);

  factory FriendGroupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FriendGroupModel(
      groupId: doc.id,
      ownerUid: data['ownerUid'] as String,
      name: data['name'] as String,
      memberUids: List<String>.from(data['memberUids'] as List? ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'ownerUid': ownerUid,
        'name': name,
        'memberUids': memberUids,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  FriendGroupModel copyWith({
    String? name,
    List<String>? memberUids,
  }) {
    return FriendGroupModel(
      groupId: groupId,
      ownerUid: ownerUid,
      name: name ?? this.name,
      memberUids: memberUids ?? this.memberUids,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
