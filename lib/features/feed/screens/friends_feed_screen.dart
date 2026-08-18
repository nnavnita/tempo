import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/notification_bell_action.dart';
import '../../../models/event_model.dart';
import '../../../providers/friends_provider.dart';
import '../../events/widgets/event_card.dart';

class FriendsFeedScreen extends ConsumerWidget {
  const FriendsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendUids = ref.watch(friendUidsProvider);
    final feedAsync = ref.watch(_feedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: const [NotificationBellAction()],
      ),
      body: feedAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.explore_outlined,
                      size: 64, color: AppColors.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    friendUids.isEmpty
                        ? 'Add friends to see their events here'
                        : 'No upcoming public events from friends',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: events.length,
            itemBuilder: (context, i) {
              final event = events[i];
              return _FeedEventCard(event: event);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// Uses friendUidsKeyProvider (sorted join) so this only re-runs when the
// set of friend UIDs actually changes, not on every Firestore snapshot.
final _feedProvider = FutureProvider<List<EventModel>>((ref) {
  final uidsKey = ref.watch(friendUidsKeyProvider);
  final uids = uidsKey.isEmpty ? <String>[] : uidsKey.split(',');
  return ref.read(eventRepositoryProvider).getFeedEvents(
        friendUids: uids,
        after: DateTime.now().subtract(const Duration(hours: 1)),
      );
});

class _FeedEventCard extends ConsumerWidget {
  const _FeedEventCard({required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerAsync = ref.watch(userByUidProvider(event.ownerUid));
    final ownerName = ownerAsync.valueOrNull?.displayName;

    return EventCard(
      event: event,
      showOwner: true,
      ownerName: ownerName,
      onTap: () => context.push('/event/${event.eventId}'),
    );
  }
}
