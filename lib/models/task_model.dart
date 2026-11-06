import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_constants.dart';

enum TaskPriority { high, normal, low }

/// Lifecycle of a task.
///
/// A single missed slot does NOT move a task here — it returns to [inbox]
/// and bumps `slipCount`. [slipped] is the *stuck* state, reached at
/// `slipCount >= stuckSlipThreshold`, and it demands explicit user triage.
enum TaskStatus { inbox, scheduled, done, slipped, unplaceable, overdue }

class TaskModel {
  /// Slip count at which a task stops being silently re-placed and is
  /// surfaced for triage instead. This is the anti-graveyard mechanism.
  static const int stuckSlipThreshold = 3;

  final String taskId;
  final String title;
  final String? notes;
  final int durationMinutes;
  final DateTime? deadline;
  final TaskPriority priority;
  final TaskStatus status;
  final bool splittable;
  final int minChunkMinutes;
  final int slipCount;
  final DateTime createdAt;
  final DateTime? completedAt;

  const TaskModel({
    required this.taskId,
    required this.title,
    this.notes,
    required this.durationMinutes,
    this.deadline,
    this.priority = TaskPriority.normal,
    this.status = TaskStatus.inbox,
    this.splittable = false,
    this.minChunkMinutes = 15,
    this.slipCount = 0,
    required this.createdAt,
    this.completedAt,
  });

  Duration get duration => Duration(minutes: durationMinutes);

  Duration get minChunk => Duration(minutes: minChunkMinutes);

  bool get isStuck => slipCount >= stuckSlipThreshold;

  /// True when the task should be considered by the solver.
  bool get isPlannable =>
      status == TaskStatus.inbox ||
      status == TaskStatus.scheduled ||
      status == TaskStatus.unplaceable;

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TaskModel(
      taskId: doc.id,
      title: data[FirestoreConstants.title] as String,
      notes: data[FirestoreConstants.notes] as String?,
      durationMinutes: data[FirestoreConstants.durationMinutes] as int,
      deadline:
          (data[FirestoreConstants.deadline] as Timestamp?)?.toDate().toUtc(),
      priority: _priorityFromName(data[FirestoreConstants.priority] as String?),
      status: _statusFromName(data[FirestoreConstants.status] as String?),
      splittable: data[FirestoreConstants.splittable] as bool? ?? false,
      minChunkMinutes: data[FirestoreConstants.minChunkMinutes] as int? ?? 15,
      slipCount: data[FirestoreConstants.slipCount] as int? ?? 0,
      createdAt:
          (data[FirestoreConstants.createdAt] as Timestamp).toDate().toUtc(),
      completedAt:
          (data[FirestoreConstants.completedAt] as Timestamp?)?.toDate().toUtc(),
    );
  }

  Map<String, dynamic> toMap() => {
        FirestoreConstants.title: title,
        FirestoreConstants.notes: notes,
        FirestoreConstants.durationMinutes: durationMinutes,
        FirestoreConstants.deadline:
            deadline == null ? null : Timestamp.fromDate(deadline!),
        FirestoreConstants.priority: priority.name,
        FirestoreConstants.status: status.name,
        FirestoreConstants.splittable: splittable,
        FirestoreConstants.minChunkMinutes: minChunkMinutes,
        FirestoreConstants.slipCount: slipCount,
        FirestoreConstants.createdAt: Timestamp.fromDate(createdAt),
        FirestoreConstants.completedAt:
            completedAt == null ? null : Timestamp.fromDate(completedAt!),
      };

  TaskModel copyWith({
    String? title,
    String? notes,
    int? durationMinutes,
    DateTime? deadline,
    TaskPriority? priority,
    TaskStatus? status,
    bool? splittable,
    int? minChunkMinutes,
    int? slipCount,
    DateTime? completedAt,
  }) =>
      TaskModel(
        taskId: taskId,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        deadline: deadline ?? this.deadline,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        splittable: splittable ?? this.splittable,
        minChunkMinutes: minChunkMinutes ?? this.minChunkMinutes,
        slipCount: slipCount ?? this.slipCount,
        createdAt: createdAt,
        completedAt: completedAt ?? this.completedAt,
      );

  static TaskPriority _priorityFromName(String? name) =>
      TaskPriority.values.firstWhere(
        (p) => p.name == name,
        orElse: () => TaskPriority.normal,
      );

  static TaskStatus _statusFromName(String? name) =>
      TaskStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => TaskStatus.inbox,
      );
}
