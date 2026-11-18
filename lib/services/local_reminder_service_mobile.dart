import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();
bool _initialized = false;

Future<void> initialize() async {
  if (_initialized) return;
  timezone_data.initializeTimeZones();
  final localTimezone = await FlutterTimezone.getLocalTimezone();
  timezone.setLocalLocation(timezone.getLocation(localTimezone.identifier));
  await _notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );
  _initialized = true;
}

Future<bool> requestPermission() async {
  await initialize();
  final android = _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  final androidGranted = await android?.requestNotificationsPermission();
  final exactAlarmsGranted = await android?.requestExactAlarmsPermission();
  final ios = _notifications
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();
  final iosGranted = await ios?.requestPermissions(
    alert: true,
    badge: true,
    sound: true,
  );
  return androidGranted == false || exactAlarmsGranted == false
      ? false
      : (androidGranted ?? iosGranted ?? true);
}

Future<void> schedule({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledAt,
  required bool soundEnabled,
}) async {
  await initialize();
  if (!scheduledAt.isAfter(DateTime.now())) return;
  await _notifications.zonedSchedule(
    id: id,
    title: title,
    body: body,
    payload: 'azkar:$id',
    scheduledDate: timezone.TZDateTime.from(scheduledAt, timezone.local),
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        soundEnabled ? 'azkar_reminders_sound' : 'azkar_reminders_silent',
        'تذكيرات الأذكار',
        channelDescription: 'تنبيهات الأذكار المجدولة',
        importance: Importance.max,
        priority: Priority.high,
        playSound: soundEnabled,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: DarwinNotificationDetails(
        presentSound: soundEnabled,
        sound: soundEnabled ? null : '',
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  );
}

Future<void> cancel(int id) async {
  await initialize();
  await _notifications.cancel(id: id);
}

Future<void> cancelExcept(Set<int> ids) async {
  await initialize();
  final pending = await _notifications.pendingNotificationRequests();
  for (final notification in pending) {
    if (notification.payload?.startsWith('azkar:') == true &&
        !ids.contains(notification.id)) {
      await _notifications.cancel(id: notification.id);
    }
  }
}
