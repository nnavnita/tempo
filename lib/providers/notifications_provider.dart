import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/providers/firebase_providers.dart';
import '../models/invitation_model.dart';
import '../models/join_request_model.dart';
import '../providers/auth_provider.dart';
import '../providers/friends_provider.dart';

/// Pending invitations for the current user.
final pendingInvitationsProvider = StreamProvider<List<InvitationModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();
  return ref
      .watch(invitationRepositoryProvider)
      .watchPendingInvitationsForUser(uid);
});

/// Pending join requests on events owned by the current user.
final pendingJoinRequestsProvider =
    StreamProvider<List<JoinRequestModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();
  return ref
      .watch(joinRequestRepositoryProvider)
      .watchPendingRequestsForOwner(uid);
});

/// Total notification badge count.
final notificationCountProvider = Provider<int>((ref) {
  final invitations = ref.watch(pendingInvitationsProvider).valueOrNull?.length ?? 0;
  final joinRequests =
      ref.watch(pendingJoinRequestsProvider).valueOrNull?.length ?? 0;
  final friendRequests =
      ref.watch(incomingFriendRequestsProvider).valueOrNull?.length ?? 0;
  return invitations + joinRequests + friendRequests;
});
