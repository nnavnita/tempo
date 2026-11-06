import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/models/task_model.dart';
import 'package:tempo/services/scheduler/placement_solver.dart';
import 'package:tempo/services/scheduler/time_interval.dart';

final now = DateTime.utc(2026, 11, 9, 8);

TaskModel task(
  String id, {
  required int minutes,
  DateTime? deadline,
  TaskPriority priority = TaskPriority.normal,
  bool splittable = false,
  int minChunkMinutes = 15,
}) =>
    TaskModel(
      taskId: id,
      title: id,
      durationMinutes: minutes,
      deadline: deadline,
      priority: priority,
      splittable: splittable,
      minChunkMinutes: minChunkMinutes,
      createdAt: now,
    );

TimeInterval gap(int startHour, int endHour, {int day = 9}) => TimeInterval(
      start: DateTime.utc(2026, 11, day, startHour),
      end: DateTime.utc(2026, 11, day, endHour),
    );

void main() {
  group('solvePlacements', () {
    test('places a single task at the start of the first gap', () {
      final result = solvePlacements(
        tasks: [task('a', minutes: 60)],
        freeGaps: [gap(9, 17)],
        now: now,
      );

      expect(result.unplaceable, isEmpty);
      expect(result.placements, hasLength(1));
      expect(result.placements.single.taskId, 'a');
      expect(result.placements.single.interval.start, DateTime.utc(2026, 11, 9, 9));
      expect(result.placements.single.interval.end, DateTime.utc(2026, 11, 9, 10));
    });

    test('returns nothing placeable when there are no gaps', () {
      final result = solvePlacements(
        tasks: [task('a', minutes: 60)],
        freeGaps: const [],
        now: now,
      );

      expect(result.placements, isEmpty);
      expect(result.unplaceable, hasLength(1));
      expect(result.unplaceable.single.reason, UnplaceableReason.noGapInHorizon);
    });

    test('packs two tasks back to back into one gap', () {
      final result = solvePlacements(
        tasks: [task('a', minutes: 60), task('b', minutes: 30)],
        freeGaps: [gap(9, 11)],
        now: now,
      );

      expect(result.unplaceable, isEmpty);
      final byId = {for (final p in result.placements) p.taskId: p.interval};
      expect(byId['a']!.start, DateTime.utc(2026, 11, 9, 9));
      expect(byId['a']!.end, DateTime.utc(2026, 11, 9, 10));
      expect(byId['b']!.start, DateTime.utc(2026, 11, 9, 10));
      expect(byId['b']!.end, DateTime.utc(2026, 11, 9, 10, 30));
    });

    test('two tasks competing for one gap place the earlier deadline first', () {
      final result = solvePlacements(
        tasks: [
          task('later', minutes: 60, deadline: DateTime.utc(2026, 11, 20)),
          task('sooner', minutes: 60, deadline: DateTime.utc(2026, 11, 10)),
        ],
        freeGaps: [gap(9, 10)],
        now: now,
      );

      expect(result.placements, hasLength(1));
      expect(result.placements.single.taskId, 'sooner');
      expect(result.unplaceable, hasLength(1));
      expect(result.unplaceable.single.taskId, 'later');
    });

    test('breaks a deadline tie on priority', () {
      final deadline = DateTime.utc(2026, 11, 12);
      final result = solvePlacements(
        tasks: [
          task('low', minutes: 60, deadline: deadline, priority: TaskPriority.low),
          task('high', minutes: 60, deadline: deadline, priority: TaskPriority.high),
        ],
        freeGaps: [gap(9, 10)],
        now: now,
      );

      expect(result.placements.single.taskId, 'high');
    });

    test('sorts tasks without deadlines after those with them', () {
      final result = solvePlacements(
        tasks: [
          task('undated', minutes: 60),
          task('dated', minutes: 60, deadline: DateTime.utc(2026, 11, 30)),
        ],
        freeGaps: [gap(9, 10)],
        now: now,
      );

      expect(result.placements.single.taskId, 'dated');
    });

    test('reports a task that cannot fit before its deadline', () {
      final result = solvePlacements(
        tasks: [
          task('a', minutes: 120, deadline: DateTime.utc(2026, 11, 9, 10)),
        ],
        freeGaps: [gap(9, 17)],
        now: now,
      );

      expect(result.placements, isEmpty);
      expect(
        result.unplaceable.single.reason,
        UnplaceableReason.noGapBeforeDeadline,
      );
    });

    test('never places a task past its deadline', () {
      final result = solvePlacements(
        tasks: [
          task('a', minutes: 60, deadline: DateTime.utc(2026, 11, 9, 12)),
        ],
        freeGaps: [gap(9, 17)],
        now: now,
      );

      expect(
        result.placements.single.interval.end
            .isAfter(DateTime.utc(2026, 11, 9, 12)),
        isFalse,
      );
    });

    test('reports a non-splittable task longer than the longest gap', () {
      final result = solvePlacements(
        tasks: [task('a', minutes: 240)],
        freeGaps: [gap(9, 10), gap(11, 12), gap(13, 14)],
        now: now,
      );

      expect(result.placements, isEmpty);
      expect(
        result.unplaceable.single.reason,
        UnplaceableReason.durationExceedsLongestGap,
      );
    });

    test('chunks a splittable task across three gaps', () {
      final result = solvePlacements(
        tasks: [task('a', minutes: 180, splittable: true, minChunkMinutes: 30)],
        freeGaps: [gap(9, 10), gap(11, 12), gap(13, 14)],
        now: now,
      );

      expect(result.unplaceable, isEmpty);
      expect(result.placements, hasLength(3));
      expect(result.placements.every((p) => p.taskId == 'a'), isTrue);

      final total = result.placements.fold<Duration>(
        Duration.zero,
        (sum, p) => sum + p.interval.duration,
      );
      expect(total, const Duration(minutes: 180));
    });

    test('never emits a chunk shorter than minChunkMinutes', () {
      // 100 minutes over a 90-minute gap and a 60-minute gap with a
      // 30-minute floor: the 10-minute tail must not become its own chunk.
      final result = solvePlacements(
        tasks: [task('a', minutes: 100, splittable: true, minChunkMinutes: 30)],
        freeGaps: [gap(9, 10, day: 9), gap(11, 12, day: 9)],
        now: now,
      );

      expect(result.unplaceable, isEmpty);
      for (final p in result.placements) {
        expect(
          p.interval.duration.inMinutes,
          greaterThanOrEqualTo(30),
          reason: 'chunk ${p.interval} is below the 30 minute floor',
        );
      }
      final total = result.placements.fold<Duration>(
        Duration.zero,
        (sum, p) => sum + p.interval.duration,
      );
      expect(total, const Duration(minutes: 100));
    });

    test('does not split a gap remainder below the floor into a chunk', () {
      // Only 40 minutes of capacity exists but the floor is 30: the task
      // takes one 40-minute chunk, not a 30 + 10 split.
      final result = solvePlacements(
        tasks: [task('a', minutes: 40, splittable: true, minChunkMinutes: 30)],
        freeGaps: [gap(9, 10)],
        now: now,
      );

      expect(result.placements, hasLength(1));
      expect(result.placements.single.interval.duration,
          const Duration(minutes: 40));
    });

    test('reports a splittable task with insufficient total capacity', () {
      final result = solvePlacements(
        tasks: [task('a', minutes: 300, splittable: true, minChunkMinutes: 30)],
        freeGaps: [gap(9, 10)],
        now: now,
      );

      expect(result.placements, isEmpty);
      expect(result.unplaceable, hasLength(1));
    });

    test('saturated calendar leaves every task unplaceable and none dropped', () {
      final tasks = [
        task('a', minutes: 60),
        task('b', minutes: 60),
        task('c', minutes: 60),
      ];
      final result = solvePlacements(
        tasks: tasks,
        freeGaps: const [],
        now: now,
      );

      expect(result.unplaceable, hasLength(3));
      expect(
        result.unplaceable.map((u) => u.taskId).toSet(),
        {'a', 'b', 'c'},
      );
    });

    test('every task ends up in exactly one of placed or unplaceable', () {
      final tasks = [
        task('fits', minutes: 30),
        task('too-long', minutes: 600),
        task('past-deadline', minutes: 60, deadline: DateTime.utc(2026, 11, 9, 8, 30)),
      ];
      final result = solvePlacements(
        tasks: tasks,
        freeGaps: [gap(9, 10)],
        now: now,
      );

      final placed = result.placements.map((p) => p.taskId).toSet();
      final unplaced = result.unplaceable.map((u) => u.taskId).toSet();

      expect(placed.intersection(unplaced), isEmpty);
      expect(placed.union(unplaced), {'fits', 'too-long', 'past-deadline'});
    });

    test('ignores gaps that have already passed', () {
      final result = solvePlacements(
        tasks: [task('a', minutes: 60)],
        freeGaps: [gap(5, 7), gap(9, 11)],
        now: now,
      );

      expect(result.placements.single.interval.start,
          DateTime.utc(2026, 11, 9, 9));
    });

    test('truncates a gap that straddles now', () {
      final result = solvePlacements(
        tasks: [task('a', minutes: 30)],
        freeGaps: [gap(7, 11)],
        now: now,
      );

      expect(result.placements.single.interval.start, now);
    });

    test('skips tasks that are not plannable', () {
      final done = task('done', minutes: 30).copyWith(status: TaskStatus.done);
      final result = solvePlacements(
        tasks: [done],
        freeGaps: [gap(9, 17)],
        now: now,
      );

      expect(result.placements, isEmpty);
      expect(result.unplaceable, isEmpty);
    });

    test('is deterministic across repeated runs', () {
      List<String> run() => solvePlacements(
            tasks: [
              task('a', minutes: 60, deadline: DateTime.utc(2026, 11, 12)),
              task('b', minutes: 60, deadline: DateTime.utc(2026, 11, 12)),
              task('c', minutes: 60),
            ],
            freeGaps: [gap(9, 12)],
            now: now,
          ).placements.map((p) => '${p.taskId}@${p.interval.start}').toList();

      expect(run(), run());
    });
  });
}
