import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/scheduled_slot.dart';

class SlotTile extends StatelessWidget {
  const SlotTile({
    super.key,
    required this.slot,
    required this.title,
    required this.onComplete,
  });

  final ScheduledSlot slot;
  final String title;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final done = slot.state == SlotState.done;
    final missed = slot.state == SlotState.missed;

    return ListTile(
      leading: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatTime(slot.start.toLocal()),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              _formatDuration(slot.duration),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          decoration: done ? TextDecoration.lineThrough : null,
          color: missed ? AppColors.onSurfaceVariant : null,
        ),
      ),
      subtitle: missed ? const Text('Missed — will be re-planned') : null,
      trailing: done
          ? const Icon(Icons.check_circle, color: AppColors.secondary)
          : IconButton(
              icon: const Icon(Icons.radio_button_unchecked),
              tooltip: 'Mark done',
              onPressed: onComplete,
            ),
    );
  }
}

String _formatTime(DateTime local) {
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour < 12 ? 'am' : 'pm';
  return '$hour:$minute$suffix';
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 60) return '${minutes}m';
  if (minutes % 60 == 0) return '${minutes ~/ 60}h';
  return '${minutes ~/ 60}h ${minutes % 60}m';
}
