import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/task_model.dart';
import '../../../providers/plan_provider.dart';

/// Tasks the planner has stopped handling on its own.
///
/// This screen is the anti-graveyard mechanism. Rather than endlessly
/// re-placing work that keeps slipping, the planner admits it is not
/// working and asks for a decision: shrink it, drop it, or try again.
class TriageScreen extends ConsumerWidget {
  const TriageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(triageTasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Needs a decision')),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (data) => data.isEmpty
            ? const _NothingToTriage()
            : ListView.separated(
                itemCount: data.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _TriageTile(task: data[index]),
              ),
      ),
    );
  }
}

class _TriageTile extends ConsumerWidget {
  const _TriageTile({required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(planControllerProvider);

    return ListTile(
      title: Text(task.title),
      subtitle: Text(_explain(task)),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (choice) {
          switch (choice) {
            case 'retry':
              controller.unstickTask(task);
            case 'done':
              controller.completeTask(task.taskId);
            case 'drop':
              controller.dropTask(task.taskId);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'retry', child: Text('Try again')),
          PopupMenuItem(value: 'done', child: Text('Mark done')),
          PopupMenuItem(value: 'drop', child: Text('Drop it')),
        ],
      ),
    );
  }
}

/// Says what actually went wrong. "Could not schedule" tells the user
/// nothing they can act on; naming the cause tells them whether to shrink
/// the task, move the deadline, or free up time.
String _explain(TaskModel task) {
  switch (task.status) {
    case TaskStatus.slipped:
      return 'Slipped ${task.slipCount} times. Shrink it, or set aside '
          'time for it by hand.';
    case TaskStatus.overdue:
      return 'Deadline has passed and it is still not done.';
    case TaskStatus.unplaceable:
      return 'No free gap big enough for ${task.durationMinutes} minutes '
          'before its deadline.';
    case TaskStatus.inbox:
    case TaskStatus.scheduled:
    case TaskStatus.done:
      return 'Waiting on the next plan.';
  }
}

class _NothingToTriage extends StatelessWidget {
  const _NothingToTriage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: AppColors.onSurfaceVariant),
            SizedBox(height: 16),
            Text(
              'Nothing stuck',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Tasks show up here when they keep slipping or will not fit.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
