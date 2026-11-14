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
  List<Map<String, String>> _uploadedQuotes = [];
  List<Map<String, String>> _curatedQuotes = [];
  String? _curatedQuotesError;
  String? _playlistsError;
  bool _isLoadingPlaylists = false;
  bool _isLoading = false;
  String _selectedCategory = 'All';
  String _selectedType = 'all'; // 'all', 'audio', 'video', 'pdf', 'text', 'favorites'
  String _searchQuery = '';

  // Cache of URLs that have been verified ready via HTTP check
  final Set<String> _readyUrlCache = {};

  // Ticker timer for live second-by-second countdowns on processing items
  Timer? _tickerTimer;

  List<ResourceModel> get resources => _resources;
  List<PlaylistModel> get playlists => _playlists;
  List<Map<String, String>> get uploadedQuotes => _uploadedQuotes;
  List<Map<String, String>> get curatedQuotes => _curatedQuotes;
  String? get curatedQuotesError => _curatedQuotesError;
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
    fetchUploadedQuotes();
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
      final hasProcessing = _resources.any((r) => r.isProcessing() && !_readyUrlCache.contains(r.archiveUrl));
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
    final isReady = await ArchiveUploadService.checkResourceReadiness(resource.archiveUrl!);
    if (isReady) {
      _readyUrlCache.add(resource.archiveUrl!);
      notifyListeners();
    }
    return isReady;
  }

  /// Resources that are currently in the Archive.org countdown window
  List<ResourceModel> get processingResources {
    return _resources
        .where((r) => r.isProcessing() && !_readyUrlCache.contains(r.archiveUrl))
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
      await fetchUploadedQuotes();
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
          .select('id, title, description, created_at')
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
  }) async {
    await _supabase.rpc(
      'save_playlist_with_resources',
      params: {
        'p_playlist_id': id,
        'p_title': title,
        'p_description': description,
        'p_resource_ids': resourceIds,
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

  Future<void> deleteCuratedQuote({
    required int id,
  }) async {
    await _supabase.from('curated_quotes').delete().eq('id', id);
    await fetchCuratedQuotes();
  }

  Future<void> fetchUploadedQuotes() async {
    try {
      final rows = await _supabase
          .from('resources')
          .select('title, description, text_content')
          .eq('type', 'text')
          .order('created_at', ascending: false);
      _uploadedQuotes = (rows as List)
          .where((row) => (row['text_content']?.toString() ?? '').isNotEmpty)
          .map(
            (row) => {
              'title': row['title']?.toString() ?? '',
              'quote': row['text_content']?.toString() ?? '',
              'source': row['description']?.toString() ?? '',
            },
          )
          .toList();
    } catch (error) {
      debugPrint('Error fetching uploaded quotes: $error');
    } finally {
      notifyListeners();
    }
  }
}
