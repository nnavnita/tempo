import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../core/constants/firestore_constants.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestoreConstants.usersCollection);

  Future<void> upsertUser(UserModel user) async {
    await _col.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _col.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Stream<UserModel?> watchUser(String uid) {
    return _col.doc(uid).snapshots().map(
          (doc) => doc.exists ? UserModel.fromFirestore(doc) : null,
        );
  }

  Future<void> updateFcmToken(String uid, String token) async {
    await _col.doc(uid).update({'fcmToken': token, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Search users by displayName prefix (case-sensitive).
  /// Requires a Firestore composite index on [displayName].
  Future<List<UserModel>> searchByName(String query, {int limit = 20}) async {
    if (query.isEmpty) return [];
    final end = '$query\uf8ff';
    final snapshot = await _col
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThanOrEqualTo: end)
        .limit(limit)
        .get();
    return snapshot.docs.map(UserModel.fromFirestore).toList();
  }
}
