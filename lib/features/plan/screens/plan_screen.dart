import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/plan_state.dart';
import '../../../models/scheduled_slot.dart';
import '../../../providers/plan_provider.dart';
import '../widgets/degraded_plan_banner.dart';
import '../widgets/slot_tile.dart';

/// Today's placed work.
///
/// Re-plans on first build so the plan reflects calendar changes made
/// elsewhere since the app was last open — the client cannot rely on
/// background execution for this.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(planControllerProvider);
      controller.registerForReplanPushes();
      controller.replan(ReplanReason.appForegrounded);
    });
  }

  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(slotsProvider(1));
    final tasks = ref.watch(allTasksProvider);

    final titles = <String, String>{
      for (final task in tasks.valueOrNull ?? const []) task.taskId: task.title,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: Column(
        children: [
          const DegradedPlanBanner(),
          Expanded(
            child: slots.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _PlanError(message: '$error'),
              data: (data) => data.isEmpty
                  ? const _EmptyPlan()
                  : RefreshIndicator(
                      onRefresh: () async => ref
                          .read(planControllerProvider)
                          .replan(ReplanReason.appForegrounded),
                      child: ListView.separated(
                        itemCount: data.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final slot = data[index];
                          return SlotTile(
                            slot: slot,
                            title: titles[slot.taskId] ?? 'Task',
                            onComplete: () => ref
                                .read(planControllerProvider)
                                .completeTask(slot.taskId),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 48, color: AppColors.onSurfaceVariant),
            SizedBox(height: 16),
            Text(
              'Nothing placed today',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Add a task and it will be fitted into your next free gap.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanError extends StatelessWidget {
  const _PlanError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: 12),
            const Text('Could not load your plan'),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The next two weeks of placed work, grouped by day.
class HorizonScreen extends ConsumerWidget {
  const HorizonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(slotsProvider(PlanState.horizon.inDays));
    final tasks = ref.watch(allTasksProvider);

    final titles = <String, String>{
      for (final task in tasks.valueOrNull ?? const []) task.taskId: task.title,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Next two weeks')),
      body: Column(
        children: [
          const DegradedPlanBanner(),
          Expanded(
            child: slots.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _PlanError(message: '$error'),
              data: (data) {
                if (data.isEmpty) return const _EmptyPlan();
                final grouped = _groupByLocalDay(data);

                return ListView.builder(
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final entry = grouped[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                          child: Text(
                            entry.label,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: AppColors.primary),
                          ),
                        ),
                        for (final slot in entry.slots)
                          SlotTile(
                            slot: slot,
                            title: titles[slot.taskId] ?? 'Task',
                            onComplete: () => ref
                                .read(planControllerProvider)
                                .completeTask(slot.taskId),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DayGroup {
  final String label;
  final List<ScheduledSlot> slots;

  const _DayGroup(this.label, this.slots);
}

List<_DayGroup> _groupByLocalDay(List<ScheduledSlot> slots) {
  final byDay = <String, List<ScheduledSlot>>{};
  for (final slot in slots) {
    final local = slot.start.toLocal();
    final key = '${local.year}-${local.month}-${local.day}';
    (byDay[key] ??= []).add(slot);
  }

  return byDay.entries
      .map((e) => _DayGroup(_dayLabel(e.value.first.start.toLocal()), e.value))
      .toList();
}

String _dayLabel(DateTime local) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${weekdays[local.weekday - 1]} ${local.day} ${months[local.month - 1]}';
}
