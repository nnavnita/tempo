import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:tempo/core/constants/firestore_constants.dart';
import 'package:tempo/models/plan_state.dart';
import 'package:tempo/models/task_model.dart';
import 'package:tempo/models/working_hours.dart';
import 'package:tempo/services/calendar/busy_interval_source.dart';
import 'package:tempo/services/calendar/google_calendar_service.dart';
import 'package:tempo/services/firestore/busy_cache_repository.dart';
import 'package:tempo/services/firestore/plan_state_repository.dart';
import 'package:tempo/services/firestore/slot_repository.dart';
import 'package:tempo/services/firestore/task_repository.dart';
import 'package:tempo/services/scheduler/plan_writer.dart';
import 'package:tempo/services/scheduler/time_interval.dart';

const uid = 'user-1';
const melbourne = 'Australia/Melbourne';

/// Mon 9 Nov 2026, 08:00 local (21:00 UTC Sun 8 Nov).
final now = DateTime.utc(2026, 11, 8, 21);

class FakeCalendar implements BusyIntervalSource {
  FakeCalendar({this.busy = const [], this.throws = false});

  final List<TimeInterval> busy;
  final bool throws;
  int callCount = 0;

  @override
  Future<List<TimeInterval>> fetchBusyIntervals(DateTime from, DateTime to) async {
    callCount++;
    if (throws) throw CalendarUnavailable('offline');
    return busy;
  }
}

({PlanWriter writer, FakeFirebaseFirestore db, TaskRepository tasks,
  SlotRepository slots, PlanStateRepository planState}) build(
  BusyIntervalSource calendar,
) {
  final db = FakeFirebaseFirestore();
  final tasks = TaskRepository(firestore: db);
  final slots = SlotRepository(firestore: db);
  final planState = PlanStateRepository(firestore: db);

  return (
    writer: PlanWriter(
      calendarService: calendar,
      taskRepository: tasks,
      slotRepository: slots,
      planStateRepository: planState,
      busyCacheRepository: BusyCacheRepository(firestore: db),
    ),
    db: db,
    tasks: tasks,
    slots: slots,
    planState: planState,
  );
}

Future<String> addTask(
  TaskRepository tasks, {
  required String title,
  required int minutes,
  DateTime? deadline,
}) =>
    tasks.create(
      uid,
      TaskModel(
        taskId: '',
        title: title,
        durationMinutes: minutes,
        deadline: deadline,
        createdAt: now,
      ),
    );

Future<PlanOutcome> run(PlanWriter writer) => writer.replan(
      uid: uid,
      now: now,
      reason: ReplanReason.initial,
      ianaTimeZone: melbourne,
      workingHours: WorkingHours.defaults,
    );

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('places a captured task and writes a slot for it', () async {
    final env = build(FakeCalendar());
    final taskId = await addTask(env.tasks, title: 'Write report', minutes: 60);

    final outcome = await run(env.writer);

    expect(outcome.placedSlotCount, 1);
    expect(outcome.unplaceable, isEmpty);
    expect(outcome.usedCachedCalendar, isFalse);

    final slots = await env.slots.fetchUpcoming(uid, now, limit: 10);
    expect(slots, hasLength(1));
    expect(slots.single.taskId, taskId);
    expect(slots.single.planVersion, 1);
  });

  test('marks a placed task as scheduled', () async {
    final env = build(FakeCalendar());
    final taskId = await addTask(env.tasks, title: 'Write report', minutes: 60);

    await run(env.writer);

    final task = await env.tasks.fetch(uid, taskId);
    expect(task!.status, TaskStatus.scheduled);
  });

  test('marks a task with nowhere to go as unplaceable, not dropped', () async {
    // Busy right through the only working day in reach.
    final env = build(FakeCalendar(busy: [
      TimeInterval(
        start: DateTime.utc(2026, 11, 8, 12),
        end: DateTime.utc(2026, 11, 23),
      ),
    ]));
    final taskId = await addTask(env.tasks, title: 'Squeeze me', minutes: 60);

    final outcome = await run(env.writer);

    expect(outcome.placedSlotCount, 0);
    expect(outcome.unplaceable, hasLength(1));

    final task = await env.tasks.fetch(uid, taskId);
    expect(task!.status, TaskStatus.unplaceable);
  });

  test('marks a task past its deadline as overdue', () async {
    final env = build(FakeCalendar());
    final taskId = await addTask(
      env.tasks,
      title: 'Too late',
      minutes: 30,
      deadline: now.subtract(const Duration(days: 1)),
    );

    await run(env.writer);

    final task = await env.tasks.fetch(uid, taskId);
    expect(task!.status, TaskStatus.overdue);
  });

  test('falls back to the cache and reports it when the calendar fails',
      () async {
    // First plan succeeds and populates the cache with a busy morning.
    final busy = [
      TimeInterval(
        start: DateTime.utc(2026, 11, 8, 22),
        end: DateTime.utc(2026, 11, 9, 6),
      ),
    ];
    final db = FakeFirebaseFirestore();
    final tasks = TaskRepository(firestore: db);
    final cache = BusyCacheRepository(firestore: db);

    PlanWriter writerWith(BusyIntervalSource calendar) => PlanWriter(
          calendarService: calendar,
          taskRepository: tasks,
          slotRepository: SlotRepository(firestore: db),
          planStateRepository: PlanStateRepository(firestore: db),
          busyCacheRepository: cache,
        );

    await addTask(tasks, title: 'Deep work', minutes: 60);

    final first = await writerWith(FakeCalendar(busy: busy)).replan(
      uid: uid,
      now: now,
      reason: ReplanReason.initial,
      ianaTimeZone: melbourne,
    );
    expect(first.usedCachedCalendar, isFalse);

    // Second plan with the calendar down must still respect that busy block.
    final second = await writerWith(FakeCalendar(throws: true)).replan(
      uid: uid,
      now: now,
      reason: ReplanReason.appForegrounded,
      ianaTimeZone: melbourne,
    );

    expect(second.usedCachedCalendar, isTrue);
    expect(second.placedSlotCount, 1);

    final slots = await SlotRepository(firestore: db)
        .fetchUpcoming(uid, now, limit: 10);
    // 17:00 local is 06:00 UTC — the cached block was honoured, so nothing
    // was booked over it.
    expect(
      slots.single.start.isBefore(DateTime.utc(2026, 11, 9, 6)),
      isFalse,
    );
  });

  test('increments planVersion on each re-plan', () async {
    final env = build(FakeCalendar());
    await addTask(env.tasks, title: 'Write report', minutes: 60);

    final first = await run(env.writer);
    final second = await run(env.writer);

    expect(first.planVersion, 1);
    expect(second.planVersion, 2);

    final state = await env.planState.fetch(uid);
    expect(state!.planVersion, 2);
  });

  test('a re-plan leaves no slots from the previous version behind', () async {
    final env = build(FakeCalendar());
    await addTask(env.tasks, title: 'Write report', minutes: 60);

    await run(env.writer);
    await run(env.writer);

    final slots = await env.slots.fetchUpcoming(uid, now, limit: 50);
    expect(slots, hasLength(1));
    expect(slots.single.planVersion, 2);
  });

  test('caches busy intervals for offline planning', () async {
    final env = build(FakeCalendar(busy: [
      TimeInterval(
        start: DateTime.utc(2026, 11, 8, 22),
        end: DateTime.utc(2026, 11, 8, 23),
      ),
    ]));

    await run(env.writer);

    final cached = await BusyCacheRepository(firestore: env.db)
        .read(uid, '2026-11-09');
    expect(cached, hasLength(1));
  });

  test('horizon spans the configured two weeks', () async {
    final env = build(FakeCalendar());
    await addTask(env.tasks, title: 'Write report', minutes: 60);

    await run(env.writer);

    final doc = await env.db
        .collection(FirestoreConstants.usersCollection)
        .doc(uid)
        .collection(FirestoreConstants.planStateCollection)
        .doc(FirestoreConstants.planStateCurrentDoc)
        .get();
    final state = PlanState.fromFirestore(doc);

    expect(state.horizonEnd.difference(state.horizonStart), PlanState.horizon);
  });
}
