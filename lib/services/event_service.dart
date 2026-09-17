import '../models/safety.dart';
import '../repositories/safety_repository.dart';
import 'device_services.dart';

/// Durable recording precedes optional feedback. Notification failure never drops events.
class EventService {
  final SafetyRepository repository;
  final NotificationService notification;
  EventService(this.repository, this.notification);
  Future<void> persist(List<SafetyEvent> events) =>
      repository.addEvents(events);
  Future<bool> feedback(
    List<SafetyEvent> events,
    SafetySettings settings,
  ) async {
    bool delivered = true;
    for (final event in events) {
      if (event.type == 'ppe_scan' &&
          events.any((e) => e.type == 'ppe_violation')) {
        continue;
      }
      try {
        await notification.alert(event, settings);
      } catch (_) {
        delivered = false;
      }
    }
    return delivered;
  }
}
