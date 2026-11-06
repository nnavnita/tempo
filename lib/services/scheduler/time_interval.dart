/// A half-open time range: `[start, end)`.
///
/// Half-open is what makes back-to-back intervals behave sanely — a meeting
/// ending at 11:00 and one starting at 11:00 do not overlap, and the gap
/// between them is zero-length rather than negative.
class TimeInterval {
  final DateTime start;
  final DateTime end;

  const TimeInterval({required this.start, required this.end});

  Duration get duration => end.difference(start);

  bool get isEmpty => !end.isAfter(start);

  bool overlaps(TimeInterval other) =>
      start.isBefore(other.end) && other.start.isBefore(end);

  TimeInterval copyWith({DateTime? start, DateTime? end}) => TimeInterval(
        start: start ?? this.start,
        end: end ?? this.end,
      );

  @override
  String toString() => 'TimeInterval($start → $end)';

  @override
  bool operator ==(Object other) =>
      other is TimeInterval && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Merges overlapping or touching intervals into a minimal sorted set.
///
/// Callers hand us busy intervals straight from Google Calendar, where
/// overlapping events are routine (a meeting inside a blocked-out morning).
/// Without merging first, subtraction would cut the same span twice and
/// emit bogus zero-or-negative-length gaps.
List<TimeInterval> mergeIntervals(List<TimeInterval> intervals) {
  final sorted = intervals.where((i) => !i.isEmpty).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  if (sorted.isEmpty) return const [];

  final merged = <TimeInterval>[sorted.first];
  for (final current in sorted.skip(1)) {
    final last = merged.last;
    if (current.start.isAfter(last.end)) {
      merged.add(current);
    } else if (current.end.isAfter(last.end)) {
      merged[merged.length - 1] = last.copyWith(end: current.end);
    }
  }
  return merged;
}

/// Returns the parts of [window] not covered by [busy], in chronological
/// order. Zero-length results are dropped: a gap you cannot put anything
/// into is not a gap.
List<TimeInterval> subtractBusy({
  required TimeInterval window,
  required List<TimeInterval> busy,
}) {
  if (window.isEmpty) return const [];

  final free = <TimeInterval>[];
  var cursor = window.start;

  for (final block in mergeIntervals(busy)) {
    if (!block.end.isAfter(window.start)) continue;
    if (!block.start.isBefore(window.end)) break;

    if (block.start.isAfter(cursor)) {
      free.add(TimeInterval(start: cursor, end: block.start));
    }
    if (block.end.isAfter(cursor)) cursor = block.end;
  }

  if (cursor.isBefore(window.end)) {
    free.add(TimeInterval(start: cursor, end: window.end));
  }

  return free;
}
