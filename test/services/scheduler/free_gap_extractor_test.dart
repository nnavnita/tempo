import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:tempo/models/working_hours.dart';
import 'package:tempo/services/scheduler/free_gap_extractor.dart';
import 'package:tempo/services/scheduler/time_interval.dart';

const melbourne = 'Australia/Melbourne';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('extractFreeGaps', () {
    test('yields one working window for a single weekday', () {
      // Mon 9 Nov 2026 is AEDT (+11), so 09:00 local == 22:00 UTC Sun 8 Nov.
      final gaps = extractFreeGaps(
        from: DateTime.utc(2026, 11, 8, 12),
        to: DateTime.utc(2026, 11, 9, 12),
        busy: const [],
        workingHours: WorkingHours.defaults,
        ianaTimeZone: melbourne,
      );

      expect(gaps, hasLength(1));
      expect(gaps.single.start, DateTime.utc(2026, 11, 8, 22));
      expect(gaps.single.end, DateTime.utc(2026, 11, 9, 7));
      expect(gaps.single.duration, const Duration(hours: 9));
    });

    test('skips days outside the configured weekdays', () {
      // Sat 7 Nov – Sun 8 Nov 2026 are both excluded by the defaults.
      final gaps = extractFreeGaps(
        from: DateTime.utc(2026, 11, 6, 12),
        to: DateTime.utc(2026, 11, 8, 12),
        busy: const [],
        workingHours: WorkingHours.defaults,
        ianaTimeZone: melbourne,
      );

      expect(gaps, isEmpty);
    });

    test('clamps the first window to the from instant', () {
      // from = 02:00 UTC Mon == 13:00 local Mon, mid-window.
      final gaps = extractFreeGaps(
        from: DateTime.utc(2026, 11, 9, 2),
        to: DateTime.utc(2026, 11, 9, 12),
        busy: const [],
        workingHours: WorkingHours.defaults,
        ianaTimeZone: melbourne,
      );

      expect(gaps, hasLength(1));
      expect(gaps.single.start, DateTime.utc(2026, 11, 9, 2));
      expect(gaps.single.end, DateTime.utc(2026, 11, 9, 7));
    });

    test('subtracts busy intervals inside the working window', () {
      final gaps = extractFreeGaps(
        from: DateTime.utc(2026, 11, 8, 12),
        to: DateTime.utc(2026, 11, 9, 12),
        busy: [
          TimeInterval(
            start: DateTime.utc(2026, 11, 9, 0),
            end: DateTime.utc(2026, 11, 9, 1),
          ),
        ],
        workingHours: WorkingHours.defaults,
        ianaTimeZone: melbourne,
      );

      expect(gaps, hasLength(2));
      expect(gaps[0].end, DateTime.utc(2026, 11, 9, 0));
      expect(gaps[1].start, DateTime.utc(2026, 11, 9, 1));
    });

    test('tracks the UTC offset shift across a DST transition', () {
      // Melbourne springs forward at 02:00 local on Sun 4 Oct 2026.
      // Fri 2 Oct is AEST (+10): 09:00 local == 23:00 UTC 1 Oct.
      // Mon 5 Oct is AEDT (+11): 09:00 local == 22:00 UTC 4 Oct.
      final gaps = extractFreeGaps(
        from: DateTime.utc(2026, 10, 1, 12),
        to: DateTime.utc(2026, 10, 5, 12),
        busy: const [],
        workingHours: WorkingHours.defaults,
        ianaTimeZone: melbourne,
      );

      expect(gaps, hasLength(2));
      expect(gaps[0].start, DateTime.utc(2026, 10, 1, 23));
      expect(gaps[1].start, DateTime.utc(2026, 10, 4, 22));

      // The preference is 9 hours of local wall-clock time on both sides
      // of the transition, even though the UTC offset changed.
      expect(gaps[0].duration, const Duration(hours: 9));
      expect(gaps[1].duration, const Duration(hours: 9));
    });

    test('returns nothing when the horizon is empty', () {
      final gaps = extractFreeGaps(
        from: DateTime.utc(2026, 11, 9, 5),
        to: DateTime.utc(2026, 11, 9, 5),
        busy: const [],
        workingHours: WorkingHours.defaults,
        ianaTimeZone: melbourne,
      );

      expect(gaps, isEmpty);
    });

    test('returns nothing when busy saturates every working window', () {
      final gaps = extractFreeGaps(
        from: DateTime.utc(2026, 11, 8, 12),
        to: DateTime.utc(2026, 11, 9, 12),
        busy: [
          TimeInterval(
            start: DateTime.utc(2026, 11, 8, 20),
            end: DateTime.utc(2026, 11, 9, 10),
          ),
        ],
        workingHours: WorkingHours.defaults,
        ianaTimeZone: melbourne,
      );

      expect(gaps, isEmpty);
    });
  });
}
