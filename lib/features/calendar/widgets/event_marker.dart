import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/event_model.dart';

class EventMarker extends StatelessWidget {
  const EventMarker({super.key, required this.event});

  final EventModel event;

  Color get _color {
    switch (event.visibility) {
      case 'private':
        return AppColors.privateEvent;
      case 'friends':
        return AppColors.friendsEvent;
      case 'everyone':
        return AppColors.publicEvent;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
      ),
    );
  }
}
