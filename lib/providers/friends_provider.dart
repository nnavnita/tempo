import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/providers/firebase_providers.dart';
import '../models/friendship_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';

/// Stream of all accepted friendships for the current user.
final friendshipsProvider = StreamProvider<List<FriendshipModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(friendRepositoryProvider).watchFriends(uid);
});

/// List of friend UIDs for the current user.
final friendUidsProvider = Provider<List<String>>((ref) {
  final uid = ref.watch(currentUidProvider);
  final friendships = ref.watch(friendshipsProvider).valueOrNull ?? [];
  if (uid == null) return [];
  return friendships.map((f) => f.otherUid(uid)).toList();
});

/// Stable string key of sorted friend UIDs.
/// Use this as a family key so providers don't re-run on every Firestore
/// snapshot that returns the same UIDs (List == is reference equality).
final friendUidsKeyProvider = Provider<String>((ref) {
  final uids = ref.watch(friendUidsProvider);
  final sorted = List<String>.from(uids)..sort();
  return sorted.join(',');
});

/// Stream of incoming pending friend requests for the current user.
final incomingFriendRequestsProvider =
    StreamProvider<List<FriendshipModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(friendRepositoryProvider).watchIncomingRequests(uid);
});

/// Provider family: fetches a UserModel by UID.
final userByUidProvider = FutureProvider.family<UserModel?, String>(
  (ref, uid) => ref.watch(userRepositoryProvider).getUser(uid),
);
