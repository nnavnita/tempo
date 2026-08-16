import 'package:cloud_firestore/cloud_firestore.dart';

class JoinRequestModel {
  final String requestId;
  final String eventId;
  final String eventOwnerUid;
  final String requesterUid;
  final String status; // 'pending' | 'approved' | 'denied'
  final DateTime requestedAt;
  final DateTime? resolvedAt;

  const JoinRequestModel({
    required this.requestId,
    required this.eventId,
    required this.eventOwnerUid,
    required this.requesterUid,
    required this.status,
    required this.requestedAt,
    this.resolvedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDenied => status == 'denied';

  factory JoinRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JoinRequestModel(
      requestId: data['requestId'] as String,
      eventId: data['eventId'] as String,
      eventOwnerUid: data['eventOwnerUid'] as String,
      requesterUid: data['requesterUid'] as String,
      status: data['status'] as String,
      requestedAt: (data['requestedAt'] as Timestamp).toDate(),
      resolvedAt: data['resolvedAt'] != null
          ? (data['resolvedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'requestId': requestId,
        'eventId': eventId,
        'eventOwnerUid': eventOwnerUid,
        'requesterUid': requesterUid,
        'status': status,
        'requestedAt': Timestamp.fromDate(requestedAt),
        'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      };
}
