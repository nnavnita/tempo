import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_constants.dart';

/// Why the most recent plan was generated. Surfaced in the UI so a plan
/// that rearranged itself can explain why rather than appearing to churn
/// at random.
enum ReplanReason {
  taskChanged,
  appForegrounded,
  slotElapsed,
  slotCompletedEarly,
  initial,
}

class PlanState {
  final int planVersion;
  final DateTime generatedAt;
  final DateTime horizonStart;
  final DateTime horizonEnd;
  final ReplanReason lastReplanReason;

  const PlanState({
    required this.planVersion,
    required this.generatedAt,
    required this.horizonStart,
    required this.horizonEnd,
    required this.lastReplanReason,
  });

  /// How far ahead the planner places work. Two weeks is long enough to
  /// absorb a deadline a fortnight out, short enough that a re-plan stays
  /// cheap and the far end does not pretend to be a commitment.
  static const Duration horizon = Duration(days: 14);

  factory PlanState.initial(DateTime now) => PlanState(
        planVersion: 1,
        generatedAt: now,
        horizonStart: now,
        horizonEnd: now.add(horizon),
        lastReplanReason: ReplanReason.initial,
      );

  PlanState next(DateTime now, ReplanReason reason) => PlanState(
        planVersion: planVersion + 1,
        generatedAt: now,
        horizonStart: now,
        horizonEnd: now.add(horizon),
        lastReplanReason: reason,
      );

  factory PlanState.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlanState(
      planVersion: data[FirestoreConstants.planVersion] as int,
      generatedAt:
          (data[FirestoreConstants.generatedAt] as Timestamp).toDate().toUtc(),
      horizonStart:
          (data[FirestoreConstants.horizonStart] as Timestamp).toDate().toUtc(),
      horizonEnd:
          (data[FirestoreConstants.horizonEnd] as Timestamp).toDate().toUtc(),
      lastReplanReason:
          _reasonFromName(data[FirestoreConstants.lastReplanReason] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
        FirestoreConstants.planVersion: planVersion,
        FirestoreConstants.generatedAt: Timestamp.fromDate(generatedAt),
        FirestoreConstants.horizonStart: Timestamp.fromDate(horizonStart),
        FirestoreConstants.horizonEnd: Timestamp.fromDate(horizonEnd),
        FirestoreConstants.lastReplanReason: lastReplanReason.name,
      };

  static ReplanReason _reasonFromName(String? name) =>
      ReplanReason.values.firstWhere(
        (r) => r.name == name,
        orElse: () => ReplanReason.initial,
      );
}
