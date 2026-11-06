import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_constants.dart';
import '../../models/task_model.dart';

/// Tasks live under `users/{uid}/tasks`. This product has no cross-user
/// reads, so user-scoping the collection keeps the security rules to a
/// single owner check rather than per-document predicates.
class TaskRepository {
  TaskRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _tasks(String uid) =>
      _firestore
          .collection(FirestoreConstants.usersCollection)
          .doc(uid)
          .collection(FirestoreConstants.tasksCollection);

  Future<String> create(String uid, TaskModel task) async {
    final doc = _tasks(uid).doc();
    await doc.set(task.toMap());
    return doc.id;
  }

  Future<void> update(String uid, TaskModel task) =>
      _tasks(uid).doc(task.taskId).set(task.toMap());

  Future<void> delete(String uid, String taskId) =>
      _tasks(uid).doc(taskId).delete();

  Future<TaskModel?> fetch(String uid, String taskId) async {
    final doc = await _tasks(uid).doc(taskId).get();
    return doc.exists ? TaskModel.fromFirestore(doc) : null;
  }

  /// Tasks the solver should consider. Done tasks are excluded; `slipped`
  /// (stuck) tasks are excluded too — they are waiting on the user, and
  /// re-placing them is exactly the graveyard behaviour we are avoiding.
  Future<List<TaskModel>> fetchPlannable(String uid) async {
    final snapshot = await _tasks(uid).where(
      FirestoreConstants.status,
      whereIn: [
        TaskStatus.inbox.name,
        TaskStatus.scheduled.name,
        TaskStatus.unplaceable.name,
      ],
    ).get();

    return snapshot.docs.map(TaskModel.fromFirestore).toList();
  }

  Stream<List<TaskModel>> watchAll(String uid) => _tasks(uid)
      .orderBy(FirestoreConstants.createdAt, descending: true)
      .snapshots()
      .map((s) => s.docs.map(TaskModel.fromFirestore).toList());

  /// Tasks needing the user's attention: stuck, overdue, or with nowhere
  /// to go. The triage screen reads this.
  Stream<List<TaskModel>> watchNeedingTriage(String uid) => _tasks(uid)
      .where(FirestoreConstants.status, whereIn: [
        TaskStatus.slipped.name,
        TaskStatus.unplaceable.name,
        TaskStatus.overdue.name,
      ])
      .snapshots()
      .map((s) => s.docs.map(TaskModel.fromFirestore).toList());

  Future<void> setStatus(String uid, String taskId, TaskStatus status) =>
      _tasks(uid).doc(taskId).update({FirestoreConstants.status: status.name});

  Future<void> markDone(String uid, String taskId, DateTime now) =>
      _tasks(uid).doc(taskId).update({
        FirestoreConstants.status: TaskStatus.done.name,
        FirestoreConstants.completedAt: Timestamp.fromDate(now),
      });

  /// Records a missed slot: the task returns to the pool and its slip
  /// counter rises. Crossing [TaskModel.stuckSlipThreshold] moves it to
  /// `slipped`, where it stops being auto-replaced and waits for triage.
  Future<void> recordSlip(String uid, TaskModel task) {
    final slipCount = task.slipCount + 1;
    final stuck = slipCount >= TaskModel.stuckSlipThreshold;
    return _tasks(uid).doc(task.taskId).update({
      FirestoreConstants.slipCount: slipCount,
      FirestoreConstants.status:
          stuck ? TaskStatus.slipped.name : TaskStatus.inbox.name,
    });
  }
}
