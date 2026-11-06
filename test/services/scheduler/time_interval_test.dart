import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/services/scheduler/time_interval.dart';

TimeInterval iv(int startHour, int endHour) => TimeInterval(
      start: DateTime.utc(2026, 11, 9, startHour),
      end: DateTime.utc(2026, 11, 9, endHour),
    );

void main() {
  group('TimeInterval', () {
    test('duration is the span between start and end', () {
      expect(iv(9, 11).duration, const Duration(hours: 2));
    });

    test('overlapping intervals report an overlap', () {
      expect(iv(9, 12).overlaps(iv(11, 13)), isTrue);
    });

    test('intervals touching end-to-start do not overlap', () {
      expect(iv(9, 11).overlaps(iv(11, 13)), isFalse);
    });

    test('disjoint intervals do not overlap', () {
      expect(iv(9, 10).overlaps(iv(14, 15)), isFalse);
    });

    test('a contained interval overlaps its container', () {
      expect(iv(9, 17).overlaps(iv(12, 13)), isTrue);
    });
  });

  group('subtractBusy', () {
    test('returns the whole window when nothing is busy', () {
      final result = subtractBusy(window: iv(9, 17), busy: []);

      expect(result, hasLength(1));
      expect(result.single.start, iv(9, 17).start);
      expect(result.single.end, iv(9, 17).end);
    });

    test('splits the window around a busy interval in the middle', () {
      final result = subtractBusy(window: iv(9, 17), busy: [iv(12, 13)]);

      expect(result, hasLength(2));
      expect(result[0].start, DateTime.utc(2026, 11, 9, 9));
      expect(result[0].end, DateTime.utc(2026, 11, 9, 12));
      expect(result[1].start, DateTime.utc(2026, 11, 9, 13));
      expect(result[1].end, DateTime.utc(2026, 11, 9, 17));
    });

    test('trims the front when busy overlaps the window start', () {
      final result = subtractBusy(window: iv(9, 17), busy: [iv(8, 10)]);

      expect(result, hasLength(1));
      expect(result.single.start, DateTime.utc(2026, 11, 9, 10));
      expect(result.single.end, DateTime.utc(2026, 11, 9, 17));
    });

    test('trims the tail when busy overlaps the window end', () {
      final result = subtractBusy(window: iv(9, 17), busy: [iv(16, 20)]);

      expect(result, hasLength(1));
      expect(result.single.end, DateTime.utc(2026, 11, 9, 16));
    });

    test('returns nothing when busy covers the whole window', () {
      expect(subtractBusy(window: iv(9, 17), busy: [iv(8, 18)]), isEmpty);
    });

    test('merges overlapping busy intervals rather than double-cutting', () {
      final result =
          subtractBusy(window: iv(9, 17), busy: [iv(11, 13), iv(12, 14)]);

      expect(result, hasLength(2));
      expect(result[0].end, DateTime.utc(2026, 11, 9, 11));
      expect(result[1].start, DateTime.utc(2026, 11, 9, 14));
    });

    test('handles unsorted busy input', () {
      final result =
          subtractBusy(window: iv(9, 17), busy: [iv(15, 16), iv(10, 11)]);

      expect(result, hasLength(3));
      expect(result[0].end, DateTime.utc(2026, 11, 9, 10));
      expect(result[1].start, DateTime.utc(2026, 11, 9, 11));
      expect(result[1].end, DateTime.utc(2026, 11, 9, 15));
      expect(result[2].start, DateTime.utc(2026, 11, 9, 16));
    });

    test('ignores busy intervals entirely outside the window', () {
      final result = subtractBusy(window: iv(9, 17), busy: [iv(20, 22)]);

      expect(result, hasLength(1));
      expect(result.single.duration, const Duration(hours: 8));
    });

    test('drops zero-length gaps left by adjacent busy intervals', () {
      final result = subtractBusy(window: iv(9, 17), busy: [iv(9, 12), iv(12, 17)]);

      expect(result, isEmpty);
    });
  });
}
