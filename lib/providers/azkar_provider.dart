import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/azkar_model.dart';
import '../services/local_reminder_service.dart';

class AzkarProvider extends ChangeNotifier {
  static const _enabledKey = 'azkar_local_reminders_enabled';
  final SupabaseClient _supabase = Supabase.instance.client;
  List<AzkarModel> _azkar = [];
  bool _isLoading = true;
  String? _error;
  String? _notificationError;
  bool _remindersEnabled = false;
  late final Future<void> _ready;

  List<AzkarModel> get azkar => List.unmodifiable(_azkar);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get notificationError => _notificationError;
  bool get remindersEnabled => _remindersEnabled;

  AzkarProvider() {
    _ready = _initialize();
  }

  Future<void> _initialize() async {
    try {
      await LocalReminderService.initialize();
    } catch (error) {
      _notificationError = error.toString();
      debugPrint('Could not initialize local reminders: $error');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _remindersEnabled = prefs.getBool(_enabledKey) ?? false;
    } catch (error) {
      debugPrint('Could not load local reminder preference: $error');
    }
    await _fetchAzkar();
    if (_remindersEnabled && _notificationError == null) {
      try {
        await _scheduleLocalReminders();
      } catch (error) {
        _notificationError = error.toString();
        debugPrint('Could not schedule local reminders: $error');
      }
    }
    notifyListeners();
  }

  Future<void> fetchAzkar() async {
    await _ready;
    await _fetchAzkar();
    if (_remindersEnabled) await _scheduleLocalReminders();
  }

  Future<void> _fetchAzkar() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _supabase.from('azkar').select().order('scheduled_at');
      _azkar = (rows as List).map((row) => AzkarModel.fromJson(row)).toList();
    } catch (error) {
      _error = error.toString();
      debugPrint('Could not load azkar: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveAzkar(AzkarModel azkar) async {
    await _ready;
    if (azkar.id == 0) {
      await _supabase.from('azkar').insert(azkar.toJson());
    } else {
      await _supabase
          .from('azkar')
          .update({...azkar.toJson(), 'notification_sent_at': null})
          .eq('id', azkar.id);
    }
    await fetchAzkar();
  }

  Future<void> deleteAzkar(int id) async {
    await _ready;
    await _supabase.from('azkar').delete().eq('id', id);
    await LocalReminderService.cancel(id);
    await fetchAzkar();
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    await _ready;
    if (enabled) {
      if (_notificationError != null) {
        throw StateError(_notificationError!);
      }
      final granted = await LocalReminderService.requestPermission();
      if (!granted) {
        throw StateError('Notification permission was not granted.');
      }
    }
    _remindersEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    await refreshLocalReminders();
    notifyListeners();
  }

  Future<void> refreshLocalReminders({bool? soundEnabled}) async {
    await _ready;
    await _scheduleLocalReminders(soundEnabled: soundEnabled);
  }

  Future<void> _scheduleLocalReminders({bool? soundEnabled}) async {
    if (_notificationError != null && _remindersEnabled) {
      throw StateError(_notificationError!);
    }
    final prefs = await SharedPreferences.getInstance();
    final playSound =
        soundEnabled ?? (prefs.getBool('notification_alarm_sound') ?? true);
    await LocalReminderService.cancelExcept(
      _remindersEnabled ? _azkar.map((item) => item.id).toSet() : const <int>{},
    );
    for (final item in _azkar) {
      if (item.scheduledAt.isAfter(DateTime.now()) && _remindersEnabled) {
        await LocalReminderService.schedule(
          id: item.id,
          title: item.title,
          body: [
            item.content,
            if (item.description?.isNotEmpty == true) item.description!,
            if (item.source?.isNotEmpty == true) item.source!,
            '${item.category} • يكرر ${item.repetitionCount} مرات',
          ].join('\n'),
          scheduledAt: item.scheduledAt,
          soundEnabled: playSound,
        );
      } else {
        await LocalReminderService.cancel(item.id);
      }
    }
  }
}
