import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/plan_provider.dart';

/// Shown when the last plan was built from cached calendar data.
///
/// Degraded planning is always visible. A plan built without live calendar
/// data can book over real commitments, and letting that happen silently
/// is the fastest way for the user to stop trusting the plan.
class DegradedPlanBanner extends ConsumerWidget {
  const DegradedPlanBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(lastPlanOutcomeProvider);
    if (outcome == null || !outcome.usedCachedCalendar) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: AppColors.warning.withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Planned from cached calendar data — new events may not be '
              'accounted for.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
