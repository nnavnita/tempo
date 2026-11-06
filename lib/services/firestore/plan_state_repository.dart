import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_constants.dart';
import '../../models/plan_state.dart';

class PlanStateRepository {
  PlanStateRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _firestore
      .collection(FirestoreConstants.usersCollection)
      .doc(uid)
      .collection(FirestoreConstants.planStateCollection)
      .doc(FirestoreConstants.planStateCurrentDoc);

  Future<PlanState?> fetch(String uid) async {
    final doc = await _doc(uid).get();
    return doc.exists ? PlanState.fromFirestore(doc) : null;
  }

  Stream<PlanState?> watch(String uid) => _doc(uid).snapshots().map(
        (doc) => doc.exists ? PlanState.fromFirestore(doc) : null,
      );

  Future<void> write(String uid, PlanState state) =>
      _doc(uid).set(state.toMap());
}
