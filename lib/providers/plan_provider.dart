import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/providers/firebase_providers.dart';
import '../core/constants/app_constants.dart';
import '../models/plan_state.dart';
import '../models/scheduled_slot.dart';
import '../models/task_model.dart';
import '../services/scheduler/plan_writer.dart';
import 'auth_provider.dart';

/// The zone working hours are interpreted in.
///
/// v1 ships a fixed default rather than reading the device zone — resolving
/// an IANA name on-device needs a platform channel, and getting it wrong
/// silently shifts every working window. Exposed as a provider so a
/// settings screen can override it without touching the planner.
final timeZoneProvider = Provider<String>(
  (ref) => AppConstants.fallbackTimeZone,
);

final allTasksProvider = StreamProvider<List<TaskModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(taskRepositoryProvider).watchAll(uid);
});

/// Tasks waiting on a decision from the user: stuck, overdue, or with
/// nowhere to go.
final triageTasksProvider = StreamProvider<List<TaskModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(taskRepositoryProvider).watchNeedingTriage(uid);
});

final planStateProvider = StreamProvider<PlanState?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(planStateRepositoryProvider).watch(uid);
});

/// Slots starting within the next [days] days.
final slotsProvider =
    StreamProvider.family<List<ScheduledSlot>, int>((ref, days) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);

  final now = DateTime.now().toUtc();
  return ref.watch(slotRepositoryProvider).watchBetween(
        uid,
        now,
        now.add(Duration(days: days)),
      );
});

/// The most recent re-plan result, so the UI can show degraded-calendar
/// and unplaceable feedback without re-running the plan.
final lastPlanOutcomeProvider = StateProvider<PlanOutcome?>((ref) => null);

final planControllerProvider = Provider<PlanController>((ref) {
  return PlanController(ref);
});

class PlanController {
  PlanController(this._ref);

  final Ref _ref;

  /// Re-plans, then re-registers local notifications for the near horizon.
  ///
  /// Notification sync is deliberately coupled to re-planning: a plan the
  /// OS has not been told about is a plan that will not fire.
  Future<PlanOutcome?> replan(ReplanReason reason) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return null;

    final now = DateTime.now().toUtc();
    final outcome = await _ref.read(planWriterProvider).replan(
          uid: uid,
          now: now,
          reason: reason,
          ianaTimeZone: _ref.read(timeZoneProvider),
        );

    _ref.read(lastPlanOutcomeProvider.notifier).state = outcome;
    await _syncNotifications(uid, now);
    return outcome;
  }

  Future<void> addTask(TaskModel task) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;

    await _ref.read(taskRepositoryProvider).create(uid, task);
    await replan(ReplanReason.taskChanged);
  }

  Future<void> completeTask(String taskId) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;

    await _ref
        .read(taskRepositoryProvider)
        .markDone(uid, taskId, DateTime.now().toUtc());
    await replan(ReplanReason.slotCompletedEarly);
  }

  Future<void> dropTask(String taskId) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;

    await _ref.read(taskRepositoryProvider).delete(uid, taskId);
    await replan(ReplanReason.taskChanged);
  }

  /// Returns a stuck task to the pool so the planner will place it again.
  Future<void> unstickTask(TaskModel task) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;

    await _ref.read(taskRepositoryProvider).update(
          uid,
          task.copyWith(status: TaskStatus.inbox, slipCount: 0),
        );
    await replan(ReplanReason.taskChanged);
  }

  /// Registers this device for the server's re-plan pushes and re-plans
  /// whenever one arrives.
  ///
  /// Idempotent: safe to call on every app start.
  Future<void> registerForReplanPushes() async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;

    final messaging = _ref.read(replanMessagingServiceProvider);
    await messaging.requestPermission();

    final token = await messaging.currentToken();
    if (token != null) {
      await _ref.read(userRepositoryProvider).updateFcmToken(uid, token);
    }

    // Tokens rotate on reinstall, restore and cache clear. Missing a
    // rotation means the server quietly loses the ability to reach this
    // device, and the user just stops getting reminders.
    messaging.tokenRefreshes.listen((refreshed) {
      final currentUid = _ref.read(currentUidProvider);
      if (currentUid != null) {
        _ref.read(userRepositoryProvider).updateFcmToken(currentUid, refreshed);
      }
    });

    messaging.listen(() => replan(ReplanReason.slotElapsed));
  }

  Future<void> _syncNotifications(String uid, DateTime now) async {
    final slots = await _ref.read(slotRepositoryProvider).fetchUpcoming(
          uid,
          now,
          limit: AppConstants.localNotificationHorizon,
        );

    final titles = <String, String>{};
    for (final taskId in slots.map((s) => s.taskId).toSet()) {
      final task = await _ref.read(taskRepositoryProvider).fetch(uid, taskId);
      if (task != null) titles[taskId] = task.title;
    }

    await _ref.read(slotNotificationSchedulerProvider).syncUpcoming(
          slots: slots,
          taskTitles: titles,
          now: now,
        );
  }
}
