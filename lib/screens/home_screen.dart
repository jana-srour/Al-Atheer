import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_strings.dart';
import '../models/resource_model.dart';
import '../providers/resource_provider.dart';
import '../providers/azkar_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/daily_wisdom_card.dart';
import '../widgets/featured_hero_card.dart';
import '../widgets/image_resource_widget.dart';
import '../widgets/islamic_header_widget.dart';
import '../widgets/library_stats_bar.dart';
import '../widgets/pdf_viewer_widget.dart';
import '../widgets/post_resource_widget.dart';
import '../widgets/text_quote_widget.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/writer_home_card.dart';
import 'playlist_library_screen.dart';
import 'writer_biography_screen.dart';

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
    {'title': 'صور', 'type': 'image', 'icon': Icons.image_outlined},
    {'title': 'صوتيات', 'type': 'audio', 'icon': Icons.audiotrack_rounded},
    {'title': 'مرئيات', 'type': 'video', 'icon': Icons.videocam_rounded},
    {'title': 'درر وفوائد', 'type': 'text', 'icon': Icons.format_quote_rounded},
    {'title': 'منشورات', 'type': 'post', 'icon': Icons.post_add},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _isFavoritesOnly = false;
        });
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
    if (type == 'playlists') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PlaylistLibraryScreen()),
      );
      return;
    }

    setState(() {
      _isFavoritesOnly = false;
    });
    final index = _tabs.indexWhere((t) => t['type'] == type);
    if (index != -1) {
      _tabController.animateTo(index);
    }
  }

  void _toggleFavorites(ResourceProvider resourceProvider) {
    final showFavorites = !_isFavoritesOnly;
    setState(() {
      _isFavoritesOnly = showFavorites;
    });
    if (showFavorites) {
      _searchController.clear();
      resourceProvider.resetResourceFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final resourceProv = Provider.of<ResourceProvider>(context);
    final azkarProv = Provider.of<AzkarProvider>(context);
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

    final azkarSearch = resourceProv.searchQuery.trim().toLowerCase();
    final displayAzkar =
        _isFavoritesOnly ||
            (resourceProv.selectedType != 'all' &&
                resourceProv.selectedType != 'post')
        ? const []
        : azkarProv.azkar
              .where(
                (item) =>
                    resourceProv.selectedCategory == null ||
                    item.category == resourceProv.selectedCategory,
              )
              .where(
                (item) =>
                    azkarSearch.isEmpty ||
                    item.title.toLowerCase().contains(azkarSearch) ||
                    item.content.toLowerCase().contains(azkarSearch) ||
                    (item.description?.toLowerCase().contains(azkarSearch) ??
                        false),
              )
              .toList(growable: false);

    final featuredItem = displayList.isNotEmpty ? displayList.first : null;
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Islamic Brand & Hijri Header
            SliverToBoxAdapter(
              child: IslamicHeaderWidget(
                isFavoritesSelected: _isFavoritesOnly,
                onToggleFavorites: () => _toggleFavorites(resourceProv),
                onOpenAdmin: () async {
                  await Navigator.pushNamed(context, '/admin');
                  if (context.mounted) {
                    await Future.wait([
                      resourceProv.fetchCategories(),
                      resourceProv.fetchResources(),
                    ]);
                  }
                },
                onOpenSettings: () => Navigator.pushNamed(context, '/settings'),
                onOpenBiography: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WriterBiographyScreen(),
                  ),
                ),
                onOpenPlaylists: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PlaylistLibraryScreen(),
                  ),
                ),
              ),
            ),

            // Daily Wisdom Inspiring Card
            const SliverToBoxAdapter(child: DailyWisdomCard()),

            const SliverToBoxAdapter(child: WriterHomeCard()),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.auto_awesome_outlined),
                    ),
                    title: const Text('الأذكار المجدولة'),
                    subtitle: const Text('أذكار وأدعية وآيات مع تنبيهات'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(context, '/azkar'),
                  ),
                ),
              ),
            ),

            if (settings.favoriteSyncError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      leading: Icon(
                        Icons.cloud_off_outlined,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      title: Text(
                        settings.isArabic
                            ? 'تعذرت مزامنة المفضلة'
                            : 'Favorites sync is unavailable',
                      ),
                      subtitle: Text(settings.favoriteSyncError!),
                      trailing: IconButton(
                        tooltip: settings.isArabic
                            ? 'إعادة المحاولة'
                            : 'Retry sync',
                        onPressed: settings.retryFavoriteSync,
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                  ),
                ),
              ),

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
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          textDirection: TextDirection.rtl,
                          children:
                              resourceProv.categories.map((cat) {
                                final isSelected =
                                    resourceProv.selectedCategory == cat;
                                return Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 8,
                                  ),
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
                              }).toList()..add(
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 8,
                                  ),
                                  child: ChoiceChip(
                                    label: Text(
                                      AppStrings.of(context).text('home_all'),
                                    ),
                                    selected:
                                        resourceProv.selectedCategory == null,
                                    onSelected: (_) =>
                                        resourceProv.setCategoryFilter(null),
                                    selectedColor: deepNavy,
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                          resourceProv.selectedCategory == null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color:
                                          resourceProv.selectedCategory == null
                                          ? radiantGold
                                          : (isDark
                                                ? Colors.grey.shade300
                                                : Colors.black87),
                                    ),
                                    side: BorderSide(
                                      color:
                                          resourceProv.selectedCategory == null
                                          ? radiantGold
                                          : (isDark
                                                ? Colors.grey.shade800
                                                : Colors.grey.shade300),
                                      width:
                                          resourceProv.selectedCategory == null
                                          ? 1.4
                                          : 1,
                                    ),
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Library Stats Bar with Ingestion Alert
            SliverToBoxAdapter(child: LibraryStatsBar(showStats: false)),

            // Featured Hero Highlight (only when not searching or filtering by favorites)
            if (featuredItem != null &&
                resourceProv.searchQuery.isEmpty &&
                !_isFavoritesOnly &&
                resourceProv.selectedCategory == null &&
                resourceProv.selectedType == 'all')
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1050),
                    child: FeaturedHeroCard(resource: featuredItem),
                  ),
                ),
              ),

            // A single compact, horizontally scrolling type selector.
            SliverToBoxAdapter(
              child: _buildTypeCards(
                resourceProv,
                isDark,
                radiantGold,
                deepNavy,
                _onSelectStatType,
              ),
            ),
          ];
        },
        body: RefreshIndicator(
          color: radiantGold,
          onRefresh: () async {
            await Future.wait([
              resourceProv.fetchCategories(),
              resourceProv.fetchResources(),
              resourceProv.fetchCuratedQuotes(),
              resourceProv.fetchDailyQuoteSelection(),
              resourceProv.fetchDailyQuoteSchedule(),
              resourceProv.fetchPlaylists(),
              azkarProv.fetchAzkar(),
            ]);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
            itemCount:
                resourceProv.isLoading ||
                    (displayList.isEmpty && displayAzkar.isEmpty)
                ? 1
                : displayList.length + displayAzkar.length,
            itemBuilder: (context, index) {
              if (resourceProv.isLoading) {
                return SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.6,
                  child: const Center(
                    child: CircularProgressIndicator(color: radiantGold),
                  ),
                );
              }

              if (displayList.isEmpty && displayAzkar.isEmpty) {
                return SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.6,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                                      : 'اختر تصنيفاً آخر أو اسحب للأسفل للتحديث'),
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
                              resourceProv.setCategoryFilter(null);
                              _tabController.animateTo(0);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              if (index >= displayList.length) {
                final item = displayAzkar[index - displayList.length];
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1050),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome_outlined,
                                  color: radiantGold,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                Text(
                                  item.category,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SelectableText(
                              item.content,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20, height: 1.8),
                            ),
                            if (item.description?.isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Text(item.description!),
                            ],
                            if (item.source?.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.source!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const Divider(),
                            Text(
                              'موعد التذكير: ${item.scheduledAt.toLocal()} • '
                              'يكرر ${item.repetitionCount} مرات',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              final item = displayList[index];
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1050),
                  child: switch (item.type) {
                    'audio' => AudioPlayerWidget(resource: item),
                    'video' => VideoPlayerWidget(resource: item),
                    'pdf' => PdfViewerWidget(resource: item),
                    'image' => ImageResourceWidget(resource: item),
                    'post' => PostResourceWidget(resource: item),
                    'text' || _ => TextQuoteWidget(resource: item),
                  },
                ),
              );
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

Widget _buildTypeCards(
  ResourceProvider provider,
  bool isDark,
  Color gold,
  Color navy,
  ValueChanged<String> onSelected,
) {
  final cards = [
    ('Audio', 'صوتيات', Icons.mic_none_rounded, 'audio'),
    ('Video lessons', 'دروس مرئية', Icons.video_library_outlined, 'video'),
    ('PDF books', 'كتب ومطبوعات', Icons.menu_book_rounded, 'pdf'),
    ('Photos', 'صور', Icons.image_outlined, 'image'),
    ('Quotes', 'أقوال وفوائد', Icons.format_quote_rounded, 'text'),
    ('Posts', 'منشورات', Icons.post_add, 'post'),
    ('All library', 'كل المواد', Icons.auto_stories_outlined, 'all'),
    ('Playlists', 'قوائم ودورات', Icons.queue_music_rounded, 'playlists'),
  ];

  return Padding(
    padding: const EdgeInsets.fromLTRB(14, 5, 14, 10),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth >= 850
                ? (constraints.maxWidth - 8 * (cards.length - 1)) / cards.length
                : 128.0;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < cards.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    SizedBox(
                      width: itemWidth,
                      child: _buildTypeCard(
                        card: cards[index],
                        isSelected: provider.selectedType == cards[index].$4,
                        isDark: isDark,
                        gold: gold,
                        navy: navy,
                        onTap: () => onSelected(cards[index].$4),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

Widget _buildTypeCard({
  required (String, String, IconData, String) card,
  required bool isSelected,
  required bool isDark,
  required Color gold,
  required Color navy,
  required VoidCallback onTap,
}) {
  final background = isSelected
      ? navy
      : (isDark ? const Color(0xFF1E293B) : Colors.white);
  final foreground = isSelected ? Colors.white : (isDark ? Colors.white : navy);
  return Card(
    margin: EdgeInsets.zero,
    elevation: isSelected ? 2 : 0,
    color: background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: gold.withValues(alpha: isSelected ? .8 : .3)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(card.$3, size: 17, color: isSelected ? gold : foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                card.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
