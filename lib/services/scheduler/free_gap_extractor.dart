import 'package:timezone/timezone.dart' as tz;
import '../../models/working_hours.dart';
import 'time_interval.dart';

/// Turns a calendar's busy intervals into the free gaps a plan can use.
///
/// Pure: the caller supplies `from`/`to` rather than this reading a clock,
/// which is what lets the DST and saturation cases be tested at all.
///
/// Walks local calendar days, because working hours are a local wall-clock
/// preference. Iterating UTC days would silently drift the window by an
/// hour either side of a DST transition.
List<TimeInterval> extractFreeGaps({
  required DateTime from,
  required DateTime to,
  required List<TimeInterval> busy,
  required WorkingHours workingHours,
  required String ianaTimeZone,
}) {
  if (!to.isAfter(from)) return const [];

  final location = tz.getLocation(ianaTimeZone);
  final merged = mergeIntervals(busy);
  final gaps = <TimeInterval>[];

  var day = tz.TZDateTime.from(from, location);
  day = tz.TZDateTime(location, day.year, day.month, day.day);
  final lastDay = tz.TZDateTime.from(to, location);

  while (!day.isAfter(lastDay)) {
    if (workingHours.includesWeekday(day.weekday)) {
      // Constructing from minutes-of-day via TZDateTime resolves the real
      // offset in force on that date, so 09:00 stays 09:00 local across a
      // transition instead of shifting with a fixed offset.
      final windowStart = tz.TZDateTime(
        location,
        day.year,
        day.month,
        day.day,
      ).add(Duration(minutes: workingHours.startMinuteOfDay));

      final windowEnd = tz.TZDateTime(
        location,
        day.year,
        day.month,
        day.day,
      ).add(Duration(minutes: workingHours.endMinuteOfDay));

      final clampedStart =
          windowStart.toUtc().isBefore(from) ? from : windowStart.toUtc();
      final clampedEnd = windowEnd.toUtc().isAfter(to) ? to : windowEnd.toUtc();

      if (clampedEnd.isAfter(clampedStart)) {
        gaps.addAll(
          subtractBusy(
            window: TimeInterval(start: clampedStart, end: clampedEnd),
            busy: merged,
          ),
        );
      }
    }
    day = tz.TZDateTime(location, day.year, day.month, day.day + 1);
  }

  return gaps;
}
