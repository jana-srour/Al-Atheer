import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/playlist_model.dart';
import '../../models/resource_model.dart';
import '../../providers/resource_provider.dart';
import '../../widgets/archive_cover_editor.dart';
import '../../widgets/cover_image.dart';

class AdminPlaylistsScreen extends StatefulWidget {
  const AdminPlaylistsScreen({super.key});

  @override
  State<AdminPlaylistsScreen> createState() => _AdminPlaylistsScreenState();
}

class _AdminPlaylistsScreenState extends State<AdminPlaylistsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<ResourceModel> _resources = [];
  bool _isLoadingResources = true;
  String? _resourceError;

  @override
  void initState() {
    super.initState();
    _loadResources();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ResourceProvider>().fetchPlaylists();
      }
    });
  }

  Future<void> _loadResources() async {
    if (mounted) {
      setState(() {
        _isLoadingResources = true;
        _resourceError = null;
      });
    }
    try {
      final response = await _supabase
          .from('resources')
          .select('*')
          .order('title');
      if (!mounted) return;
      setState(() {
        _resources = (response as List)
            .map((item) => ResourceModel.fromJson(item))
            .toList();
        _resourceError = null;
        _isLoadingResources = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resourceError = error.toString();
        _isLoadingResources = false;
      });
    }
  }

  Future<void> _editPlaylist({PlaylistModel? playlist}) async {
    if (_isLoadingResources || _resourceError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حمّل المواد أولاً قبل إنشاء القائمة.')),
      );
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _PlaylistEditorDialog(playlist: playlist, resources: _resources),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ قائمة التشغيل')));
    }
  }

  Future<void> _deletePlaylist(PlaylistModel playlist) async {
    final provider = context.read<ResourceProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف قائمة التشغيل؟'),
        content: Text('سيتم حذف "${playlist.title}" من المكتبة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await provider.deletePlaylist(playlist.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف قائمة التشغيل')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر حذف القائمة: $error')));
      }
    }
  }

  Future<void> _movePlaylist(int index, int offset) async {
    try {
      await context.read<ResourceProvider>().movePlaylist(index, offset);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تغيير ترتيب القائمة: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResourceProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة قوائم التشغيل'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () {
              _loadResources();
              provider.fetchPlaylists();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoadingResources ? null : () => _editPlaylist(),
        icon: const Icon(Icons.add),
        label: const Text('قائمة جديدة'),
      ),
      body: _isLoadingResources || provider.isLoadingPlaylists
          ? const Center(child: CircularProgressIndicator())
          : _resourceError != null
          ? _LoadError(message: _resourceError!, onRetry: _loadResources)
          : provider.playlistsError != null && provider.playlists.isEmpty
          ? _LoadError(
              message: provider.playlistsError!,
              onRetry: provider.fetchPlaylists,
            )
          : provider.playlists.isEmpty
          ? const Center(child: Text('لم تُنشأ قوائم تشغيل بعد'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: provider.playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = provider.playlists[index];
                    final types = playlist.resources
                        .map((resource) => resource.typeLabel)
                        .toSet()
                        .join('، ');
                    return Card(
                      child: ListTile(
                        leading: CoverImage(
                          imageUrl: playlist.coverImageUrl,
                          width: 58,
                          height: 58,
                          fallbackIcon: Icons.queue_music_rounded,
                        ),
                        title: Text(playlist.title),
                        subtitle: Text(
                          '${playlist.resources.length} مادة${types.isEmpty ? '' : ' • $types'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Wrap(
                          spacing: 0,
                          children: [
                            IconButton(
                              tooltip: 'تحريك القائمة للأعلى',
                              onPressed: index == 0
                                  ? null
                                  : () => _movePlaylist(index, -1),
                              icon: const Icon(Icons.arrow_upward),
                            ),
                            IconButton(
                              tooltip: 'تحريك القائمة للأسفل',
                              onPressed: index == provider.playlists.length - 1
                                  ? null
                                  : () => _movePlaylist(index, 1),
                              icon: const Icon(Icons.arrow_downward),
                            ),
                            IconButton(
                              tooltip: 'تعديل المواد',
                              onPressed: () =>
                                  _editPlaylist(playlist: playlist),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'حذف القائمة',
                              onPressed: () => _deletePlaylist(playlist),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'تعذر تحميل بيانات قوائم التشغيل',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    ),
  );
}

class _PlaylistEditorDialog extends StatefulWidget {
  final PlaylistModel? playlist;
  final List<ResourceModel> resources;

  const _PlaylistEditorDialog({
    required this.playlist,
    required this.resources,
  });

  @override
  State<_PlaylistEditorDialog> createState() => _PlaylistEditorDialogState();
}

class _PlaylistEditorDialogState extends State<_PlaylistEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final List<int> _selectedResourceIds;
  String? _coverImageUrl;
  String _searchQuery = '';
  String? _saveError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.playlist?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.playlist?.description ?? '',
    );
    _coverImageUrl = widget.playlist?.coverImageUrl;
    _selectedResourceIds =
        widget.playlist?.resources.map((resource) => resource.id).toList() ??
        <int>[];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _saveError = 'أدخل اسم قائمة التشغيل.');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await context.read<ResourceProvider>().savePlaylist(
        id: widget.playlist?.id,
        title: title,
        description: _descriptionController.text.trim(),
        resourceIds: _selectedResourceIds,
        coverImageUrl: _coverImageUrl,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = 'تعذر حفظ القائمة: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleResources = widget.resources.where((resource) {
      final query = _searchQuery.trim().toLowerCase();
      return query.isEmpty ||
          resource.title.toLowerCase().contains(query) ||
          resource.category.toLowerCase().contains(query) ||
          resource.typeLabel.toLowerCase().contains(query);
    }).toList();

    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.playlist == null ? 'إنشاء قائمة تشغيل' : 'تعديل القائمة',
      ),
      content: SizedBox(
        width: 560,
        height: (MediaQuery.sizeOf(context).height * 0.55).clamp(280.0, 620.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'اسم القائمة'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'وصف (اختياري)'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ArchiveCoverEditor(
              imageUrl: _coverImageUrl,
              uploadTitle: _titleController.text,
              onChanged: (url) => setState(() => _coverImageUrl = url),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث عن مادة لإضافتها',
                isDense: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'المحدد: ${_selectedResourceIds.length}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            if (_selectedResourceIds.isNotEmpty)
              SizedBox(
                height: (_selectedResourceIds.length * 52.0)
                    .clamp(0.0, 130.0)
                    .toDouble(),
                child: ListView.builder(
                  itemCount: _selectedResourceIds.length,
                  itemBuilder: (context, index) {
                    final id = _selectedResourceIds[index];
                    final resource = widget.resources.firstWhere(
                      (item) => item.id == id,
                    );
                    return ListTile(
                      dense: true,
                      title: Text(
                        resource.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'تحريك المادة للأعلى',
                            visualDensity: VisualDensity.compact,
                            onPressed: index == 0
                                ? null
                                : () => setState(() {
                                    final selected = _selectedResourceIds
                                        .removeAt(index);
                                    _selectedResourceIds.insert(
                                      index - 1,
                                      selected,
                                    );
                                  }),
                            icon: const Icon(Icons.arrow_upward, size: 18),
                          ),
                          IconButton(
                            tooltip: 'تحريك المادة للأسفل',
                            visualDensity: VisualDensity.compact,
                            onPressed: index == _selectedResourceIds.length - 1
                                ? null
                                : () => setState(() {
                                    final selected = _selectedResourceIds
                                        .removeAt(index);
                                    _selectedResourceIds.insert(
                                      index + 1,
                                      selected,
                                    );
                                  }),
                            icon: const Icon(Icons.arrow_downward, size: 18),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 4),
            Expanded(
              child: visibleResources.isEmpty
                  ? const Center(child: Text('لا توجد مواد مطابقة'))
                  : ListView.builder(
                      itemCount: visibleResources.length,
                      itemBuilder: (context, index) {
                        final resource = visibleResources[index];
                        return CheckboxListTile(
                          dense: true,
                          value: _selectedResourceIds.contains(resource.id),
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedResourceIds.add(resource.id);
                              } else {
                                _selectedResourceIds.remove(resource.id);
                              }
                            });
                          },
                          title: Text(
                            resource.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${resource.typeLabel} • ${resource.category}',
                          ),
                          secondary: Icon(_iconForType(resource.type)),
                        );
                      },
                    ),
            ),
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _saveError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('حفظ القائمة'),
        ),
      ],
    );
  }

  IconData _iconForType(String type) => switch (type) {
    'audio' => Icons.audiotrack_rounded,
    'video' => Icons.videocam_rounded,
    'pdf' => Icons.picture_as_pdf_rounded,
    'image' => Icons.image_outlined,
    'post' => Icons.post_add,
    _ => Icons.format_quote_rounded,
  };
}
