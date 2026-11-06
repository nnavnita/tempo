import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/app_constants.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/auth_token_service.dart';
import '../../services/calendar/google_calendar_service.dart';
import '../../services/firestore/busy_cache_repository.dart';
import '../../services/firestore/plan_state_repository.dart';
import '../../services/firestore/slot_repository.dart';
import '../../services/firestore/task_repository.dart';
import '../../services/firestore/user_repository.dart';
import '../../services/notifications/replan_messaging_service.dart';
import '../../services/notifications/slot_notification_scheduler.dart';
import '../../services/scheduler/plan_writer.dart';

// ── Firebase instances ────────────────────────────────────────────────────────

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final googleSignInProvider = Provider<GoogleSignIn>(
  (ref) => GoogleSignIn(scopes: AppConstants.googleScopes),
);

// ── Services ──────────────────────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    googleSignIn: ref.watch(googleSignInProvider),
  );
});

final authTokenServiceProvider = Provider<AuthTokenService>((ref) {
  return AuthTokenService(googleSignIn: ref.watch(googleSignInProvider));
});

final googleCalendarServiceProvider = Provider<GoogleCalendarService>((ref) {
  return GoogleCalendarService(
    authTokenService: ref.watch(authTokenServiceProvider),
  );
});

final slotNotificationSchedulerProvider =
    Provider<SlotNotificationScheduler>((ref) {
  return SlotNotificationScheduler();
});

final replanMessagingServiceProvider =
    Provider<ReplanMessagingService>((ref) {
  return ReplanMessagingService();
});

// ── Repositories ──────────────────────────────────────────────────────────────

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(firestore: ref.watch(firestoreProvider));
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(firestore: ref.watch(firestoreProvider));
});

final slotRepositoryProvider = Provider<SlotRepository>((ref) {
  return SlotRepository(firestore: ref.watch(firestoreProvider));
});

final planStateRepositoryProvider = Provider<PlanStateRepository>((ref) {
  return PlanStateRepository(firestore: ref.watch(firestoreProvider));
});

final busyCacheRepositoryProvider = Provider<BusyCacheRepository>((ref) {
  return BusyCacheRepository(firestore: ref.watch(firestoreProvider));
});

// ── Planner ───────────────────────────────────────────────────────────────────

final planWriterProvider = Provider<PlanWriter>((ref) {
  return PlanWriter(
    calendarService: ref.watch(googleCalendarServiceProvider),
    taskRepository: ref.watch(taskRepositoryProvider),
    slotRepository: ref.watch(slotRepositoryProvider),
    planStateRepository: ref.watch(planStateRepositoryProvider),
    busyCacheRepository: ref.watch(busyCacheRepositoryProvider),
  );
});
