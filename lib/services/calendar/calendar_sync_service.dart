import 'package:uuid/uuid.dart';
import '../auth/auth_service.dart';
import '../firestore/event_repository.dart';
import '../firestore/busy_slot_repository.dart';
import 'google_calendar_service.dart';
import '../../models/event_model.dart';
import '../../models/busy_slot_model.dart';

/// Orchestrates the dual-write to Firestore and Google Calendar.
/// Every event mutation goes through this service to keep both systems
/// in sync and to manage busy_slots for private events.
class CalendarSyncService {
  CalendarSyncService({
    required AuthService authService,
    required EventRepository eventRepository,
    required BusySlotRepository busySlotRepository,
    required GoogleCalendarService googleCalendarService,
  })  : _authService = authService,
        _eventRepository = eventRepository,
        _busySlotRepository = busySlotRepository,
        _googleCalendarService = googleCalendarService;

  final AuthService _authService;
  final EventRepository _eventRepository;
  final BusySlotRepository _busySlotRepository;
  final GoogleCalendarService _googleCalendarService;

  final _uuid = const Uuid();

  /// Creates an event in Firestore and Google Calendar, then writes a
  /// busy_slot if the event is private.
  Future<EventModel> createEvent({
    required String title,
    String? description,
    String? location,
    required DateTime startTime,
    required DateTime endTime,
    required String visibility,
  }) async {
    final uid = _authService.currentUser!.uid;
    final eventId = _uuid.v4();
    final now = DateTime.now();

    var event = EventModel(
      eventId: eventId,
      ownerUid: uid,
      title: title,
      description: description,
      location: location,
      startTime: startTime,
      endTime: endTime,
      visibility: visibility,
      createdAt: now,
      updatedAt: now,
    );

    // Write to Firestore first so the document exists
    await _eventRepository.createEvent(event);

    // Insert into Google Calendar
    try {
      final gcalId = await _googleCalendarService.insertEvent(event);
      event = event.copyWith(googleCalendarEventId: gcalId);
      await _eventRepository.updateEvent(event);
    } catch (e) {
      // Calendar sync failure is non-fatal; the event still exists in Firestore
      // TODO: add a retry queue / background sync
    }

    // Write busy_slot for private events so others can see the time is blocked
    if (event.isPrivate) {
      final slot = BusySlotModel(
        slotId: BusySlotModel.buildSlotId(uid, eventId),
        ownerUid: uid,
        eventId: eventId,
        startTime: startTime,
        endTime: endTime,
      );
      await _busySlotRepository.upsertBusySlot(slot);
    }

    return event;
  }

  /// Updates an event in both Firestore and Google Calendar.
  /// Re-creates or deletes busy_slot as visibility changes.
  Future<EventModel> updateEvent(EventModel updated) async {
    final previous = await _eventRepository.getEvent(updated.eventId);

    await _eventRepository.updateEvent(updated);

    if (updated.googleCalendarEventId != null) {
      try {
        await _googleCalendarService.updateEvent(updated);
      } catch (_) {}
    }

    // Handle busy_slot changes based on visibility change
    if (previous != null) {
      final wasPrivate = previous.isPrivate;
      final isNowPrivate = updated.isPrivate;

      if (!wasPrivate && isNowPrivate) {
        // Became private → create busy_slot
        final slot = BusySlotModel(
          slotId: BusySlotModel.buildSlotId(updated.ownerUid, updated.eventId),
          ownerUid: updated.ownerUid,
          eventId: updated.eventId,
          startTime: updated.startTime,
          endTime: updated.endTime,
        );
        await _busySlotRepository.upsertBusySlot(slot);
      } else if (wasPrivate && !isNowPrivate) {
        // No longer private → delete busy_slot
        await _busySlotRepository.deleteBusySlot(
          BusySlotModel.buildSlotId(updated.ownerUid, updated.eventId),
        );
      } else if (isNowPrivate) {
        // Still private but time may have changed → update busy_slot
        final slot = BusySlotModel(
          slotId: BusySlotModel.buildSlotId(updated.ownerUid, updated.eventId),
          ownerUid: updated.ownerUid,
          eventId: updated.eventId,
          startTime: updated.startTime,
          endTime: updated.endTime,
        );
        await _busySlotRepository.upsertBusySlot(slot);
      }
    }

    return updated;
  }

  /// Deletes an event from Firestore, Google Calendar, and removes busy_slot.
  Future<void> deleteEvent(EventModel event) async {
    await _eventRepository.deleteEvent(event.eventId);

    if (event.googleCalendarEventId != null) {
      try {
        await _googleCalendarService.deleteEvent(event.googleCalendarEventId!);
      } catch (_) {}
    }

    await _busySlotRepository.deleteBusySlot(
      BusySlotModel.buildSlotId(event.ownerUid, event.eventId),
    );
  }

  /// Called when a join request is approved or an invitation is accepted.
  /// Updates Firestore attendeeUids. If the attendee IS the currently
  /// authenticated user (invitation acceptance), also inserts the event into
  /// their Google Calendar. When the owner approves someone else's request the
  /// calendar insert happens on the attendee's next interaction instead.
  Future<void> addAttendeeToEvent({
    required EventModel event,
    required String attendeeUid,
  }) async {
    final currentUid = _authService.currentUser?.uid;

    // Only insert into Google Calendar when the attendee is the current user
    // (e.g. accepting an invitation). Owners approving others' requests cannot
    // insert into a third party's calendar client-side.
    if (currentUid == attendeeUid) {
      try {
        await _googleCalendarService.insertEventForCurrentUser(event);
      } catch (_) {}
    }

    // Update Firestore attendeeUids
    if (!event.attendeeUids.contains(attendeeUid)) {
      final updatedUids = [...event.attendeeUids, attendeeUid];
      await _eventRepository.updateEvent(
        event.copyWith(attendeeUids: updatedUids),
      );
    }
  }
}
