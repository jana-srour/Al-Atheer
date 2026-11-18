Future<void> initialize() async {}

Future<bool> requestPermission() async => false;

Future<void> schedule({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledAt,
  required bool soundEnabled,
}) async {}

Future<void> cancel(int id) async {}

Future<void> cancelExcept(Set<int> ids) async {}
