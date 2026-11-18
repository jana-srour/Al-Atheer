import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/playlist_model.dart';
import '../models/resource_model.dart';
import '../services/archive_upload_service.dart';

class ResourceProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<ResourceModel> _resources = [];
  List<PlaylistModel> _playlists = [];
  List<Map<String, String>> _curatedQuotes = [];
  Set<int> _dailyQuoteIds = {};
  Map<DateTime, int> _dailyQuoteSchedule = {};
  String? _curatedQuotesError;
  String? _dailyQuoteSelectionError;
  String? _dailyQuoteScheduleError;
  String? _playlistsError;
  bool _isLoadingPlaylists = false;
  bool _isLoadingDailyQuoteSelection = false;
  bool _isLoadingDailyQuoteSchedule = false;
  bool _isLoading = false;
  String _selectedCategory = 'All';
  String _selectedType =
      'all'; // 'all', 'audio', 'video', 'pdf', 'text', 'favorites'
  String _searchQuery = '';

  // Cache of URLs that have been verified ready via HTTP check
  final Set<String> _readyUrlCache = {};

  // Ticker timer for live second-by-second countdowns on processing items
  Timer? _tickerTimer;

  List<ResourceModel> get resources => _resources;
  List<PlaylistModel> get playlists => _playlists;
  List<Map<String, String>> get curatedQuotes => _curatedQuotes;
  Set<int> get dailyQuoteIds => Set.unmodifiable(_dailyQuoteIds);
  Map<DateTime, int> get dailyQuoteSchedule =>
      Map.unmodifiable(_dailyQuoteSchedule);
  List<Map<String, String>> get dailyQuotes => _curatedQuotes
      .where(
        (quote) => _dailyQuoteIds.contains(int.tryParse(quote['id'] ?? '')),
      )
      .toList(growable: false);
  String? get curatedQuotesError => _curatedQuotesError;
  String? get dailyQuoteSelectionError => _dailyQuoteSelectionError;
  String? get dailyQuoteScheduleError => _dailyQuoteScheduleError;
  bool get isLoadingDailyQuoteSelection => _isLoadingDailyQuoteSelection;
  bool get isLoadingDailyQuoteSchedule => _isLoadingDailyQuoteSchedule;
  String? get playlistsError => _playlistsError;
  bool get isLoadingPlaylists => _isLoadingPlaylists;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;
  String get selectedType => _selectedType;
  String get searchQuery => _searchQuery;

  List<String> _categories = ['All'];
  List<String> get categories => _categories;

  ResourceProvider() {
    fetchCategories();
    fetchResources();
    fetchPlaylists();
    fetchCuratedQuotes();
    fetchDailyQuoteSelection();
    fetchDailyQuoteSchedule();
    _startTickerIfNeeded();
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  void _startTickerIfNeeded() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final hasProcessing = _resources.any(
        (r) => r.isProcessing() && !_readyUrlCache.contains(r.archiveUrl),
      );
      if (hasProcessing) {
        notifyListeners();
      }
    });
  }

  /// Whether a specific resource is confirmed ready (either passed timer or verified live)
  bool isResourceReady(ResourceModel resource, {int delaySeconds = 120}) {
    if (resource.type == 'text' || resource.archiveUrl == null) return true;
    if (_readyUrlCache.contains(resource.archiveUrl)) return true;
    return !resource.isProcessing(delaySeconds: delaySeconds);
  }

  /// Actively tests Archive.org via HTTP HEAD/GET to check if ingestion is finished early
  Future<bool> probeResourceReadiness(ResourceModel resource) async {
    if (resource.archiveUrl == null) return true;
    final isReady = await ArchiveUploadService.checkResourceReadiness(
      resource.archiveUrl!,
    );
    if (isReady) {
      _readyUrlCache.add(resource.archiveUrl!);
      notifyListeners();
    }
    return isReady;
  }

  /// Resources that are currently in the Archive.org countdown window
  List<ResourceModel> get processingResources {
    return _resources
        .where(
          (r) => r.isProcessing() && !_readyUrlCache.contains(r.archiveUrl),
        )
        .toList();
  }

  /// Total count for specific media types
  int countByType(String type) {
    if (type == 'all') return _resources.length;
    return _resources.where((r) => r.type == type).length;
  }

  Future<void> fetchCategories() async {
    try {
      final response = await _supabase.from('categories').select('name');
      final List<dynamic> dataList = response as List<dynamic>;
      _categories = [
        'All',
        ...dataList
            .map((c) => c['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty),
      ];
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      if (_categories.isEmpty) {
        _categories = ['All', 'Fiqh', 'Aqeedah', 'Tafseer', 'General'];
      }
    }
  }

  void setTypeFilter(String type) {
    _selectedType = type;
    notifyListeners();
    if (type != 'favorites') {
      fetchResources();
    }
  }

  void setCategoryFilter(String category) {
    _selectedCategory = category;
    fetchResources();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    fetchResources();
  }

  void resetResourceFilters() {
    _selectedCategory = 'All';
    _selectedType = 'all';
    _searchQuery = '';
    fetchResources();
  }

  Future<void> fetchResources() async {
    _isLoading = true;
    notifyListeners();

    try {
      var queryBuilder = _supabase.from('resources').select('*');

      if (_selectedType != 'all' && _selectedType != 'favorites') {
        queryBuilder = queryBuilder.eq('type', _selectedType);
      }

      if (_selectedCategory != 'All') {
        queryBuilder = queryBuilder.eq('category', _selectedCategory);
      }

      if (_searchQuery.trim().isNotEmpty) {
        queryBuilder = queryBuilder.ilike('title', '%${_searchQuery.trim()}%');
      }

      final data = await queryBuilder.order('created_at', ascending: false);

      _resources = (data as List)
          .map((e) => ResourceModel.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Error fetching resources: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addResource(ResourceModel resource) async {
    try {
      await _supabase.from('resources').insert(resource.toJson());
      await fetchResources();
      return true;
    } catch (e) {
      debugPrint('Error adding resource: $e');
      return false;
    }
  }

  Future<bool> deleteResource(int id) async {
    try {
      await _supabase.from('resources').delete().eq('id', id);
      await fetchResources();
      return true;
    } catch (e) {
      debugPrint('Error deleting resource: $e');
      return false;
    }
  }

  Future<void> fetchPlaylists() async {
    _isLoadingPlaylists = true;
    notifyListeners();
    try {
      final playlistRows = await _supabase
          .from('playlists')
          .select('id, title, description, cover_image_url, created_at')
          .order('created_at', ascending: false);
      final rows = playlistRows as List;

      if (rows.isEmpty) {
        _playlists = [];
      } else {
        final ids = rows.map((row) => row['id'] as int).toList();
        final itemRows = await _supabase
            .from('playlist_items')
            .select('playlist_id, sort_order, resource:resources(*)')
            .inFilter('playlist_id', ids)
            .order('sort_order');
        final resourcesByPlaylist = <int, List<ResourceModel>>{};

        for (final item in itemRows as List) {
          final resourceJson = item['resource'];
          if (resourceJson is! Map<String, dynamic>) continue;
          final playlistId = item['playlist_id'] as int;
          resourcesByPlaylist
              .putIfAbsent(playlistId, () => [])
              .add(ResourceModel.fromJson(resourceJson));
        }

        _playlists = rows
            .map(
              (row) => PlaylistModel.fromJson(
                row,
                resources: resourcesByPlaylist[row['id'] as int] ?? const [],
              ),
            )
            .toList();
      }
      _playlistsError = null;
    } catch (error) {
      _playlistsError = error.toString();
      debugPrint('Error fetching playlists: $error');
    } finally {
      _isLoadingPlaylists = false;
      notifyListeners();
    }
  }

  Future<void> savePlaylist({
    int? id,
    required String title,
    required String description,
    required List<int> resourceIds,
    String? coverImageUrl,
  }) async {
    await _supabase.rpc(
      'save_playlist_with_resources_and_cover',
      params: {
        'p_playlist_id': id,
        'p_title': title,
        'p_description': description,
        'p_resource_ids': resourceIds,
        'p_cover_image_url': coverImageUrl,
      },
    );
    await fetchPlaylists();
  }

  Future<void> deletePlaylist(int id) async {
    await _supabase.from('playlists').delete().eq('id', id);
    await fetchPlaylists();
  }

  Future<void> fetchCuratedQuotes() async {
    try {
      final rows = await _supabase
          .from('curated_quotes')
          .select('id, title, quote, source')
          .order('created_at', ascending: false);
      _curatedQuotes = (rows as List)
          .map(
            (row) => {
              'id': row['id'].toString(),
              'title': row['title']?.toString() ?? '',
              'quote': row['quote']?.toString() ?? '',
              'source': row['source']?.toString() ?? '',
            },
          )
          .toList();
      _curatedQuotesError = null;
    } catch (error) {
      _curatedQuotesError = error.toString();
      debugPrint('Error fetching curated quotes: $error');
    } finally {
      notifyListeners();
    }
  }

  Future<void> fetchDailyQuoteSelection() async {
    _isLoadingDailyQuoteSelection = true;
    _dailyQuoteSelectionError = null;
    notifyListeners();
    try {
      final rows = await _supabase
          .from('daily_quote_selections')
          .select('quote_id');
      _dailyQuoteIds = (rows as List)
          .map((row) => row['quote_id'])
          .whereType<num>()
          .map((id) => id.toInt())
          .toSet();
    } catch (error) {
      _dailyQuoteSelectionError = error.toString();
      debugPrint('Error fetching daily quote selection: $error');
    } finally {
      _isLoadingDailyQuoteSelection = false;
      notifyListeners();
    }
  }

  Future<void> setDailyQuoteSelection(Set<int> quoteIds) async {
    final selectedIds = quoteIds.toList()..sort();
    await _supabase.rpc(
      'set_daily_quote_selection',
      params: {'p_quote_ids': selectedIds},
    );
    _dailyQuoteIds = selectedIds.toSet();
    _dailyQuoteSelectionError = null;
    notifyListeners();
  }

  Future<void> fetchDailyQuoteSchedule() async {
    _isLoadingDailyQuoteSchedule = true;
    _dailyQuoteScheduleError = null;
    notifyListeners();
    try {
      final rows = await _supabase
          .from('daily_quote_schedule')
          .select('schedule_date, quote_id')
          .order('schedule_date');
      _dailyQuoteSchedule = {
        for (final row in rows as List)
          _dateOnly(row['schedule_date']): (row['quote_id'] as num).toInt(),
      };
    } catch (error) {
      _dailyQuoteScheduleError = error.toString();
      debugPrint('Error fetching daily quote schedule: $error');
    } finally {
      _isLoadingDailyQuoteSchedule = false;
      notifyListeners();
    }
  }

  Future<void> setDailyQuoteSchedule({
    required DateTime date,
    required int? quoteId,
  }) async {
    final normalizedDate = DateTime.utc(date.year, date.month, date.day);
    await _supabase.rpc(
      'set_daily_quote_schedule',
      params: {
        'p_schedule_date': normalizedDate.toIso8601String().substring(0, 10),
        'p_quote_id': quoteId,
      },
    );
    if (quoteId == null) {
      _dailyQuoteSchedule.remove(normalizedDate);
    } else {
      _dailyQuoteSchedule[normalizedDate] = quoteId;
    }
    _dailyQuoteScheduleError = null;
    notifyListeners();
  }

  DateTime _dateOnly(Object? value) {
    final parsed = DateTime.parse(value.toString());
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }

  Future<void> addCuratedQuote({
    required String title,
    required String quote,
    required String source,
  }) async {
    await _supabase.from('curated_quotes').insert({
      'title': title,
      'quote': quote,
      'source': source,
    });
    await fetchCuratedQuotes();
  }

  Future<void> deleteCuratedQuote({required int id}) async {
    await _supabase.from('curated_quotes').delete().eq('id', id);
    await Future.wait([
      fetchCuratedQuotes(),
      fetchDailyQuoteSelection(),
      fetchDailyQuoteSchedule(),
    ]);
  }
}
