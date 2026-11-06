import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/task_model.dart';
import '../../../providers/plan_provider.dart';

/// Quick add. The only capture path in v1.
///
/// Duration is asked for up front and is not optional: a task without a
/// time cost cannot be fitted against a real calendar, which is the whole
/// reason plain todo lists never turn into plans.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _durationMinutes = 30;
  TaskPriority _priority = TaskPriority.normal;
  DateTime? _deadline;
  bool _splittable = false;
  bool _saving = false;

  static const _durationChoices = [15, 30, 45, 60, 90, 120, 180, 240];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final task = TaskModel(
      taskId: '',
      title: _titleController.text.trim(),
      durationMinutes: _durationMinutes,
      deadline: _deadline?.toUtc(),
      priority: _priority,
      splittable: _splittable,
      createdAt: DateTime.now().toUtc(),
    );

    try {
      await ref.read(planControllerProvider).addTask(task);
      if (mounted) context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $error')),
      );
    }
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      // End of the chosen day — a deadline of "Thursday" means any time
      // that Thursday, not 00:00.
      setState(() => _deadline =
          DateTime(picked.year, picked.month, picked.day, 23, 59));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New task')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What needs doing?',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Give it a name'
                  : null,
            ),
            const SizedBox(height: 24),
            Text('How long?', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final minutes in _durationChoices)
                  ChoiceChip(
                    label: Text(_formatMinutes(minutes)),
                    selected: _durationMinutes == minutes,
                    onSelected: (_) =>
                        setState(() => _durationMinutes = minutes),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Priority', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<TaskPriority>(
              segments: const [
                ButtonSegment(value: TaskPriority.high, label: Text('High')),
                ButtonSegment(value: TaskPriority.normal, label: Text('Normal')),
                ButtonSegment(value: TaskPriority.low, label: Text('Low')),
              ],
              selected: {_priority},
              onSelectionChanged: (s) => setState(() => _priority = s.first),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Deadline'),
              subtitle: Text(_deadline == null
                  ? 'None'
                  : _formatDate(_deadline!)),
              trailing: _deadline == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _deadline = null),
                    ),
              onTap: _pickDeadline,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Can be split'),
              subtitle: const Text('Allow this to be spread across gaps'),
              value: _splittable,
              onChanged: (v) => setState(() => _splittable = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add and plan'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  if (minutes % 60 == 0) return '${minutes ~/ 60}h';
  return '${minutes ~/ 60}h ${minutes % 60}m';
}

String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}
