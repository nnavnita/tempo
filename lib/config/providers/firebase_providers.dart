import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/app_constants.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/auth_token_service.dart';
import '../../services/calendar/calendar_sync_service.dart';
import '../../services/calendar/google_calendar_service.dart';
import '../../services/firestore/busy_slot_repository.dart';
import '../../services/firestore/event_repository.dart';
import '../../services/firestore/friend_repository.dart';
import '../../services/firestore/invitation_repository.dart';
import '../../services/firestore/join_request_repository.dart';
import '../../services/firestore/user_repository.dart';

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
      authTokenService: ref.watch(authTokenServiceProvider));
});

// ── Repositories ──────────────────────────────────────────────────────────────

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(firestore: ref.watch(firestoreProvider));
});

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(firestore: ref.watch(firestoreProvider));
});

final busySlotRepositoryProvider = Provider<BusySlotRepository>((ref) {
  return BusySlotRepository(firestore: ref.watch(firestoreProvider));
});

final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  return FriendRepository(firestore: ref.watch(firestoreProvider));
});

final joinRequestRepositoryProvider = Provider<JoinRequestRepository>((ref) {
  return JoinRequestRepository(firestore: ref.watch(firestoreProvider));
});

final invitationRepositoryProvider = Provider<InvitationRepository>((ref) {
  return InvitationRepository(firestore: ref.watch(firestoreProvider));
});

final calendarSyncServiceProvider = Provider<CalendarSyncService>((ref) {
  return CalendarSyncService(
    authService: ref.watch(authServiceProvider),
    eventRepository: ref.watch(eventRepositoryProvider),
    busySlotRepository: ref.watch(busySlotRepositoryProvider),
    googleCalendarService: ref.watch(googleCalendarServiceProvider),
  );
});
