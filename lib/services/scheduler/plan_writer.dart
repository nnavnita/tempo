import 'package:timezone/timezone.dart' as tz;
import '../../models/plan_state.dart';
import '../../models/scheduled_slot.dart';
import '../../models/task_model.dart';
import '../../models/working_hours.dart';
import '../calendar/google_calendar_service.dart';
import '../firestore/busy_cache_repository.dart';
import '../firestore/plan_state_repository.dart';
import '../firestore/slot_repository.dart';
import '../firestore/task_repository.dart';
import 'free_gap_extractor.dart';
import 'placement_solver.dart';
import 'time_interval.dart';

/// The result of a re-plan, enough for the UI to explain what happened.
class PlanOutcome {
  final int planVersion;
  final int placedSlotCount;
  final List<Unplaceable> unplaceable;

  /// True when the plan was built from cached busy intervals because the
  /// Calendar API was unreachable. The UI must surface this.
  final bool usedCachedCalendar;

  const PlanOutcome({
    required this.planVersion,
    required this.placedSlotCount,
    required this.unplaceable,
    required this.usedCachedCalendar,
  });
}

/// Turns the pure solver into a persisted plan.
///
/// This is the only place that knows the order of operations: read the
/// calendar, carve out gaps, solve, then write slots, task statuses and
/// plan state. Keeping it here is what lets [solvePlacements] stay pure.
class PlanWriter {
  PlanWriter({
    required GoogleCalendarService calendarService,
    required TaskRepository taskRepository,
    required SlotRepository slotRepository,
    required PlanStateRepository planStateRepository,
    required BusyCacheRepository busyCacheRepository,
  })  : _calendar = calendarService,
        _tasks = taskRepository,
        _slots = slotRepository,
        _planState = planStateRepository,
        _busyCache = busyCacheRepository;

  final GoogleCalendarService _calendar;
  final TaskRepository _tasks;
  final SlotRepository _slots;
  final PlanStateRepository _planState;
  final BusyCacheRepository _busyCache;

  Future<PlanOutcome> replan({
    required String uid,
    required DateTime now,
    required ReplanReason reason,
    WorkingHours workingHours = WorkingHours.defaults,
    required String ianaTimeZone,
  }) async {
    final from = now.toUtc();
    final to = from.add(PlanState.horizon);

    final busy = await _loadBusy(
      uid: uid,
      from: from,
      to: to,
      now: now,
      ianaTimeZone: ianaTimeZone,
    );

    final gaps = extractFreeGaps(
      from: from,
      to: to,
      busy: busy.intervals,
      workingHours: workingHours,
      ianaTimeZone: ianaTimeZone,
    );

    final plannable = await _tasks.fetchPlannable(uid);
    final result = solvePlacements(
      tasks: plannable,
      freeGaps: gaps,
      now: from,
    );

    final previous = await _planState.fetch(uid);
    final next = previous == null
        ? PlanState.initial(from)
        : previous.next(from, reason);

    final slots = result.placements
        .map((p) => ScheduledSlot(
              slotId: ScheduledSlot.buildSlotId(p.taskId, p.interval.start),
              taskId: p.taskId,
              start: p.interval.start,
              end: p.interval.end,
              planVersion: next.planVersion,
            ))
        .toList();

    await _slots.replaceFuturePlan(uid: uid, slots: slots, from: from);
    await _applyTaskStatuses(
      uid: uid,
      tasks: plannable,
      result: result,
      now: from,
    );
    await _planState.write(uid, next);

    return PlanOutcome(
      planVersion: next.planVersion,
      placedSlotCount: slots.length,
      unplaceable: result.unplaceable,
      usedCachedCalendar: busy.fromCache,
    );
  }

  /// Reads busy intervals from the Calendar API, refreshing the cache. On
  /// failure, falls back to the cache and reports that it did so rather
  /// than planning against an empty calendar — which would cheerfully
  /// book over every real commitment the user has.
  Future<_BusyResult> _loadBusy({
    required String uid,
    required DateTime from,
    required DateTime to,
    required DateTime now,
    required String ianaTimeZone,
  }) async {
    try {
      final intervals = await _calendar.fetchBusyIntervals(from, to);
      await _refreshCache(
        uid: uid,
        intervals: intervals,
        from: from,
        to: to,
        now: now,
        ianaTimeZone: ianaTimeZone,
      );
      return _BusyResult(intervals, fromCache: false);
    } on CalendarUnavailable {
      final keys = _dayKeysBetween(from, to, ianaTimeZone);
      final cached = await _busyCache.readMany(uid, keys);
      return _BusyResult(cached, fromCache: true);
    }
  }

  Future<void> _refreshCache({
    required String uid,
    required List<TimeInterval> intervals,
    required DateTime from,
    required DateTime to,
    required DateTime now,
    required String ianaTimeZone,
  }) async {
    final location = tz.getLocation(ianaTimeZone);
    final byDay = <String, List<TimeInterval>>{};

    for (final key in _dayKeysBetween(from, to, ianaTimeZone)) {
      byDay[key] = [];
    }
    for (final interval in intervals) {
      final local = tz.TZDateTime.from(interval.start, location);
      final key = BusyCacheRepository.dayKeyFor(local);
      (byDay[key] ??= []).add(interval);
    }

    for (final entry in byDay.entries) {
      await _busyCache.write(
        uid: uid,
        dayKey: entry.key,
        intervals: entry.value,
        now: now,
      );
    }
  }

  List<String> _dayKeysBetween(
    DateTime from,
    DateTime to,
    String ianaTimeZone,
  ) {
    final location = tz.getLocation(ianaTimeZone);
    final keys = <String>[];
    var day = tz.TZDateTime.from(from, location);
    day = tz.TZDateTime(location, day.year, day.month, day.day);
    final last = tz.TZDateTime.from(to, location);

    while (!day.isAfter(last)) {
      keys.add(BusyCacheRepository.dayKeyFor(day));
      day = tz.TZDateTime(location, day.year, day.month, day.day + 1);
    }
    return keys;
  }

  /// Every plannable task gets a visible status. A task past its deadline
  /// is `overdue` rather than `unplaceable` — the distinction is what the
  /// triage screen uses to say something useful.
  Future<void> _applyTaskStatuses({
    required String uid,
    required List<TaskModel> tasks,
    required PlanResult result,
    required DateTime now,
  }) async {
    final placed = result.placements.map((p) => p.taskId).toSet();
    final unplaceable = {for (final u in result.unplaceable) u.taskId: u};

    for (final task in tasks) {
      final overdue = task.deadline != null && task.deadline!.isBefore(now);

      final TaskStatus status;
      if (overdue) {
        status = TaskStatus.overdue;
      } else if (placed.contains(task.taskId)) {
        status = TaskStatus.scheduled;
      } else if (unplaceable.containsKey(task.taskId)) {
        status = TaskStatus.unplaceable;
      } else {
        continue;
      }

      if (task.status != status) {
        await _tasks.setStatus(uid, task.taskId, status);
      }
    }
  }
}

class _BusyResult {
  final List<TimeInterval> intervals;
  final bool fromCache;

  const _BusyResult(this.intervals, {required this.fromCache});
}
