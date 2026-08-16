import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

class VisibilitySelector extends StatelessWidget {
  const VisibilitySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who can see this event?',
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: 8),
        _VisibilityOption(
          selected: value == AppConstants.visibilityPrivate,
          icon: Icons.lock_outline,
          label: 'Private',
          sublabel: 'Only you can see this. Others see you as busy.',
          color: AppColors.privateEvent,
          onTap: () => onChanged(AppConstants.visibilityPrivate),
        ),
        const SizedBox(height: 8),
        _VisibilityOption(
          selected: value == AppConstants.visibilityFriends,
          icon: Icons.people_outline,
          label: 'Friends',
          sublabel: 'Visible to your friends. They can request to join.',
          color: AppColors.friendsEvent,
          onTap: () => onChanged(AppConstants.visibilityFriends),
        ),
        const SizedBox(height: 8),
        _VisibilityOption(
          selected: value == AppConstants.visibilityEveryone,
          icon: Icons.public,
          label: 'Everyone',
          sublabel: 'Anyone using Tempo can see and request to join.',
          color: AppColors.publicEvent,
          onTap: () => onChanged(AppConstants.visibilityEveryone),
        ),
      ],
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  const _VisibilityOption({
    required this.selected,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? color : const Color(0xFFDADCE0),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected ? color.withOpacity(0.05) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? color : AppColors.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? color : AppColors.onSurface,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
