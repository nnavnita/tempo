import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../config/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/event_model.dart';
import '../../../models/join_request_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/friends_provider.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(_eventProvider(eventId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event'),
        actions: [
          eventAsync.whenOrNull(
            data: (event) {
              final uid = ref.watch(currentUidProvider);
              if (event != null && event.ownerUid == uid) {
                return IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/event/$eventId/edit'),
                );
              }
              return null;
            },
          ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: eventAsync.when(
        data: (event) =>
            event == null ? _notFound(context) : _body(context, ref, event),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _notFound(BuildContext context) => const Center(
        child: Text('Event not found'),
      );

  Widget _body(BuildContext context, WidgetRef ref, EventModel event) {
    final uid = ref.watch(currentUidProvider);
    final isOwner = event.ownerUid == uid;
    final fmt = DateFormat('EEE, MMM d • h:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + visibility badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              _VisibilityBadge(visibility: event.visibility),
            ],
          ),
          const SizedBox(height: 16),

          // Time
          _InfoRow(
            icon: Icons.access_time,
            text:
                '${fmt.format(event.startTime)}\n→ ${fmt.format(event.endTime)}',
          ),

          // Location
          if (event.location != null) ...[
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.place_outlined, text: event.location!),
          ],

          // Description
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(event.description!),
          ],

          const SizedBox(height: 24),

          // Attendees
          if (event.attendeeUids.isNotEmpty) ...[
            Text(
              'Attendees (${event.attendeeUids.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: event.attendeeUids
                  .map((u) => _AttendeeChip(uid: u))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Owner actions: pending join requests
          if (isOwner) _PendingRequestsList(eventId: event.eventId),

          // Non-owner actions: join request button
          if (!isOwner && uid != null && !event.isPrivate)
            _JoinRequestButton(event: event, currentUid: uid),
        ],
      ),
    );
  }
}

// ── Private providers ─────────────────────────────────────────────────────────

final _eventProvider =
    FutureProvider.family<EventModel?, String>((ref, eventId) {
  return ref.watch(eventRepositoryProvider).getEvent(eventId);
});

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _VisibilityBadge extends StatelessWidget {
  const _VisibilityBadge({required this.visibility});

  final String visibility;

  Color get _color {
    switch (visibility) {
      case 'private':
        return AppColors.privateEvent;
      case 'friends':
        return AppColors.friendsEvent;
      default:
        return AppColors.publicEvent;
    }
  }

  String get _label {
    switch (visibility) {
      case 'private':
        return 'Private';
      case 'friends':
        return 'Friends';
      default:
        return 'Everyone';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text(
        _label,
        style: TextStyle(color: _color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.onSurface),
          ),
        ),
      ],
    );
  }
}

class _AttendeeChip extends ConsumerWidget {
  const _AttendeeChip({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userByUidProvider(uid));
    return userAsync.when(
      data: (user) => Chip(label: Text(user?.displayName ?? uid)),
      loading: () => const Chip(label: Text('...')),
      error: (_, __) => Chip(label: Text(uid)),
    );
  }
}

class _PendingRequestsList extends ConsumerWidget {
  const _PendingRequestsList({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_pendingRequestsProvider(eventId));

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Join Requests (${requests.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...requests.map((r) => _RequestTile(request: r)),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

final _pendingRequestsProvider =
    StreamProvider.family<List<JoinRequestModel>, String>(
  (ref, eventId) =>
      ref.watch(joinRequestRepositoryProvider).watchRequestsForEvent(eventId),
);

class _RequestTile extends ConsumerWidget {
  const _RequestTile({required this.request});

  final JoinRequestModel request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userByUidProvider(request.requesterUid));

    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: userAsync.when(
          data: (u) => Text(u?.displayName ?? request.requesterUid),
          loading: () => const Text('Loading...'),
          error: (_, __) => Text(request.requesterUid),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline,
                  color: AppColors.secondary),
              onPressed: () async {
                final eventAsync = ref.read(_eventProvider(request.eventId));
                final event = eventAsync.value;
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
              icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
              onPressed: () => ref
                  .read(joinRequestRepositoryProvider)
                  .denyRequest(request.requestId),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinRequestButton extends ConsumerStatefulWidget {
  const _JoinRequestButton({
    required this.event,
    required this.currentUid,
  });

  final EventModel event;
  final String currentUid;

  @override
  ConsumerState<_JoinRequestButton> createState() => _JoinRequestButtonState();
}

class _JoinRequestButtonState extends ConsumerState<_JoinRequestButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final isAttendee = widget.event.attendeeUids.contains(widget.currentUid);
    if (isAttendee) {
      return const Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.secondary),
          SizedBox(width: 8),
          Text('You\'re attending this event'),
        ],
      );
    }

    return FutureBuilder(
      future: ref
          .read(joinRequestRepositoryProvider)
          .getRequestForUserAndEvent(
            requesterUid: widget.currentUid,
            eventId: widget.event.eventId,
          ),
      builder: (context, snapshot) {
        final existing = snapshot.data;
        if (existing != null) {
          if (existing.isPending) {
            return const Text('Join request pending...',
                style: TextStyle(color: AppColors.onSurfaceVariant));
          }
          if (existing.isDenied) {
            return const Text('Your join request was declined.',
                style: TextStyle(color: AppColors.error));
          }
        }
        return ElevatedButton.icon(
          onPressed: _loading ? null : _requestToJoin,
          icon: const Icon(Icons.add),
          label: const Text('Request to Join'),
        );
      },
    );
  }

  Future<void> _requestToJoin() async {
    setState(() => _loading = true);
    try {
      await ref.read(joinRequestRepositoryProvider).createRequest(
            eventId: widget.event.eventId,
            eventOwnerUid: widget.event.ownerUid,
            requesterUid: widget.currentUid,
          );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
