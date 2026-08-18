import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/notification_bell_action.dart';
import '../../../providers/friends_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../config/providers/firebase_providers.dart';

class FriendsListScreen extends ConsumerWidget {
  const FriendsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendshipsAsync = ref.watch(friendshipsProvider);
    final myUid = ref.watch(currentUidProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => context.push(RouteConstants.userSearch),
          ),
          IconButton(
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () => context.push(RouteConstants.friendRequests),
          ),
          const NotificationBellAction(),
        ],
      ),
      body: friendshipsAsync.when(
        data: (friendships) {
          if (friendships.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline,
                      size: 64, color: AppColors.onSurfaceVariant),
                  const SizedBox(height: 16),
                  const Text('No friends yet'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => context.push(RouteConstants.userSearch),
                    child: const Text('Find Friends'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: friendships.length,
            itemBuilder: (context, i) {
              final friendship = friendships[i];
              final friendUid =
                  myUid != null ? friendship.otherUid(myUid) : '';
              return _FriendTile(
                uid: friendUid,
                onRemove: () async {
                  if (myUid == null) return;
                  await ref
                      .read(friendRepositoryProvider)
                      .removeFriend(myUid, friendUid);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _FriendTile extends ConsumerWidget {
  const _FriendTile({required this.uid, required this.onRemove});

  final String uid;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userByUidProvider(uid));

    return userAsync.when(
      data: (user) => ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          backgroundImage: user?.photoURL != null
              ? CachedNetworkImageProvider(user!.photoURL!)
              : null,
          child: user?.photoURL == null
              ? Text(
                  user?.displayName.isNotEmpty == true
                      ? user!.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: AppColors.primary),
                )
              : null,
        ),
        title: Text(user?.displayName ?? uid),
        subtitle: Text(user?.email ?? ''),
        trailing: PopupMenuButton(
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'remove',
              child: Text('Remove Friend',
                  style: TextStyle(color: AppColors.error)),
            ),
          ],
          onSelected: (v) {
            if (v == 'remove') onRemove();
          },
        ),
      ),
      loading: () => const ListTile(
        leading: CircleAvatar(),
        title: LinearProgressIndicator(),
      ),
      error: (_, __) => ListTile(title: Text(uid)),
    );
  }
}
