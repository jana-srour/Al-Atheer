import 'local_reminder_service_stub.dart'
    if (dart.library.io) 'local_reminder_service_mobile.dart'
    as platform;

class LocalReminderService {
  static Future<void> initialize() => platform.initialize();

  static Future<bool> requestPermission() => platform.requestPermission();

  static Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required bool soundEnabled,
  }) => platform.schedule(
    id: id,
    title: title,
    body: body,
    scheduledAt: scheduledAt,
    soundEnabled: soundEnabled,
  );

  static Future<void> cancel(int id) => platform.cancel(id);

  static Future<void> cancelExcept(Set<int> ids) => platform.cancelExcept(ids);
}
