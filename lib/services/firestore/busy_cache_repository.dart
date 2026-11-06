import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_constants.dart';
import '../scheduler/time_interval.dart';

/// Caches calendar busy intervals per local day.
///
/// Two jobs: planning still works offline, and a re-plan does not hammer
/// the Calendar API. The cache is advisory — a successful Calendar fetch
/// always overwrites it.
class BusyCacheRepository {
  BusyCacheRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _cache(String uid) =>
      _firestore
          .collection(FirestoreConstants.usersCollection)
          .doc(uid)
          .collection(FirestoreConstants.busyCacheCollection);

  /// `2026-11-09` in the user's local zone. Day-keyed rather than a single
  /// blob so a partial refresh does not invalidate the whole horizon.
  static String dayKeyFor(DateTime localDay) {
    final m = localDay.month.toString().padLeft(2, '0');
    final d = localDay.day.toString().padLeft(2, '0');
    return '${localDay.year}-$m-$d';
  }

  Future<void> write({
    required String uid,
    required String dayKey,
    required List<TimeInterval> intervals,
    required DateTime now,
  }) =>
      _cache(uid).doc(dayKey).set({
        FirestoreConstants.dayKey: dayKey,
        FirestoreConstants.cachedAt: Timestamp.fromDate(now),
        FirestoreConstants.intervals: intervals
            .map((i) => {
                  FirestoreConstants.start: Timestamp.fromDate(i.start),
                  FirestoreConstants.end: Timestamp.fromDate(i.end),
                })
            .toList(),
      });

  Future<List<TimeInterval>> read(String uid, String dayKey) async {
    final doc = await _cache(uid).doc(dayKey).get();
    if (!doc.exists) return const [];
    return _parseIntervals(doc.data()!);
  }

  /// Every cached interval across [dayKeys], for planning while offline.
  Future<List<TimeInterval>> readMany(
    String uid,
    List<String> dayKeys,
  ) async {
    final intervals = <TimeInterval>[];
    for (final key in dayKeys) {
      intervals.addAll(await read(uid, key));
    }
    return intervals;
  }

  static List<TimeInterval> _parseIntervals(Map<String, dynamic> data) {
    final raw = data[FirestoreConstants.intervals] as List? ?? const [];
    return raw.map((entry) {
      final map = entry as Map<String, dynamic>;
      return TimeInterval(
        start: (map[FirestoreConstants.start] as Timestamp).toDate().toUtc(),
        end: (map[FirestoreConstants.end] as Timestamp).toDate().toUtc(),
      );
    }).toList();
  }
}
