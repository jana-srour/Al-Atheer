import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/resource_model.dart';
import '../services/archive_upload_service.dart';

class ResourceProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<ResourceModel> _resources = [];
  bool _isLoading = false;
  String _selectedCategory = 'All';
  String _selectedType = 'all'; // 'all', 'audio', 'video', 'pdf', 'text', 'favorites'
  String _searchQuery = '';

  // Cache of URLs that have been verified ready via HTTP check
  final Set<String> _readyUrlCache = {};

  // Ticker timer for live second-by-second countdowns on processing items
  Timer? _tickerTimer;

  List<ResourceModel> get resources => _resources;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;
  String get selectedType => _selectedType;
  String get searchQuery => _searchQuery;

  List<String> _categories = ['All'];
  List<String> get categories => _categories;

  ResourceProvider() {
    fetchCategories();
    fetchResources();
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
}
