import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../config/providers/firebase_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/friends_provider.dart';
import '../widgets/visibility_selector.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  DateTime _startTime = DateTime.now().add(const Duration(hours: 1));
  DateTime _endTime = DateTime.now().add(const Duration(hours: 2));
  String _visibility = AppConstants.visibilityEveryone;
  List<String> _inviteeUids = [];
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final picked = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startTime = picked;
        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 1));
        }
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_endTime.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final event = await ref.read(calendarSyncServiceProvider).createEvent(
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            location: _locationCtrl.text.trim().isEmpty
                ? null
                : _locationCtrl.text.trim(),
            startTime: _startTime,
            endTime: _endTime,
            visibility: _visibility,
          );

      // Send invitations if any friends were selected
      for (final uid in _inviteeUids) {
        await ref.read(invitationRepositoryProvider).createInvitation(
              eventId: event.eventId,
              eventOwnerUid: event.ownerUid,
              inviteeUid: uid,
            );
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, MMM d • h:mm a');
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Event'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 20),
            _DateTimeRow(
              label: 'Starts',
              value: fmt.format(_startTime),
              onTap: () => _pickDateTime(isStart: true),
            ),
            const SizedBox(height: 8),
            _DateTimeRow(
              label: 'Ends',
              value: fmt.format(_endTime),
              onTap: () => _pickDateTime(isStart: false),
            ),
            const SizedBox(height: 24),
            VisibilitySelector(
              value: _visibility,
              onChanged: (v) => setState(() => _visibility = v),
            ),
            const SizedBox(height: 24),
            _InviteFriendsSection(
              selectedUids: _inviteeUids,
              onChanged: (uids) => setState(() => _inviteeUids = uids),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDADCE0)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time,
                size: 18, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
            const Spacer(),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _InviteFriendsSection extends ConsumerWidget {
  const _InviteFriendsSection({
    required this.selectedUids,
    required this.onChanged,
  });

  final List<String> selectedUids;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendUids = ref.watch(friendUidsProvider);
    if (friendUids.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invite Friends',
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: friendUids.map((uid) {
            final isSelected = selectedUids.contains(uid);
            return _FriendChip(
              uid: uid,
              isSelected: isSelected,
              onToggle: () {
                final updated = List<String>.from(selectedUids);
                if (isSelected) {
                  updated.remove(uid);
                } else {
                  updated.add(uid);
                }
                onChanged(updated);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FriendChip extends ConsumerWidget {
  const _FriendChip({
    required this.uid,
    required this.isSelected,
    required this.onToggle,
  });

  final String uid;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userByUidProvider(uid));
    return userAsync.when(
      data: (user) => FilterChip(
        label: Text(user?.displayName ?? uid),
        selected: isSelected,
        onSelected: (_) => onToggle(),
        selectedColor: AppColors.primary.withOpacity(0.15),
        checkmarkColor: AppColors.primary,
      ),
      loading: () => const SizedBox(
        width: 80,
        height: 32,
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => FilterChip(
        label: Text(uid),
        selected: isSelected,
        onSelected: (_) => onToggle(),
      ),
    );
  }
}
