import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/resource_model.dart';
import '../providers/auth_provider.dart';
import '../providers/resource_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/daily_wisdom_card.dart';
import '../widgets/featured_hero_card.dart';
import '../widgets/islamic_header_widget.dart';
import '../widgets/library_stats_bar.dart';
import '../widgets/pdf_viewer_widget.dart';
import '../widgets/text_quote_widget.dart';
import '../widgets/video_player_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isFavoritesOnly = false;

  final List<Map<String, dynamic>> _tabs = [
    {'title': 'الكل', 'type': 'all', 'icon': Icons.grid_view_rounded},
    {'title': 'كتب PDF', 'type': 'pdf', 'icon': Icons.menu_book_rounded},
    {'title': 'صوتيات', 'type': 'audio', 'icon': Icons.audiotrack_rounded},
    {'title': 'مرئيات', 'type': 'video', 'icon': Icons.videocam_rounded},
    {'title': 'درر وفوائد', 'type': 'text', 'icon': Icons.format_quote_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _isFavoritesOnly = false);
        final resProvider = Provider.of<ResourceProvider>(
          context,
          listen: false,
        );
        resProvider.setTypeFilter(_tabs[_tabController.index]['type']);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSelectStatType(String type) {
    setState(() => _isFavoritesOnly = false);
    final index = _tabs.indexWhere((t) => t['type'] == type);
    if (index != -1) {
      _tabController.animateTo(index);
    }
  }

  void _toggleFavorites() {
    setState(() {
      _isFavoritesOnly = !_isFavoritesOnly;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final resourceProv = Provider.of<ResourceProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const radiantGold = Color(0xFFF59E0B);
    const deepNavy = Color(0xFF0F172A);

    // Compute display items based on filters and favorites
    List<ResourceModel> displayList = resourceProv.resources;

    if (_isFavoritesOnly) {
      displayList = displayList
          .where((r) => settings.favoriteIds.contains(r.id))
          .toList();
    }

    if (settings.hideProcessingFromPublic &&
        (!auth.isAuthenticated || !auth.isAdmin)) {
      displayList = displayList
          .where(
            (r) => resourceProv.isResourceReady(
              r,
              delaySeconds: settings.archiveIngestionDelaySeconds,
            ),
          )
          .toList();
    }

    final featuredItem = displayList.isNotEmpty ? displayList.first : null;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Islamic Brand & Hijri Header
            SliverToBoxAdapter(
              child: IslamicHeaderWidget(
                isFavoritesSelected: _isFavoritesOnly,
                onToggleFavorites: _toggleFavorites,
                onOpenAdmin: () async {
                  await Navigator.pushNamed(context, '/admin');
                  if (context.mounted) {
                    resourceProv.fetchCategories();
                    resourceProv.fetchResources();
                  }
                },
                onOpenSettings: () => Navigator.pushNamed(context, '/settings'),
              ),
            ),

            // Daily Wisdom Inspiring Card
            const SliverToBoxAdapter(child: DailyWisdomCard()),

            // Search Bar & Horizontal Category Filter
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Search Field
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText:
                            'ابحث في الكتب، الدروس، التفاسير، والفوائد...',
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: radiantGold,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  resourceProv.setSearchQuery('');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: radiantGold.withValues(alpha: 0.3),
                          ),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF7F5EE),
                      ),
                      onChanged: (val) {
                        setState(() {});
                        resourceProv.setSearchQuery(val);
                      },
                    ),
                    const SizedBox(height: 10),

                    // Category Pill Bar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: resourceProv.categories.map((cat) {
                          final isSelected =
                              resourceProv.selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              onSelected: (_) =>
                                  resourceProv.setCategoryFilter(cat),
                              selectedColor: deepNavy,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? radiantGold
                                    : (isDark
                                          ? Colors.grey.shade300
                                          : Colors.black87),
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? radiantGold
                                    : (isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade300),
                                width: isSelected ? 1.4 : 1,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Library Stats Bar with Ingestion Alert
            SliverToBoxAdapter(
              child: LibraryStatsBar(onSelectType: _onSelectStatType),
            ),

            // Featured Hero Highlight (only when not searching or filtering by favorites)
            if (featuredItem != null &&
                resourceProv.searchQuery.isEmpty &&
                !_isFavoritesOnly &&
                resourceProv.selectedCategory == 'All' &&
                resourceProv.selectedType == 'all')
              SliverToBoxAdapter(
                child: FeaturedHeroCard(resource: featuredItem),
              ),

            // Persistent Tabs bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabHeaderDelegate(
                child: Container(
                  color: isDark ? const Color(0xFF060D1A) : deepNavy,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: radiantGold,
                    indicatorWeight: 3,
                    labelColor: radiantGold,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    tabs: _tabs.map((t) {
                      return Tab(
                        child: Row(
                          children: [
                            Icon(t['icon'] as IconData, size: 16),
                            const SizedBox(width: 6),
                            Text(t['title'] as String),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ];
        },
        body: resourceProv.isLoading
            ? const Center(child: CircularProgressIndicator(color: radiantGold))
            : displayList.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: deepNavy.withValues(alpha: 0.1),
                          border: Border.all(
                            color: radiantGold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          _isFavoritesOnly
                              ? Icons.star_border
                              : Icons.auto_stories_outlined,
                          size: 56,
                          color: radiantGold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isFavoritesOnly
                            ? 'قائمة المفضلة فارغة'
                            : 'لا توجد إصدارات مطابقة للبحث',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isFavoritesOnly
                            ? 'اضغط على زر النجمة في أي بطاقة لإضافتها للمفضلة.'
                            : (resourceProv.searchQuery.isNotEmpty
                                  ? 'جرب البحث بكلمات أخرى أو اختر تصنيفاً مختلفاً'
                                  : 'اختر تصنيفاً آخر أو قم بتحديث القائمة'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: radiantGold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.refresh, color: radiantGold),
                        label: const Text(
                          'إعادة ضبط الفلاتر',
                          style: TextStyle(color: radiantGold),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _isFavoritesOnly = false);
                          resourceProv.setSearchQuery('');
                          resourceProv.setCategoryFilter('All');
                          _tabController.animateTo(0);
                        },
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                color: radiantGold,
                onRefresh: () async {
                  await resourceProv.fetchCategories();
                  await resourceProv.fetchResources();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final item = displayList[index];
                    switch (item.type) {
                      case 'audio':
                        return AudioPlayerWidget(resource: item);
                      case 'video':
                        return VideoPlayerWidget(resource: item);
                      case 'pdf':
                        return PdfViewerWidget(resource: item);
                      case 'text':
                      default:
                        return TextQuoteWidget(resource: item);
                    }
                  },
                ),
              ),
      ),
      floatingActionButton: (auth.isAuthenticated && auth.isAdmin)
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.pushNamed(context, '/admin');
                if (context.mounted) {
                  resourceProv.fetchCategories();
                  resourceProv.fetchResources();
                }
              },
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('نشر مادة جديدة'),
            )
          : null,
    );
  }
}

class _SliverTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverTabHeaderDelegate({required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant _SliverTabHeaderDelegate oldDelegate) {
    return false;
  }
}
