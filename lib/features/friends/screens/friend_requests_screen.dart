import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/friends_provider.dart';

class FriendRequestsScreen extends ConsumerWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(incomingFriendRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Friend Requests')),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(child: Text('No pending friend requests'));
          }
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, i) {
              final friendship = requests[i];
              return _RequestTile(
                senderUid: friendship.requestedBy,
                docId: friendship.docId,
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

class _RequestTile extends ConsumerWidget {
  const _RequestTile({required this.senderUid, required this.docId});

  final String senderUid;
  final String docId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userByUidProvider(senderUid));
    final repo = ref.read(friendRepositoryProvider);

    return userAsync.when(
      data: (user) => ListTile(
        leading: CircleAvatar(
          backgroundImage: user?.photoURL != null
              ? CachedNetworkImageProvider(user!.photoURL!)
              : null,
          child: user?.photoURL == null
              ? Text(user?.displayName[0].toUpperCase() ?? '?')
              : null,
        ),
        title: Text(user?.displayName ?? senderUid),
        subtitle: Text(user?.email ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: AppColors.secondary),
              onPressed: () => repo.acceptFriendRequest(docId),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: AppColors.error),
              onPressed: () => repo.declineFriendRequest(docId),
            ),
          ],
        ),
      ),
      loading: () => const ListTile(title: LinearProgressIndicator()),
      error: (_, __) => ListTile(title: Text(senderUid)),
    );
  }
}
