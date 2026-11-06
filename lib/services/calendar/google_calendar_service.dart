import 'package:googleapis/calendar/v3.dart' as gcal;
import '../auth/auth_token_service.dart';
import '../scheduler/time_interval.dart';

/// Thrown when the Calendar API cannot be reached or refuses the request.
///
/// Planning degrades to the cached busy intervals when this is raised, and
/// the UI must say so — silent degradation is treated as a bug.
class CalendarUnavailable implements Exception {
  CalendarUnavailable(this.message, {this.isAuthFailure = false});

  final String message;
  final bool isAuthFailure;

  @override
  String toString() => 'CalendarUnavailable: $message';
}

class GoogleCalendarService {
  GoogleCalendarService({required AuthTokenService authTokenService})
      : _authTokenService = authTokenService;

  final AuthTokenService _authTokenService;

  Future<gcal.CalendarApi> _api() async {
    final client = await _authTokenService.getAuthenticatedHttpClient();
    return gcal.CalendarApi(client);
  }

  /// Lists events from the user's primary calendar within a date range.
  Future<List<gcal.Event>> listEvents(DateTime start, DateTime end) async {
    try {
      final api = await _api();
      final events = await api.events.list(
        'primary',
        timeMin: start.toUtc(),
        timeMax: end.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );
      return events.items ?? [];
    } on gcal.DetailedApiRequestError catch (e) {
      throw CalendarUnavailable(
        e.message ?? 'Calendar request failed (${e.status})',
        isAuthFailure: e.status == 401 || e.status == 403,
      );
    }
  }

  /// The user's committed time in [start]..[end], as intervals the planner
  /// can subtract.
  ///
  /// All-day events are skipped: they signal a kind of day, not a block of
  /// unavailable hours, and treating them as busy would wipe out the whole
  /// working window. Declined events are skipped for the same reason —
  /// they are not actually commitments.
  Future<List<TimeInterval>> fetchBusyIntervals(
    DateTime start,
    DateTime end,
  ) async {
    final events = await listEvents(start, end);
    final intervals = <TimeInterval>[];

    for (final event in events) {
      if (event.status == 'cancelled') continue;
      if (_isDeclinedBySelf(event)) continue;
      if (event.transparency == 'transparent') continue;

      final from = event.start?.dateTime?.toUtc();
      final to = event.end?.dateTime?.toUtc();
      if (from == null || to == null) continue;

      final interval = TimeInterval(start: from, end: to);
      if (!interval.isEmpty) intervals.add(interval);
    }

    return mergeIntervals(intervals);
  }

  /// Mirrors a planned slot onto the calendar so the time is visibly
  /// blocked. Returns the Google Calendar event id.
  Future<String> insertSlotEvent({
    required String title,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final api = await _api();
      final event = gcal.Event()
        ..summary = title
        ..start = gcal.EventDateTime(dateTime: start.toUtc(), timeZone: 'UTC')
        ..end = gcal.EventDateTime(dateTime: end.toUtc(), timeZone: 'UTC')
        ..visibility = 'private';

      final inserted = await api.events.insert(event, 'primary');
      return inserted.id!;
    } on gcal.DetailedApiRequestError catch (e) {
      throw CalendarUnavailable(
        e.message ?? 'Calendar insert failed (${e.status})',
        isAuthFailure: e.status == 401 || e.status == 403,
      );
    }
  }

  Future<void> deleteSlotEvent(String googleCalendarEventId) async {
    try {
      final api = await _api();
      await api.events.delete('primary', googleCalendarEventId);
    } on gcal.DetailedApiRequestError catch (e) {
      // A slot event already gone from the calendar is the desired end
      // state, not a failure worth surfacing.
      if (e.status == 404 || e.status == 410) return;
      throw CalendarUnavailable(
        e.message ?? 'Calendar delete failed (${e.status})',
        isAuthFailure: e.status == 401 || e.status == 403,
      );
    }
  }

  bool _isDeclinedBySelf(gcal.Event event) =>
      event.attendees?.any(
        (a) => (a.self ?? false) && a.responseStatus == 'declined',
      ) ??
      false;
}
