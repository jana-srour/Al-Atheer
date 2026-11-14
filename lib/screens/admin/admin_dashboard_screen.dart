import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/resource_model.dart';
import '../../providers/resource_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/archive_upload_service.dart';
import 'admin_upload_widget.dart';
import 'admin_playlists_screen.dart';
import 'admin_quotes_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  late TabController _tabController;
  Timer? _tickerTimer;

  List<ResourceModel> _resources = [];
  List<String> _categories = ['Fiqh', 'Aqeedah', 'Tafseer', 'General'];
  bool _isLoading = true;
  bool _hasArchiveKeys = false;
  String _searchFilter = '';
  String _typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkArchiveKeys();
    _fetchData();

    // Periodic timer to keep live countdown badges ticking every second
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        final hasProcessing = _resources.any(
          (r) => r.isProcessing(
            delaySeconds: settings.archiveIngestionDelaySeconds,
          ),
        );
        if (hasProcessing) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkArchiveKeys() async {
    final hasKeys = await ArchiveUploadService.hasCredentials();
    if (mounted) setState(() => _hasArchiveKeys = hasKeys);
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final resResponse = await _supabase
          .from('resources')
          .select()
          .order('created_at', ascending: false);

      final loadedResources = (resResponse as List)
          .map((map) => ResourceModel.fromMap(map))
          .toList();

      try {
        final catResponse = await _supabase.from('categories').select('name');
        if (catResponse.isNotEmpty) {
          _categories = (catResponse as List)
              .map((c) => c['name'].toString())
              .toList();
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _resources = loadedResources;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching admin data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteResource(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف المادة من المكتبة'),
        content: const Text(
          'هل أنت متأكد من رغبتك في حذف هذا المحتوى نهائياً من قاعدة البيانات؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('resources').delete().eq('id', id);
      if (mounted) {
        setState(() {
          _resources.removeWhere((r) => r.id == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف المادة بنجاح.'),
            backgroundColor: Color(0xFF0F172A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testReadiness(ResourceModel resource) async {
    final resProv = Provider.of<ResourceProvider>(context, listen: false);
    final isReady = await resProv.probeResourceReadiness(resource);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isReady
                ? '🎉 أصبح الملف متاحاً بالكامل في الأرشيف!'
                : '⏳ لا يزال أرشيف الإنترنت يعالج الملف، يرجى الانتظار.',
          ),
          backgroundColor: isReady
              ? const Color(0xFF0F172A)
              : Colors.amber.shade900,
        ),
      );
      setState(() {});
    }
  }

  void _showResourceEditDialog(ResourceModel resource) {
    showDialog(
      context: context,
      builder: (_) => ResourceEditDialog(
        resourceToEdit: resource,
        categories: _categories,
        onSaved: _fetchData,
      ),
    );
  }

  void _showCategoryManagerDialog() {
    showDialog(
      context: context,
      builder: (_) =>
          CategoryManagerDialog(categories: _categories, onChanged: _fetchData),
    );
  }

  void _showCredentialsDialog() {
    final accessCtrl = TextEditingController();
    final secretCtrl = TextEditingController();

    ArchiveUploadService.getCredentials().then((creds) {
      if (creds != null) {
        accessCtrl.text = creds['accessKey'] ?? '';
        secretCtrl.text = creds['secretKey'] ?? '';
      }
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.vpn_key, color: Color(0xFFF59E0B)),
            SizedBox(width: 10),
            Text('Archive.org S3 Keys', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configure your Internet Archive S3 Access & Secret Keys to enable automatic direct uploading.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://archive.org/account/s3.php'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: Color(0xFF0F172A),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Open archive.org/account/s3.php to generate keys',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: accessCtrl,
                decoration: const InputDecoration(
                  labelText: 'S3 Access Key',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secretCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'S3 Secret Key',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (accessCtrl.text.trim().isNotEmpty &&
                  secretCtrl.text.trim().isNotEmpty) {
                try {
                  await ArchiveUploadService.saveCredentials(
                    accessKey: accessCtrl.text.trim(),
                    secretKey: secretCtrl.text.trim(),
                  );
                  await _checkArchiveKeys();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Archive.org credentials saved!'),
                        backgroundColor: Color(0xFF0F172A),
                      ),
                    );
                  }
                } catch (error) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Could not save credentials: $error'),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Save Keys'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context);
    final resProv = Provider.of<ResourceProvider>(context);
    final delaySeconds = settings.archiveIngestionDelaySeconds;
    const radiantGold = Color(0xFFF59E0B);
    final filteredResources = _resources.where((r) {
      final matchesSearch =
          _searchFilter.isEmpty ||
          r.title.toLowerCase().contains(_searchFilter.toLowerCase()) ||
          r.category.toLowerCase().contains(_searchFilter.toLowerCase());

      bool matchesType = true;
      if (_typeFilter == 'processing') {
        matchesType = !resProv.isResourceReady(r, delaySeconds: delaySeconds);
      } else if (_typeFilter != 'all') {
        matchesType = r.type == _typeFilter;
      }

      return matchesSearch && matchesType;
    }).toList();

    final processingItems = _resources
        .where((r) => !resProv.isResourceReady(r, delaySeconds: delaySeconds))
        .toList();

    final audioCount = _resources.where((r) => r.type == 'audio').length;
    final videoCount = _resources.where((r) => r.type == 'video').length;
    final pdfCount = _resources.where((r) => r.type == 'pdf').length;
    final quoteCount = _resources.where((r) => r.type == 'text').length;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.admin_panel_settings, color: radiantGold),
            SizedBox(width: 8),
            Text('مركز إدارة دار الأثير', style: TextStyle(fontSize: 18)),
          ],
        ),
        actions: [
          // S3 Status Chip
          ActionChip(
            avatar: Icon(
              _hasArchiveKeys ? Icons.cloud_done : Icons.cloud_off,
              color: _hasArchiveKeys ? radiantGold : Colors.amberAccent,
              size: 16,
            ),
            label: Text(
              _hasArchiveKeys ? 'Archive.org متصل' : 'مفاتيح S3 مطلوبة',
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF0F172A),
            side: BorderSide(
              color: _hasArchiveKeys ? radiantGold : Colors.amberAccent,
            ),
            onPressed: _showCredentialsDialog,
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.queue_music_rounded, color: Colors.white),
            tooltip: 'إدارة قوائم التشغيل',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminPlaylistsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined, color: Colors.white),
            tooltip: 'إدارة التصنيفات',
            onPressed: _showCategoryManagerDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _checkArchiveKeys();
              _fetchData();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: radiantGold,
          indicatorWeight: 3,
          labelColor: radiantGold,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(icon: Icon(Icons.publish), text: 'استوديو النشر'),
            Tab(
              icon: Badge(
                isLabelVisible: processingItems.isNotEmpty,
                label: Text('${processingItems.length}'),
                backgroundColor: Colors.amber.shade800,
                child: const Icon(Icons.inventory_2_outlined),
              ),
              text: 'مخزون المكتبة',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Publisher Studio
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KPI Stat Cards
                _buildStatsGrid(
                  total: _resources.length,
                  audios: audioCount,
                  videos: videoCount,
                  pdfs: pdfCount,
                  quotes: quoteCount,
                  processingCount: processingItems.length,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminPlaylistsScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.queue_music_rounded),
                      label: const Text('إنشاء وإدارة قوائم التشغيل'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminQuotesScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.format_quote_rounded),
                      label: const Text('إدارة درر اليوم'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Full Luxury Publishing Studio
                AdminUploadWidget(
                  onPublished: () {
                    _fetchData();
                  },
                ),
              ],
            ),
          ),

          // TAB 2: Library Inventory Management
          Column(
            children: [
              // Ingestion Processing Queue Header (if any item is currently indexing)
              if (processingItems.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: Colors.amber.shade900.withValues(alpha: 0.15),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.hourglass_top,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'طابور المعالجة: ${processingItems.length} مواد قيد الفهرسة في أرشيف الإنترنت',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _typeFilter = 'processing'),
                        child: const Text(
                          'عرض فقط',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Search & Filter Bar
              Container(
                padding: const EdgeInsets.all(14),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'ابحث في المخزون بالعنوان أو التصنيف...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: radiantGold,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: radiantGold.withValues(alpha: 0.3),
                          ),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E293B)
                            : Colors.grey.shade100,
                      ),
                      onChanged: (val) => setState(() => _searchFilter = val),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChoice(
                            'all',
                            'الكل (${_resources.length})',
                          ),
                          const SizedBox(width: 6),
                          if (processingItems.isNotEmpty) ...[
                            _buildFilterChoice(
                              'processing',
                              'قيد الفهرسة (${processingItems.length})',
                            ),
                            const SizedBox(width: 6),
                          ],
                          _buildFilterChoice('pdf', 'PDFs ($pdfCount)'),
                          const SizedBox(width: 6),
                          _buildFilterChoice('audio', 'صوتيات ($audioCount)'),
                          const SizedBox(width: 6),
                          _buildFilterChoice('video', 'مرئيات ($videoCount)'),
                          const SizedBox(width: 6),
                          _buildFilterChoice('text', 'اقتباسات ($quoteCount)'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Inventory List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: radiantGold),
                      )
                    : filteredResources.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open_outlined,
                              size: 54,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'لا توجد مواد مطابقة للبحث',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredResources.length,
                        itemBuilder: (ctx, index) {
                          final item = filteredResources[index];
                          return _buildResourceCard(
                            item,
                            isDark,
                            delaySeconds: delaySeconds,
                            isReady: resProv.isResourceReady(
                              item,
                              delaySeconds: delaySeconds,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChoice(String type, String label) {
    const radiantGold = Color(0xFFF59E0B);
    const deepEmerald = Color(0xFF0F172A);
    final isSelected = _typeFilter == type;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) => setState(() => _typeFilter = type),
      selectedColor: deepEmerald,
      labelStyle: TextStyle(
        color: isSelected ? radiantGold : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? radiantGold : Colors.grey.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildStatsGrid({
    required int total,
    required int audios,
    required int videos,
    required int pdfs,
    required int quotes,
    required int processingCount,
    required bool isDark,
  }) {
    const radiantGold = Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: radiantGold.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'إحصائيات دار النشر',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              if (processingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '$processingCount قيد الأرشفة',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'المحتويات',
                  '$total',
                  Icons.auto_stories,
                  radiantGold,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'كتب PDF',
                  '$pdfs',
                  Icons.picture_as_pdf,
                  Colors.redAccent,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'صوتيات',
                  '$audios',
                  Icons.audiotrack,
                  radiantGold,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'مرئيات',
                  '$videos',
                  Icons.videocam,
                  Colors.purpleAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildResourceCard(
    ResourceModel res,
    bool isDark, {
    required int delaySeconds,
    required bool isReady,
  }) {
    IconData typeIcon;
    Color iconColor;
    const radiantGold = Color(0xFFF59E0B);
    const deepEmerald = Color(0xFF0F172A);

    switch (res.type) {
      case 'audio':
        typeIcon = Icons.audiotrack;
        iconColor = radiantGold;
        break;
      case 'video':
        typeIcon = Icons.videocam;
        iconColor = Colors.purpleAccent;
        break;
      case 'pdf':
        typeIcon = Icons.picture_as_pdf;
        iconColor = Colors.redAccent;
        break;
      case 'text':
      default:
        typeIcon = Icons.format_quote;
        iconColor = radiantGold;
        break;
    }

    final remainingStr = res.formattedRemainingTime(delaySeconds: delaySeconds);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isReady
              ? radiantGold.withValues(alpha: 0.25)
              : Colors.amber.withValues(alpha: 0.6),
          width: isReady ? 1 : 1.4,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: deepEmerald,
          child: Icon(typeIcon, color: iconColor, size: 20),
        ),
        title: Text(
          res.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: radiantGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    res.category,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: radiantGold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  res.type.toUpperCase(),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (!isReady) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.amber.shade400,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.hourglass_top,
                          size: 10,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'تجهيز: $remainingStr',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isReady && res.archiveUrl != null)
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: Colors.amber),
                tooltip: 'فحص جاهزية الرابط',
                onPressed: () => _testReadiness(res),
              ),
            if (res.archiveUrl != null && res.archiveUrl!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 19),
                tooltip: 'فتح الرابط المباشر للأرشيف',
                color: radiantGold,
                onPressed: () => launchUrl(
                  Uri.parse(res.archiveUrl!),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: radiantGold,
                size: 20,
              ),
              onPressed: () => _showResourceEditDialog(res),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 20,
              ),
              onPressed: () => _deleteResource(res.id),
            ),
          ],
        ),
      ),
    );
  }
}

// Edit Resource Dialog
class ResourceEditDialog extends StatefulWidget {
  final ResourceModel resourceToEdit;
  final List<String> categories;
  final VoidCallback onSaved;

  const ResourceEditDialog({
    super.key,
    required this.resourceToEdit,
    required this.categories,
    required this.onSaved,
  });

  @override
  State<ResourceEditDialog> createState() => _ResourceEditDialogState();
}

class _ResourceEditDialogState extends State<ResourceEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _urlCtrl;
  late TextEditingController _textCtrl;
  late String _type;
  late String _category;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.resourceToEdit.title);
    _descCtrl = TextEditingController(
      text: widget.resourceToEdit.description ?? '',
    );
    _urlCtrl = TextEditingController(
      text: widget.resourceToEdit.archiveUrl ?? '',
    );
    _textCtrl = TextEditingController(
      text: widget.resourceToEdit.textContent ?? '',
    );
    _type = widget.resourceToEdit.type;
    _category = widget.categories.contains(widget.resourceToEdit.category)
        ? widget.resourceToEdit.category
        : (widget.categories.isNotEmpty ? widget.categories.first : 'Fiqh');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client
          .from('resources')
          .update({
            'title': _titleCtrl.text.trim(),
            'description': _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            'archive_url': _type != 'text' ? _urlCtrl.text.trim() : null,
            'text_content': _type == 'text' ? _textCtrl.text.trim() : null,
            'type': _type,
            'category': _category,
          })
          .eq('id', widget.resourceToEdit.id);

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('تعديل بيانات المادة'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'العنوان *'),
                validator: (v) => v!.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'النوع'),
                items: const [
                  DropdownMenuItem(value: 'pdf', child: Text('كتاب PDF')),
                  DropdownMenuItem(value: 'audio', child: Text('تسجيل صوتي')),
                  DropdownMenuItem(
                    value: 'video',
                    child: Text('مرئي / درس مصور'),
                  ),
                  DropdownMenuItem(
                    value: 'text',
                    child: Text('اقتباس / فائدة'),
                  ),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'التصنيف'),
                items: widget.categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              if (_type != 'text') ...[
                TextFormField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رابط التحميل المباشر من الأرشيف',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_type == 'text') ...[
                TextFormField(
                  controller: _textCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'نص الفائدة'),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'الوصف أو النبذة'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
          ),
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : const Text('حفظ التعديلات'),
        ),
      ],
    );
  }
}

// Category Manager Dialog
class CategoryManagerDialog extends StatefulWidget {
  final List<String> categories;
  final VoidCallback onChanged;

  const CategoryManagerDialog({
    super.key,
    required this.categories,
    required this.onChanged,
  });

  @override
  State<CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<CategoryManagerDialog> {
  final TextEditingController _catController = TextEditingController();

  Future<void> _addCategory() async {
    final name = _catController.text.trim();
    if (name.isEmpty) return;
    try {
      await Supabase.instance.client.from('categories').insert({'name': name});
      _catController.clear();
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding category: $e')));
      }
    }
  }

  Future<void> _deleteCategory(String name) async {
    try {
      await Supabase.instance.client
          .from('categories')
          .delete()
          .eq('name', name);
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting category: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const radiantGold = Color(0xFFF59E0B);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.category, color: radiantGold),
          SizedBox(width: 8),
          Text('إدارة التصنيفات'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _catController,
                    decoration: const InputDecoration(
                      labelText: 'اسم التصنيف الجديد',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                  ),
                  icon: const Icon(Icons.add, color: radiantGold),
                  onPressed: _addCategory,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'التصنيفات الحالية:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.categories.length,
                itemBuilder: (context, index) {
                  final cat = widget.categories[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      cat,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () => _deleteCategory(cat),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}
