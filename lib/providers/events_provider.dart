import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/providers/firebase_providers.dart';
import '../models/event_model.dart';
import '../providers/auth_provider.dart';

/// Stream of all events owned by the current user.
final ownEventsProvider = StreamProvider<List<EventModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(eventRepositoryProvider).watchOwnEvents(uid);
});

/// Map of day → list of events for the calendar widget.
final eventsByDayProvider = Provider<Map<DateTime, List<EventModel>>>((ref) {
  final events = ref.watch(ownEventsProvider).valueOrNull ?? [];
  final map = <DateTime, List<EventModel>>{};
  for (final e in events) {
    final day = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
    (map[day] ??= []).add(e);
  }
  return map;
});

/// Provider family: visible events for a friend's UID.
final friendEventsProvider = FutureProvider.family<List<EventModel>, String>(
  (ref, friendUid) async {
    final myUid = ref.watch(currentUidProvider);
    if (myUid == null) return [];
    final isFriend = await ref
        .watch(friendRepositoryProvider)
        .areFriends(myUid, friendUid);
    return ref.watch(eventRepositoryProvider).getVisibleEventsForUser(
          ownerUid: friendUid,
          isFriend: isFriend,
        );
  },
);
