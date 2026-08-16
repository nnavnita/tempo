import 'package:cloud_firestore/cloud_firestore.dart';

class InvitationModel {
  final String invitationId;
  final String eventId;
  final String eventOwnerUid;
  final String inviteeUid;
  final String status; // 'pending' | 'accepted' | 'rejected'
  final DateTime sentAt;
  final DateTime? respondedAt;

  const InvitationModel({
    required this.invitationId,
    required this.eventId,
    required this.eventOwnerUid,
    required this.inviteeUid,
    required this.status,
    required this.sentAt,
    this.respondedAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  factory InvitationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InvitationModel(
      invitationId: data['invitationId'] as String,
      eventId: data['eventId'] as String,
      eventOwnerUid: data['eventOwnerUid'] as String,
      inviteeUid: data['inviteeUid'] as String,
      status: data['status'] as String,
      sentAt: (data['sentAt'] as Timestamp).toDate(),
      respondedAt: data['respondedAt'] != null
          ? (data['respondedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'invitationId': invitationId,
        'eventId': eventId,
        'eventOwnerUid': eventOwnerUid,
        'inviteeUid': inviteeUid,
        'status': status,
        'sentAt': Timestamp.fromDate(sentAt),
        'respondedAt':
            respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      };
}
