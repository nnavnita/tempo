import '../scheduler/time_interval.dart';

/// The planner's view of a calendar: just the committed time.
///
/// Exists so [PlanWriter] depends on the capability rather than on the
/// Google client, which makes the orchestration testable without faking
/// OAuth. Implemented by GoogleCalendarService.
abstract class BusyIntervalSource {
  Future<List<TimeInterval>> fetchBusyIntervals(DateTime from, DateTime to);
}
