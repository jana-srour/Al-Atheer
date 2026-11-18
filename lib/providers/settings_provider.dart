import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/web_branding_client.dart';

class SettingsProvider extends ChangeNotifier {
  static const _legacyFavoriteIdsKey = 'favorite_resource_ids';
  static const _guestFavoriteIdsKey = 'favorite_resource_ids_guest';
  static const _userFavoriteIdsKeyPrefix = 'favorite_resource_ids_user_';
  static const _appBrandingBucket = 'app-branding';
  static const _maxAppLogoBytes = 5 * 1024 * 1024;

  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('ar'); // Default to Arabic
  String _appNameAr = 'الأثير للنشر والتوزيع';
  String _appNameEn = 'Al-Atheer Islamic Library & Digital Media';
  String? _appLogoUrl;
  String? _appBrandingError;
  double _textScale = 1.0;
  bool _reduceMotion = false;
  bool _notificationAlarmSoundEnabled = true;
  int _archiveIngestionDelaySeconds = 120; // Default 2 minutes
  bool _hideProcessingFromPublic = false;
  List<int> _favoriteIds = [];
  String? _activeUserId;
  String? _favoriteSyncError;
  int _favoriteLoadRevision = 0;
  final Map<String?, Map<int, bool>> _favoriteMutations = {};
  Future<void> _localFavoriteWrites = Future<void>.value();
  Future<void> _remoteFavoriteWrites = Future<void>.value();
  late final StreamSubscription<AuthState> _authSubscription;
  late final Future<void> appBrandingReady;
  final SupabaseClient _supabase = Supabase.instance.client;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  String get appNameAr => _appNameAr;
  String get appNameEn => _appNameEn;
  String get appName => isArabic ? _appNameAr : _appNameEn;
  String? get appLogoUrl => _appLogoUrl;
  String? get appBrandingError => _appBrandingError;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isSystemTheme => _themeMode == ThemeMode.system;
  bool get isArabic => _locale.languageCode == 'ar';
  bool get isRtl => const {'ar', 'fa', 'ur'}.contains(_locale.languageCode);
  double get textScale => _textScale;
  bool get reduceMotion => _reduceMotion;
  bool get notificationAlarmSoundEnabled => _notificationAlarmSoundEnabled;
  int get archiveIngestionDelaySeconds => _archiveIngestionDelaySeconds;
  bool get hideProcessingFromPublic => _hideProcessingFromPublic;
  List<int> get favoriteIds => _favoriteIds;
  String? get favoriteSyncError => _favoriteSyncError;

  SettingsProvider() {
    _activeUserId = _supabase.auth.currentUser?.id;
    _loadSettings();
    appBrandingReady = _loadAppBranding();
    _loadFavorites(_activeUserId);
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final userId = data.session?.user.id;
      if (_activeUserId == userId) return;
      _activeUserId = userId;
      _favoriteIds = [];
      _favoriteSyncError = null;
      notifyListeners();
      _loadFavorites(userId);
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('theme_mode');
    final isDark = prefs.getBool('is_dark') ?? false;
    final lang = prefs.getString('language') ?? 'ar';
    _textScale = (prefs.getDouble('text_scale') ?? 1.0).clamp(0.85, 1.3);
    _reduceMotion = prefs.getBool('reduce_motion') ?? false;
    _notificationAlarmSoundEnabled =
        prefs.getBool('notification_alarm_sound') ?? true;
    _archiveIngestionDelaySeconds =
        prefs.getInt('archive_ingestion_delay_seconds') ?? 120;
    _hideProcessingFromPublic =
        prefs.getBool('hide_processing_from_public') ?? false;

    _themeMode = theme == 'system'
        ? ThemeMode.system
        : (theme == 'dark' || isDark ? ThemeMode.dark : ThemeMode.light);
    _locale = AppLocales.codes.contains(lang)
        ? Locale(lang)
        : const Locale('ar');
    _applyWebBranding();
    notifyListeners();
  }

  Future<void> _loadAppBranding() async {
    try {
      final row = await _supabase
          .from('app_branding')
          .select('app_name_ar, app_name_en, logo_url')
          .eq('id', 1)
          .maybeSingle();
      if (row != null) {
        _appNameAr = _validatedBrandName(
          row['app_name_ar']?.toString(),
          'الأثير للنشر والتوزيع',
        );
        _appNameEn = _validatedBrandName(
          row['app_name_en']?.toString(),
          'Al-Atheer Islamic Library & Digital Media',
        );
        _appLogoUrl = row['logo_url']?.toString();
      }
      _appBrandingError = null;
    } catch (error, stackTrace) {
      _appBrandingError =
          'Could not load app branding. Run supabase/app_branding_setup.sql. '
          '($error)';
      debugPrint(_appBrandingError);
      debugPrintStack(stackTrace: stackTrace);
    }
    _applyWebBranding();
    notifyListeners();
  }

  String _validatedBrandName(String? value, String fallback) {
    final name = value?.trim();
    return name == null || name.isEmpty ? fallback : name;
  }

  Future<String> uploadAppLogo(Uint8List bytes, String fileName) async {
    if (bytes.isEmpty || bytes.length > _maxAppLogoBytes) {
      throw ArgumentError('The app logo must be between 1 byte and 5 MB.');
    }

    final extension = fileName.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => throw ArgumentError('Choose a PNG, JPEG, or WebP image.'),
    };
    final path =
        'logo_${DateTime.now().toUtc().microsecondsSinceEpoch}.$extension';
    await _supabase.storage
        .from(_appBrandingBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            contentType: contentType,
          ),
        );
    return _supabase.storage.from(_appBrandingBucket).getPublicUrl(path);
  }

  Future<void> saveAppBranding({
    required String appNameAr,
    required String appNameEn,
    String? logoUrl,
  }) async {
    final arabicName = appNameAr.trim();
    final englishName = appNameEn.trim();
    if (arabicName.isEmpty || englishName.isEmpty) {
      throw ArgumentError('Enter an app name in both languages.');
    }
    if (arabicName.length > 60 || englishName.length > 60) {
      throw ArgumentError('App names must be 60 characters or fewer.');
    }

    await _supabase.from('app_branding').upsert({
      'id': 1,
      'app_name_ar': arabicName,
      'app_name_en': englishName,
      'logo_url': logoUrl,
      'updated_by': _supabase.auth.currentUser?.id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    _appNameAr = arabicName;
    _appNameEn = englishName;
    _appLogoUrl = logoUrl;
    _appBrandingError = null;
    _applyWebBranding();
    notifyListeners();
  }

  void _applyWebBranding() {
    WebBrandingClient.apply(appName, _appLogoUrl);
  }

  String _favoriteStorageKey(String? userId) => userId == null
      ? _guestFavoriteIdsKey
      : '$_userFavoriteIdsKeyPrefix$userId';

  String _favoriteCloudInitializedKey(String userId) =>
      'favorite_resource_cloud_initialized_$userId';

  String _pendingFavoriteSyncKey(String userId) =>
      'favorite_pending_sync_user_$userId';

  List<int> _parseFavoriteIds(List<String>? storedIds) => (storedIds ?? [])
      .map(int.tryParse)
      .whereType<int>()
      .where((id) => id > 0)
      .toSet()
      .toList();

  String _favoriteSyncFailure(Object error) {
    final details = error is PostgrestException
        ? '${error.message}${error.code == null ? '' : ' (code ${error.code})'}'
        : error.toString();
    return 'Favorites are saved on this device, but account sync failed: '
        '$details. Rerun the updated supabase_favorites_setup.sql script.';
  }

  Future<void> _loadFavorites(String? userId) async {
    final revision = ++_favoriteLoadRevision;
    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = _favoriteStorageKey(userId);
      var localFavorites = _parseFavoriteIds(prefs.getStringList(storageKey));
      if (!prefs.containsKey(storageKey) &&
          prefs.containsKey(_legacyFavoriteIdsKey)) {
        localFavorites = _parseFavoriteIds(
          prefs.getStringList(_legacyFavoriteIdsKey),
        );
        await prefs.setStringList(
          storageKey,
          localFavorites.map((id) => id.toString()).toList(),
        );
        await prefs.remove(_legacyFavoriteIdsKey);
      }

      if (revision != _favoriteLoadRevision || _activeUserId != userId) return;
      _favoriteIds = localFavorites;
      notifyListeners();

      if (userId == null) return;

      final pendingForUser = _favoriteMutations.putIfAbsent(userId, () => {});
      for (final value
          in prefs.getStringList(_pendingFavoriteSyncKey(userId)) ??
              const <String>[]) {
        final parts = value.split(':');
        if (parts.length != 2) continue;
        final id = int.tryParse(parts[0]);
        final isFavorite = bool.tryParse(parts[1]);
        if (id != null && id > 0 && isFavorite != null) {
          pendingForUser.putIfAbsent(id, () => isFavorite);
        }
      }

      final response = await _supabase
          .from('resource_favorites')
          .select('resource_id')
          .eq('user_id', userId);
      if (revision != _favoriteLoadRevision || _activeUserId != userId) return;

      final cloudFavorites = response
          .map((row) => row['resource_id'])
          .whereType<num>()
          .map((id) => id.toInt())
          .where((id) => id > 0)
          .toSet();
      final pendingMutations = Map<int, bool>.from(pendingForUser);
      if (!(prefs.getBool(_favoriteCloudInitializedKey(userId)) ?? false) &&
          cloudFavorites.isEmpty &&
          (localFavorites.isNotEmpty || pendingMutations.isNotEmpty)) {
        final favoritesToSeed = localFavorites.toSet();
        for (final mutation in pendingMutations.entries) {
          if (mutation.value) {
            favoritesToSeed.add(mutation.key);
          } else {
            favoritesToSeed.remove(mutation.key);
          }
        }
        for (final id in favoritesToSeed) {
          await _supabase.from('resource_favorites').upsert({
            'user_id': userId,
            'resource_id': id,
          }, onConflict: 'user_id,resource_id');
        }
        cloudFavorites.addAll(favoritesToSeed);
      }
      for (final mutation in pendingMutations.entries) {
        if (mutation.value) {
          cloudFavorites.add(mutation.key);
        } else {
          cloudFavorites.remove(mutation.key);
        }
      }

      _favoriteIds = cloudFavorites.toList()..sort();
      _favoriteSyncError = null;
      await prefs.setBool(_favoriteCloudInitializedKey(userId), true);
      _persistFavoriteIds(userId, _favoriteIds);
      notifyListeners();
      for (final mutation in pendingMutations.entries) {
        _queueRemoteFavoriteWrite(userId, mutation.key, mutation.value);
      }
    } catch (error, stackTrace) {
      debugPrint('Could not sync favorites for account: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (revision == _favoriteLoadRevision && _activeUserId == userId) {
        _favoriteSyncError = _favoriteSyncFailure(error);
        notifyListeners();
      }
    }
  }

  Future<void> _queueLocalWrite(
    Future<void> Function(SharedPreferences prefs) write,
  ) {
    final queuedWrite = _localFavoriteWrites.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await write(prefs);
    });
    _localFavoriteWrites = queuedWrite.catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      debugPrint('Could not save favorites on this device: $error');
      debugPrintStack(stackTrace: stackTrace);
    });
    return _localFavoriteWrites;
  }

  Future<void> _persistFavoriteIds(String? userId, List<int> favorites) {
    final ids = favorites.map((id) => id.toString()).toList();
    final pending = userId == null
        ? null
        : _favoriteMutations[userId]?.entries
              .map((entry) => '${entry.key}:${entry.value}')
              .toList();
    return _queueLocalWrite((prefs) async {
      await prefs.setStringList(_favoriteStorageKey(userId), ids);
      if (userId != null) {
        final key = _pendingFavoriteSyncKey(userId);
        if (pending == null || pending.isEmpty) {
          await prefs.remove(key);
        } else {
          await prefs.setStringList(key, pending);
        }
      }
    });
  }

  Future<void> _persistPendingFavoriteMutations(String userId) {
    final pending = _favoriteMutations[userId]?.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .toList();
    return _queueLocalWrite((prefs) async {
      final key = _pendingFavoriteSyncKey(userId);
      if (pending == null || pending.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setStringList(key, pending);
      }
    });
  }

  void _queueRemoteFavoriteWrite(String userId, int resourceId, bool favorite) {
    _remoteFavoriteWrites = _remoteFavoriteWrites.then((_) async {
      try {
        if (favorite) {
          await _supabase.from('resource_favorites').upsert({
            'user_id': userId,
            'resource_id': resourceId,
          }, onConflict: 'user_id,resource_id');
        } else {
          await _supabase
              .from('resource_favorites')
              .delete()
              .eq('user_id', userId)
              .eq('resource_id', resourceId);
        }
        if (_favoriteMutations[userId]?[resourceId] == favorite) {
          _favoriteMutations[userId]?.remove(resourceId);
          await _persistPendingFavoriteMutations(userId);
        }
        if (_activeUserId == userId &&
            _favoriteMutations[userId]?.isEmpty != false &&
            _favoriteSyncError != null) {
          _favoriteSyncError = null;
          notifyListeners();
        }
      } catch (error, stackTrace) {
        debugPrint('Could not sync favorite to account: $error');
        debugPrintStack(stackTrace: stackTrace);
        if (_activeUserId == userId) {
          _favoriteSyncError = _favoriteSyncFailure(error);
          notifyListeners();
        }
      }
    });
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
    _applyWebBranding();
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

  Future<void> setNotificationAlarmSoundEnabled(bool enabled) async {
    _notificationAlarmSoundEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_alarm_sound', enabled);
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

  void retryFavoriteSync() {
    final userId = _activeUserId;
    if (userId != null) _loadFavorites(userId);
  }

  Future<void> toggleFavorite(int id) async {
    if (id <= 0) return;
    final userId = _activeUserId;
    final favorite = !_favoriteIds.contains(id);
    if (favorite) {
      _favoriteIds.add(id);
    } else {
      _favoriteIds.remove(id);
    }
    if (userId != null) {
      _favoriteMutations.putIfAbsent(userId, () => {})[id] = favorite;
    }
    notifyListeners();
    final localWrite = _persistFavoriteIds(userId, _favoriteIds);
    if (userId != null) _queueRemoteFavoriteWrite(userId, id, favorite);
    await localWrite;
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
