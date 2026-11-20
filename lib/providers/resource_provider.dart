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
  String? _selectedCategory;
  String _selectedType =
      'all'; // 'all', 'audio', 'video', 'pdf', 'text', 'favorites'
  String _searchQuery = '';
  String? _selectedSubfolder;

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
  String? get selectedCategory => _selectedCategory;
  String? get selectedSubfolder => _selectedSubfolder;
  String get selectedType => _selectedType;
  String get searchQuery => _searchQuery;

  List<String> _categories = [];
  List<String> get categories => _categories;
  Map<String, List<String>> _subfoldersByCategory = {};

  List<String> subfoldersForCategory(String category) =>
      _subfoldersByCategory[category] ?? const [];

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
      final response = await _supabase
          .from('categories')
          .select('name, subfolders')
          .order('sort_order', ascending: true)
          .order('name', ascending: true);
      final List<dynamic> dataList = response as List<dynamic>;
      _categories = [];
      _subfoldersByCategory = {};
      for (final category in dataList) {
        final name = category['name']?.toString() ?? '';
        if (name.isEmpty) continue;
        _categories.add(name);
        final rawSubfolders = category['subfolders'];
        _subfoldersByCategory[name] = rawSubfolders is List
            ? rawSubfolders
                  .map((subfolder) => subfolder.toString())
                  .where((subfolder) => subfolder.isNotEmpty)
                  .toList()
            : [];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      _categories = [];
      _subfoldersByCategory = {};
      notifyListeners();
    }
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    final categories = List<String>.of(_categories);
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex < 0 ||
        oldIndex >= categories.length ||
        newIndex < 0 ||
        newIndex >= categories.length ||
        oldIndex == newIndex) {
      return;
    }

    final category = categories.removeAt(oldIndex);
    categories.insert(newIndex, category);
    _categories = categories;
    notifyListeners();
    try {
      await _persistSortOrder('categories', 'name', categories);
    } catch (error) {
      await fetchCategories();
      rethrow;
    }
  }

  Future<void> reorderPlaylists(int oldIndex, int newIndex) async {
    final playlists = List<PlaylistModel>.of(_playlists);
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex < 0 ||
        oldIndex >= playlists.length ||
        newIndex < 0 ||
        newIndex >= playlists.length ||
        oldIndex == newIndex) {
      return;
    }

    final playlist = playlists.removeAt(oldIndex);
    playlists.insert(newIndex, playlist);
    _playlists = playlists;
    notifyListeners();
    try {
      await _persistSortOrder(
        'playlists',
        'id',
        playlists.map((playlist) => playlist.id).toList(),
      );
    } catch (error) {
      await fetchPlaylists();
      rethrow;
    }
  }

  Future<void> reorderResources(List<int> resourceIds) async {
    try {
      await _persistSortOrder('resources', 'id', resourceIds);
      await fetchResources();
    } catch (error) {
      await fetchResources();
      rethrow;
    }
  }

  Future<void> _persistSortOrder(
    String table,
    String idColumn,
    List<Object> ids,
  ) async {
    const batchSize = 20;
    for (var start = 0; start < ids.length; start += batchSize) {
      final end = start + batchSize < ids.length
          ? start + batchSize
          : ids.length;
      await Future.wait([
        for (var index = start; index < end; index++)
          _supabase
              .from(table)
              .update({'sort_order': index})
              .eq(idColumn, ids[index]),
      ]);
    }
  }

  void setTypeFilter(String type) {
    _selectedType = type;
    notifyListeners();
    if (type != 'favorites') {
      fetchResources();
    }
  }

  void setCategoryFilter(String? category) {
    _selectedCategory = category;
    _selectedSubfolder = null;
    fetchResources();
  }

  void setSubfolderFilter(String category, String subfolder) {
    _selectedCategory = category;
    _selectedSubfolder = subfolder;
    fetchResources();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    fetchResources();
  }

  void resetResourceFilters() {
    _selectedCategory = null;
    _selectedSubfolder = null;
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

      final selectedCategory = _selectedCategory;
      if (selectedCategory != null) {
        queryBuilder = queryBuilder.eq('category', selectedCategory);
      }
      final selectedSubfolder = _selectedSubfolder;
      if (selectedSubfolder != null) {
        queryBuilder = queryBuilder.eq('subfolder', selectedSubfolder);
      }

      if (_searchQuery.trim().isNotEmpty) {
        queryBuilder = queryBuilder.ilike('title', '%${_searchQuery.trim()}%');
      }

      final data = await queryBuilder
          .order('sort_order')
          .order('created_at', ascending: false);

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

  Future<void> addSubfolder(String category, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Subfolder name cannot be empty.');
    }

    final subfolders = List<String>.of(subfoldersForCategory(category));
    if (subfolders.contains(trimmedName)) {
      throw StateError('A subfolder with this name already exists.');
    }
    subfolders.add(trimmedName);
    await _supabase
        .from('categories')
        .update({'subfolders': subfolders})
        .eq('name', category)
        .select('name')
        .single();
    await fetchCategories();
  }

  Future<void> deleteSubfolder(String category, String name) async {
    final subfolders = List<String>.of(subfoldersForCategory(category));
    if (!subfolders.remove(name)) return;

    await _supabase.rpc(
      'delete_category_subfolder',
      params: {'p_category_name': category, 'p_subfolder_name': name},
    );
    await Future.wait([fetchCategories(), fetchResources()]);
  }

  Future<void> renameSubfolder(
    String category,
    String oldName,
    String newName,
  ) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Subfolder name cannot be empty.');
    }

    final subfolders = subfoldersForCategory(category);
    if (trimmedName != oldName && subfolders.contains(trimmedName)) {
      throw StateError('A subfolder with this name already exists.');
    }

    await _supabase.rpc(
      'rename_category_subfolder',
      params: {
        'p_category_name': category,
        'p_old_subfolder_name': oldName,
        'p_new_subfolder_name': trimmedName,
      },
    );
    await Future.wait([fetchCategories(), fetchResources()]);
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
          .select(
            'id, title, description, cover_image_url, created_at, sort_order',
          )
          .order('sort_order')
          .order('created_at');
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
    Set<int> existingIds = {};
    var nextSortOrder = 0;
    if (id == null) {
      final currentRows = await _supabase
          .from('playlists')
          .select('id, sort_order');
      existingIds = (currentRows as List)
          .map((row) => (row['id'] as num).toInt())
          .toSet();
      nextSortOrder =
          (currentRows as List).fold<int>(-1, (maximum, row) {
            final order = (row['sort_order'] as num).toInt();
            return order > maximum ? order : maximum;
          }) +
          1;
    }

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
    if (id == null) {
      final rows = await _supabase
          .from('playlists')
          .select('id')
          .order('created_at', ascending: false);
      final newRows = (rows as List)
          .where((row) => !existingIds.contains((row['id'] as num).toInt()))
          .toList();
      if (newRows.isNotEmpty) {
        final newId = (newRows.first['id'] as num).toInt();
        await _supabase
            .from('playlists')
            .update({'sort_order': nextSortOrder})
            .eq('id', newId);
      }
    }
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
