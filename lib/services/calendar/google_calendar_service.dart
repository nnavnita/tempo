import 'package:googleapis/calendar/v3.dart' as gcal;
import '../auth/auth_token_service.dart';
import '../../models/event_model.dart';

class GoogleCalendarService {
  GoogleCalendarService({required AuthTokenService authTokenService})
      : _authTokenService = authTokenService;

  final AuthTokenService _authTokenService;

  Future<gcal.CalendarApi> _api() async {
    final client = await _authTokenService.getAuthenticatedHttpClient();
    return gcal.CalendarApi(client);
  }

  /// Inserts an event into the authenticated user's primary Google Calendar.
  /// Returns the Google Calendar event ID.
  Future<String> insertEvent(EventModel event) async {
    final api = await _api();

    final gcalEvent = gcal.Event()
      ..summary = event.title
      ..description = event.description
      ..location = event.location
      ..start = gcal.EventDateTime(
        dateTime: event.startTime.toUtc(),
        timeZone: 'UTC',
      )
      ..end = gcal.EventDateTime(
        dateTime: event.endTime.toUtc(),
        timeZone: 'UTC',
      )
      ..visibility = _mapVisibility(event.visibility);

    final inserted = await api.events.insert(gcalEvent, 'primary');
    return inserted.id!;
  }

  /// Updates an existing Google Calendar event.
  Future<void> updateEvent(EventModel event) async {
    if (event.googleCalendarEventId == null) return;
    final api = await _api();

    final gcalEvent = gcal.Event()
      ..summary = event.title
      ..description = event.description
      ..location = event.location
      ..start = gcal.EventDateTime(
        dateTime: event.startTime.toUtc(),
        timeZone: 'UTC',
      )
      ..end = gcal.EventDateTime(
        dateTime: event.endTime.toUtc(),
        timeZone: 'UTC',
      )
      ..visibility = _mapVisibility(event.visibility);

    await api.events
        .update(gcalEvent, 'primary', event.googleCalendarEventId!);
  }

  /// Deletes a Google Calendar event.
  Future<void> deleteEvent(String googleCalendarEventId) async {
    final api = await _api();
    await api.events.delete('primary', googleCalendarEventId);
  }

  /// Inserts a copy of an event into the currently authenticated user's
  /// Google Calendar. Used when a join request is approved or invitation
  /// is accepted — the attendee is the active user at that moment.
  Future<String> insertEventForCurrentUser(EventModel event) async {
    return insertEvent(event);
  }

  /// Lists events from the user's primary calendar within a date range.
  Future<List<gcal.Event>> listEvents(DateTime start, DateTime end) async {
    final api = await _api();
    final events = await api.events.list(
      'primary',
      timeMin: start.toUtc(),
      timeMax: end.toUtc(),
      singleEvents: true,
      orderBy: 'startTime',
    );
    return events.items ?? [];
  }

  /// Maps Tempo visibility to Google Calendar visibility string.
  String _mapVisibility(String visibility) {
    switch (visibility) {
      case 'private':
        return 'private';
      case 'friends':
        // Google Calendar doesn't have a native "friends" visibility;
        // we use 'default' (respects calendar sharing settings).
        return 'default';
      case 'everyone':
        return 'public';
      default:
        return 'default';
    }
  }
}
