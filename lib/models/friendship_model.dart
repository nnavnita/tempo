import 'package:cloud_firestore/cloud_firestore.dart';

class FriendshipModel {
  final String docId; // sorted([uid1, uid2]).join('_')
  final List<String> users;
  final String status; // 'pending' | 'accepted'
  final String requestedBy;
  final DateTime requestedAt;
  final DateTime? acceptedAt;

  const FriendshipModel({
    required this.docId,
    required this.users,
    required this.status,
    required this.requestedBy,
    required this.requestedAt,
    this.acceptedAt,
  });

  bool get isAccepted => status == 'accepted';
  bool get isPending => status == 'pending';

  String otherUid(String myUid) => users.firstWhere((u) => u != myUid);

  factory FriendshipModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FriendshipModel(
      docId: doc.id,
      users: List<String>.from(data['users'] as List),
      status: data['status'] as String,
      requestedBy: data['requestedBy'] as String,
      requestedAt: (data['requestedAt'] as Timestamp).toDate(),
      acceptedAt: data['acceptedAt'] != null
          ? (data['acceptedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'users': users,
        'status': status,
        'requestedBy': requestedBy,
        'requestedAt': Timestamp.fromDate(requestedAt),
        'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      };

  static String buildDocId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}
