import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/invitation_model.dart';
import '../../../models/join_request_model.dart';
import '../../../providers/friends_provider.dart';
import '../../../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(pendingInvitationsProvider);
    final joinRequestsAsync = ref.watch(pendingJoinRequestsProvider);
    final friendRequestsAsync = ref.watch(incomingFriendRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        children: [
          // Invitations section
          invitationsAsync.when(
            data: (invitations) {
              if (invitations.isEmpty) return const SizedBox.shrink();
              return _Section(
                title: 'Invitations',
                children: invitations
                    .map((inv) => _InvitationTile(invitation: inv))
                    .toList(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Join Requests section (owner receives)
          joinRequestsAsync.when(
            data: (requests) {
              if (requests.isEmpty) return const SizedBox.shrink();
              return _Section(
                title: 'Join Requests',
                children: requests
                    .map((r) => _JoinRequestTile(request: r))
                    .toList(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Friend Requests section
          friendRequestsAsync.when(
            data: (friendships) {
              if (friendships.isEmpty) return const SizedBox.shrink();
              return _Section(
                title: 'Friend Requests',
                children: friendships
                    .map((f) => _FriendRequestTile(
                          docId: f.docId,
                          senderUid: f.requestedBy,
                        ))
                    .toList(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Empty state
          if ((invitationsAsync.valueOrNull?.isEmpty ?? true) &&
              (joinRequestsAsync.valueOrNull?.isEmpty ?? true) &&
              (friendRequestsAsync.valueOrNull?.isEmpty ?? true))
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 80),
                child: Column(
                  children: [
                    Icon(Icons.notifications_none,
                        size: 64, color: AppColors.onSurfaceVariant),
                    SizedBox(height: 16),
                    Text('All caught up!'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }
}

class _InvitationTile extends ConsumerStatefulWidget {
  const _InvitationTile({required this.invitation});

  final InvitationModel invitation;

  @override
  ConsumerState<_InvitationTile> createState() => _InvitationTileState();
}

class _InvitationTileState extends ConsumerState<_InvitationTile> {
  bool _loading = false;

  Future<void> _accept() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(invitationRepositoryProvider)
          .acceptInvitation(widget.invitation.invitationId);
      // Add to Google Calendar — the current user is the attendee
      final event = await ref
          .read(eventRepositoryProvider)
          .getEvent(widget.invitation.eventId);
      if (event != null) {
        await ref.read(calendarSyncServiceProvider).addAttendeeToEvent(
              event: event,
              attendeeUid: widget.invitation.inviteeUid,
            );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    await ref
        .read(invitationRepositoryProvider)
        .rejectInvitation(widget.invitation.invitationId);
  }

  @override
  Widget build(BuildContext context) {
    final ownerAsync =
        ref.watch(userByUidProvider(widget.invitation.eventOwnerUid));
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.event)),
      title: Text('Invited by ${ownerAsync.valueOrNull?.displayName ?? '...'}'),
      subtitle: InkWell(
        onTap: () => context.push('/event/${widget.invitation.eventId}'),
        child: Text(
          'View event',
          style: const TextStyle(color: AppColors.primary),
        ),
      ),
      trailing: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle,
                      color: AppColors.secondary),
                  onPressed: _accept,
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: AppColors.error),
                  onPressed: _reject,
                ),
              ],
            ),
    );
  }
}

class _JoinRequestTile extends ConsumerWidget {
  const _JoinRequestTile({required this.request});

  final JoinRequestModel request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userByUidProvider(request.requesterUid));
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person_add)),
      title: Text(
          '${userAsync.valueOrNull?.displayName ?? '...'} wants to join your event'),
      subtitle: InkWell(
        onTap: () => context.push('/event/${request.eventId}'),
        child: const Text('View event',
            style: TextStyle(color: AppColors.primary)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: AppColors.secondary),
            onPressed: () async {
              final event = await ref
                  .read(eventRepositoryProvider)
                  .getEvent(request.eventId);
              if (event == null) return;
              await ref
                  .read(joinRequestRepositoryProvider)
                  .approveRequest(request.requestId);
              await ref.read(calendarSyncServiceProvider).addAttendeeToEvent(
                    event: event,
                    attendeeUid: request.requesterUid,
                  );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: AppColors.error),
            onPressed: () => ref
                .read(joinRequestRepositoryProvider)
                .denyRequest(request.requestId),
          ),
        ],
      ),
    );
  }
}

class _FriendRequestTile extends ConsumerWidget {
  const _FriendRequestTile(
      {required this.docId, required this.senderUid});

  final String docId;
  final String senderUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userByUidProvider(senderUid));
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(
          '${userAsync.valueOrNull?.displayName ?? '...'} wants to be your friend'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: AppColors.secondary),
            onPressed: () =>
                ref.read(friendRepositoryProvider).acceptFriendRequest(docId),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: AppColors.error),
            onPressed: () =>
                ref.read(friendRepositoryProvider).declineFriendRequest(docId),
          ),
        ],
      ),
    );
  }
}
