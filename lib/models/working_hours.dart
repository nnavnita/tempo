/// When the user is willing to have work placed.
///
/// Stored as minutes-from-local-midnight rather than a `DateTime` because
/// the same 9am–6pm preference has to apply across DST transitions, where
/// "9am local" is not a fixed UTC offset.
class WorkingHours {
  final int startMinuteOfDay;
  final int endMinuteOfDay;

  /// `DateTime.monday` (1) .. `DateTime.sunday` (7).
  final Set<int> weekdays;

  const WorkingHours({
    required this.startMinuteOfDay,
    required this.endMinuteOfDay,
    required this.weekdays,
  });

  /// Weekdays, 9am–6pm.
  static const WorkingHours defaults = WorkingHours(
    startMinuteOfDay: 9 * 60,
    endMinuteOfDay: 18 * 60,
    weekdays: {
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    },
  );

  bool includesWeekday(int weekday) => weekdays.contains(weekday);

  Map<String, dynamic> toMap() => {
        'startMinuteOfDay': startMinuteOfDay,
        'endMinuteOfDay': endMinuteOfDay,
        'weekdays': weekdays.toList()..sort(),
      };

  factory WorkingHours.fromMap(Map<String, dynamic> map) => WorkingHours(
        startMinuteOfDay: map['startMinuteOfDay'] as int,
        endMinuteOfDay: map['endMinuteOfDay'] as int,
        weekdays: (map['weekdays'] as List).cast<int>().toSet(),
      );
}
