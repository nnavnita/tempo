import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/notification_bell_action.dart';
import '../../../models/event_model.dart';
import '../../../providers/events_provider.dart';
import '../widgets/event_marker.dart';
import '../../events/widgets/event_card.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  Future<void> _showMonthYearPicker() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthYearPicker(current: _focusedDay),
    );
    if (picked != null) {
      setState(() {
        _focusedDay = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsByDay = ref.watch(eventsByDayProvider);
    final monthLabel = DateFormat('MMMM y').format(_focusedDay);

    final normalizedSelected = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final selectedEvents = eventsByDay[normalizedSelected] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(monthLabel),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_view_month_outlined),
            tooltip: 'Jump to month',
            onPressed: _showMonthYearPicker,
          ),
          const NotificationBellAction(),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            child: TableCalendar<EventModel>(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              calendarFormat: _calendarFormat,
              eventLoader: (day) {
                final normalized = DateTime(day.year, day.month, day.day);
                return eventsByDay[normalized] ?? [];
              },
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              onPageChanged: (focused) {
                setState(() => _focusedDay = focused);
              },
              daysOfWeekHeight: 28,
              rowHeight: 48,
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: false,
                titleTextStyle: const TextStyle(
                  fontSize: 0,
                  color: Colors.transparent,
                ),
                leftChevronIcon: const Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: AppColors.onSurfaceVariant,
                ),
                rightChevronIcon: const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.onSurfaceVariant,
                ),
                formatButtonDecoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                formatButtonTextStyle: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                headerPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                ),
                weekendStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              calendarStyle: CalendarStyle(
                cellMargin: const EdgeInsets.all(4),
                defaultTextStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurface,
                ),
                weekendTextStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurface,
                ),
                outsideTextStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                // Today: ring outline only, no fill
                todayDecoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                todayTextStyle: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                markerSize: 5,
                markersMaxCount: 3,
                markerMargin: const EdgeInsets.symmetric(horizontal: 1),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;
                  return Positioned(
                    bottom: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: events
                          .take(3)
                          .map((e) => EventMarker(event: e))
                          .toList(),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: selectedEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_note_outlined,
                          size: 36,
                          color: AppColors.onSurfaceVariant
                              .withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No events',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: selectedEvents.length,
                    itemBuilder: (context, index) {
                      final event = selectedEvents[index];
                      return EventCard(
                        event: event,
                        onTap: () => context.push('/event/${event.eventId}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Month / Year picker modal ─────────────────────────────────────────────────

class _MonthYearPicker extends StatefulWidget {
  const _MonthYearPicker({required this.current});

  final DateTime current;

  @override
  State<_MonthYearPicker> createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<_MonthYearPicker> {
  late int _year;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr',
    'May', 'Jun', 'Jul', 'Aug',
    'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.current.year;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // Year row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _year--),
              ),
              Text(
                '$_year',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _year++),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Month grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2,
            ),
            itemCount: 12,
            itemBuilder: (context, i) {
              final month = i + 1;
              final isSelected = _year == widget.current.year &&
                  month == widget.current.month;
              final isToday =
                  _year == now.year && month == now.month;
              return GestureDetector(
                onTap: () =>
                    Navigator.of(context).pop(DateTime(_year, month)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : isToday
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(color: AppColors.primary, width: 1.5)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _months[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? Colors.white
                          : isToday
                              ? AppColors.primary
                              : AppColors.onSurface,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
