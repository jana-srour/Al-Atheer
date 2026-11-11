import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('ar'); // Default to Arabic
  double _textScale = 1.0;
  bool _reduceMotion = false;
  int _archiveIngestionDelaySeconds = 120; // Default 2 minutes
  bool _hideProcessingFromPublic = false;
  List<int> _favoriteIds = [];

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isSystemTheme => _themeMode == ThemeMode.system;
  bool get isArabic => _locale.languageCode == 'ar';
  bool get isRtl => const {'ar', 'fa', 'ur'}.contains(_locale.languageCode);
  double get textScale => _textScale;
  bool get reduceMotion => _reduceMotion;
  int get archiveIngestionDelaySeconds => _archiveIngestionDelaySeconds;
  bool get hideProcessingFromPublic => _hideProcessingFromPublic;
  List<int> get favoriteIds => _favoriteIds;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('theme_mode');
    final isDark = prefs.getBool('is_dark') ?? false;
    final lang = prefs.getString('language') ?? 'ar';
    _textScale = (prefs.getDouble('text_scale') ?? 1.0).clamp(0.85, 1.3);
    _reduceMotion = prefs.getBool('reduce_motion') ?? false;
    _archiveIngestionDelaySeconds =
        prefs.getInt('archive_ingestion_delay_seconds') ?? 120;
    _hideProcessingFromPublic =
        prefs.getBool('hide_processing_from_public') ?? false;

    final favsList = prefs.getStringList('favorite_resource_ids');
    if (favsList != null) {
      _favoriteIds = favsList
          .map((e) => int.tryParse(e) ?? 0)
          .where((id) => id > 0)
          .toList();
    }

    _themeMode = theme == 'system'
        ? ThemeMode.system
        : (theme == 'dark' || isDark ? ThemeMode.dark : ThemeMode.light);
    _locale = AppLocales.codes.contains(lang)
        ? Locale(lang)
        : const Locale('ar');
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark', isDark);
    await prefs.setString('theme_mode', isDark ? 'dark' : 'light');
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', switch (mode) {
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
    });
    await prefs.setBool('is_dark', mode == ThemeMode.dark);
  }

  Future<void> setLanguage(String languageCode) async {
    if (!AppLocales.codes.contains(languageCode)) return;
    _locale = Locale(languageCode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
  }

  Future<void> setTextScale(double scale) async {
    _textScale = scale.clamp(0.85, 1.3);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('text_scale', _textScale);
  }

  Future<void> setReduceMotion(bool reduce) async {
    _reduceMotion = reduce;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reduce_motion', reduce);
  }

  Future<void> setArchiveIngestionDelay(int seconds) async {
    _archiveIngestionDelaySeconds = seconds;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('archive_ingestion_delay_seconds', seconds);
  }

  Future<void> setHideProcessingFromPublic(bool hide) async {
    _hideProcessingFromPublic = hide;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hide_processing_from_public', hide);
  }

  bool isFavorite(int id) => _favoriteIds.contains(id);

  Future<void> toggleFavorite(int id) async {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'favorite_resource_ids',
      _favoriteIds.map((e) => e.toString()).toList(),
    );
  }
}

class AppLocales {
  static const codes = <String>{
    'ar',
    'en',
    'fa',
    'ur',
    'tr',
    'id',
    'fr',
    'es',
    'bn',
  };
}
