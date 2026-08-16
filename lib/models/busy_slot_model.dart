import 'package:cloud_firestore/cloud_firestore.dart';

class BusySlotModel {
  final String slotId; // '{ownerUid}_{eventId}'
  final String ownerUid;
  final String eventId;
  final DateTime startTime;
  final DateTime endTime;

  const BusySlotModel({
    required this.slotId,
    required this.ownerUid,
    required this.eventId,
    required this.startTime,
    required this.endTime,
  });

  factory BusySlotModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusySlotModel(
      slotId: doc.id,
      ownerUid: data['ownerUid'] as String,
      eventId: data['eventId'] as String,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'eventId': eventId,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
      };

  static String buildSlotId(String ownerUid, String eventId) =>
      '${ownerUid}_$eventId';
}
