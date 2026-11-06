import '../../models/task_model.dart';
import 'time_interval.dart';

enum UnplaceableReason {
  /// Capacity exists in the horizon, but none of it lands before the
  /// task's deadline.
  noGapBeforeDeadline,

  /// No usable capacity at all, or not enough of it in total.
  noGapInHorizon,

  /// A non-splittable task is longer than the longest single gap.
  durationExceedsLongestGap,
}

class Placement {
  final String taskId;
  final TimeInterval interval;

  const Placement({required this.taskId, required this.interval});

  @override
  String toString() => 'Placement($taskId, $interval)';
}

class Unplaceable {
  final String taskId;
  final UnplaceableReason reason;

  const Unplaceable({required this.taskId, required this.reason});

  @override
  String toString() => 'Unplaceable($taskId, ${reason.name})';
}

class PlanResult {
  final List<Placement> placements;
  final List<Unplaceable> unplaceable;

  const PlanResult({required this.placements, required this.unplaceable});
}

/// Places tasks into free gaps, earliest-deadline-first.
///
/// Pure by contract: no clock, no Firestore, no I/O. `now` is passed in.
///
/// Deliberately greedy rather than a constraint solver. EDF is optimal for
/// feasibility on a single resource, which is the shape of this problem,
/// and greedy buys three things a CP solver would cost us: determinism,
/// an answer fast enough to run on the client, and an explanation the user
/// can follow ("it's here because nothing earlier was free"). If placement
/// quality ever demands more, CP-SAT drops in behind this signature.
///
/// Every plannable task comes back in exactly one of [PlanResult.placements]
/// or [PlanResult.unplaceable]. Silently dropping a task is the one failure
/// this function must never have.
PlanResult solvePlacements({
  required List<TaskModel> tasks,
  required List<TimeInterval> freeGaps,
  required DateTime now,
}) {
  var remaining = _usableGaps(freeGaps, now);

  final sorted = tasks.where((t) => t.isPlannable).toList()
    ..sort(_byUrgency);

  final placements = <Placement>[];
  final unplaceable = <Unplaceable>[];

  for (final task in sorted) {
    final chunks = _placeTask(task, remaining);

    if (chunks == null) {
      unplaceable.add(
        Unplaceable(taskId: task.taskId, reason: _reasonFor(task, remaining)),
      );
      continue;
    }

    placements.addAll(chunks.map(
      (interval) => Placement(taskId: task.taskId, interval: interval),
    ));
    remaining = _consume(remaining, chunks);
  }

  return PlanResult(placements: placements, unplaceable: unplaceable);
}

/// Drops gaps already in the past and truncates one straddling [now].
List<TimeInterval> _usableGaps(List<TimeInterval> gaps, DateTime now) {
  final usable = <TimeInterval>[];
  for (final gap in gaps) {
    if (!gap.end.isAfter(now)) continue;
    final start = gap.start.isBefore(now) ? now : gap.start;
    final truncated = TimeInterval(start: start, end: gap.end);
    if (!truncated.isEmpty) usable.add(truncated);
  }
  usable.sort((a, b) => a.start.compareTo(b.start));
  return usable;
}

/// Earliest deadline first; then higher priority; then longer duration;
/// then task id so repeated runs produce identical plans.
int _byUrgency(TaskModel a, TaskModel b) {
  final deadline = _compareDeadlines(a.deadline, b.deadline);
  if (deadline != 0) return deadline;

  final priority = a.priority.index.compareTo(b.priority.index);
  if (priority != 0) return priority;

  final duration = b.durationMinutes.compareTo(a.durationMinutes);
  if (duration != 0) return duration;

  return a.taskId.compareTo(b.taskId);
}

/// A task with no deadline is less urgent than any task with one.
int _compareDeadlines(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

/// Returns the chunks this task should occupy, or null if it will not fit.
List<TimeInterval>? _placeTask(TaskModel task, List<TimeInterval> gaps) {
  if (!task.splittable) {
    for (final gap in gaps) {
      final usable = _clampToDeadline(gap, task.deadline);
      if (usable == null) continue;
      if (usable.duration >= task.duration) {
        return [
          TimeInterval(
            start: usable.start,
            end: usable.start.add(task.duration),
          ),
        ];
      }
    }
    return null;
  }

  final chunks = <TimeInterval>[];
  var outstanding = task.duration;
  final floor = task.minChunk;

  for (final gap in gaps) {
    if (outstanding <= Duration.zero) break;

    final usable = _clampToDeadline(gap, task.deadline);
    if (usable == null) continue;

    Duration take;
    if (outstanding <= usable.duration) {
      // The tail fits here. Take all of it, even if it is below the floor —
      // the floor exists to stop pointless fragments, not to strand a
      // task's final minutes.
      take = outstanding;
    } else {
      if (usable.duration < floor) continue;
      take = usable.duration;
      final leftover = outstanding - take;
      if (leftover < floor) {
        // Shrink this chunk so the remainder clears the floor instead of
        // emitting a sub-floor fragment later.
        final shrunk = outstanding - floor;
        if (shrunk < floor) continue;
        take = shrunk;
      }
    }

    chunks.add(TimeInterval(start: usable.start, end: usable.start.add(take)));
    outstanding -= take;
  }

  if (outstanding > Duration.zero) return null;
  return chunks;
}

/// Trims a gap so nothing is scheduled past the deadline. Returns null when
/// the gap offers no time before it.
TimeInterval? _clampToDeadline(TimeInterval gap, DateTime? deadline) {
  if (deadline == null) return gap;
  if (!gap.start.isBefore(deadline)) return null;
  final end = gap.end.isAfter(deadline) ? deadline : gap.end;
  final clamped = TimeInterval(start: gap.start, end: end);
  return clamped.isEmpty ? null : clamped;
}

UnplaceableReason _reasonFor(TaskModel task, List<TimeInterval> gaps) {
  if (gaps.isEmpty) return UnplaceableReason.noGapInHorizon;

  if (task.deadline != null) {
    final ignoringDeadline = _placeTask(
      task.copyWith(deadline: _noDeadline),
      gaps,
    );
    if (ignoringDeadline != null) {
      return UnplaceableReason.noGapBeforeDeadline;
    }
  }

  if (!task.splittable) {
    final longest = gaps
        .map((g) => g.duration)
        .reduce((a, b) => a > b ? a : b);
    if (task.duration > longest) {
      return UnplaceableReason.durationExceedsLongestGap;
    }
  }

  return UnplaceableReason.noGapInHorizon;
}

/// Sentinel far enough out to act as "no deadline" for the retry probe in
/// [_reasonFor]. `copyWith` cannot set a field back to null, and a separate
/// nullable-aware builder would be more machinery than this one probe
/// justifies.
final DateTime _noDeadline = DateTime.utc(9999);

/// Removes placed time from the pool of free gaps.
List<TimeInterval> _consume(
  List<TimeInterval> gaps,
  List<TimeInterval> placed,
) {
  final merged = mergeIntervals(placed);
  final result = <TimeInterval>[];
  for (final gap in gaps) {
    result.addAll(subtractBusy(window: gap, busy: merged));
  }
  return result;
}
