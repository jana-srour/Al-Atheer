import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../widgets/archive_cover_editor.dart';
import '../widgets/cover_image.dart';

class WriterBiographySection {
  final String title;
  final String body;

  const WriterBiographySection({required this.title, required this.body});
}

class WriterBiographyScreen extends StatefulWidget {
  const WriterBiographyScreen({super.key});

  @override
  State<WriterBiographyScreen> createState() => _WriterBiographyScreenState();
}

class _WriterBiographyScreenState extends State<WriterBiographyScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _writerName = '';
  String _portraitUrl = '';
  List<WriterBiographySection> _sections = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBiography();
  }

  Future<void> _loadBiography() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final row = await _supabase
          .from('writer_biography')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (!mounted) return;
      final rawSections = row?['sections'];
      final sections = rawSections is List
          ? rawSections
                .whereType<Map>()
                .map(
                  (section) => WriterBiographySection(
                    title: section['title']?.toString() ?? '',
                    body: section['body']?.toString() ?? '',
                  ),
                )
                .toList()
          : <WriterBiographySection>[];
      if (sections.isEmpty &&
          row?['biography']?.toString().isNotEmpty == true) {
        sections.add(
          WriterBiographySection(
            title: 'السيرة الذاتية',
            body: row!['biography'].toString(),
          ),
        );
      }
      setState(() {
        _writerName = row?['writer_name']?.toString() ?? '';
        _portraitUrl = row?['portrait_url']?.toString() ?? '';
        _sections = sections;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _editBiography() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WriterBiographyEditor(
        writerName: _writerName,
        portraitUrl: _portraitUrl,
        sections: _sections,
      ),
    );
    if (saved == true && mounted) await _loadBiography();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('عن الكاتب'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'تعديل السيرة الذاتية',
              onPressed: _editBiography,
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loadBiography,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _BiographyError(message: _error!, onRetry: _loadBiography)
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF060D1A),
                            Color(0xFF0F172A),
                            Color(0xFF1E3A5F),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0F172A,
                            ).withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 560;
                          final portraitWidget = Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFF59E0B),
                            ),
                            child: CoverImage(
                              imageUrl: _portraitUrl,
                              width: 132,
                              height: 132,
                              borderRadius: BorderRadius.circular(100),
                              fallbackIcon: Icons.person_rounded,
                            ),
                          );
                          final identity = Column(
                            crossAxisAlignment: compact
                                ? CrossAxisAlignment.center
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                _writerName.isEmpty
                                    ? 'كاتب دار الأثير'
                                    : _writerName,
                                textAlign: compact
                                    ? TextAlign.center
                                    : TextAlign.start,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'عن الكاتب وأعماله',
                                textAlign: compact
                                    ? TextAlign.center
                                    : TextAlign.start,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: const Color(0xFFFBBF24)),
                              ),
                            ],
                          );

                          if (compact) {
                            return Column(
                              children: [
                                portraitWidget,
                                const SizedBox(height: 18),
                                identity,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              portraitWidget,
                              const SizedBox(width: 24),
                              Expanded(child: identity),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_sections.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'لم تتم إضافة محتوى بعد.',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(height: 1.8),
                          ),
                        ),
                      )
                    else
                      for (final section in _sections)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.auto_stories_rounded,
                                      color: Color(0xFFF59E0B),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        section.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  section.body,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.copyWith(height: 1.8),
                                ),
                              ],
                            ),
                          ),
                        ),
                    if (isAdmin) ...[
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _editBiography,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('تعديل صفحة الكاتب'),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _WriterBiographyEditor extends StatefulWidget {
  final String writerName;
  final String portraitUrl;
  final List<WriterBiographySection> sections;

  const _WriterBiographyEditor({
    required this.writerName,
    required this.portraitUrl,
    required this.sections,
  });

  @override
  State<_WriterBiographyEditor> createState() => _WriterBiographyEditorState();
}

class _WriterBiographyEditorState extends State<_WriterBiographyEditor> {
  late final TextEditingController _nameController;
  late String? _portraitUrl;
  late final List<_WriterSectionControllers> _sectionControllers;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.writerName);
    _portraitUrl = widget.portraitUrl.isEmpty ? null : widget.portraitUrl;
    _sectionControllers = widget.sections
        .map(
          (section) => _WriterSectionControllers(
            title: section.title,
            body: section.body,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final section in _sectionControllers) {
      section.dispose();
    }
    super.dispose();
  }

  void _addSection() {
    setState(() => _sectionControllers.add(_WriterSectionControllers()));
  }

  void _removeSection(int index) {
    final section = _sectionControllers.removeAt(index);
    section.dispose();
    setState(() {});
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'أدخل اسم الكاتب.');
      return;
    }
    if (_sectionControllers.any(
      (section) =>
          section.title.text.trim().isEmpty || section.body.text.trim().isEmpty,
    )) {
      setState(() => _error = 'أدخل عنواناً ومحتوى لكل قسم أو احذفه.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'save_writer_biography_sections',
        params: {
          'p_writer_name': _nameController.text.trim(),
          'p_portrait_url': _portraitUrl,
          'p_sections': _sectionControllers
              .map(
                (section) => {
                  'title': section.title.text.trim(),
                  'body': section.body.text.trim(),
                },
              )
              .toList(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'تعذر حفظ صفحة الكاتب: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_isSaving,
    child: AlertDialog(
      title: const Text('تعديل صفحة الكاتب'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'اسم الكاتب'),
              ),
              const SizedBox(height: 12),
              for (
                var index = 0;
                index < _sectionControllers.length;
                index++
              ) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'القسم ${index + 1}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            IconButton(
                              tooltip: 'حذف القسم',
                              onPressed: _isSaving
                                  ? null
                                  : () => _removeSection(index),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        TextField(
                          controller: _sectionControllers[index].title,
                          decoration: const InputDecoration(
                            labelText: 'عنوان القسم',
                            hintText: 'مثال: المؤلفات أو السيرة الذاتية',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _sectionControllers[index].body,
                          minLines: 3,
                          maxLines: 10,
                          decoration: const InputDecoration(
                            labelText: 'المحتوى',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _addSection,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة قسم'),
                ),
              ),
              const SizedBox(height: 12),
              ArchiveCoverEditor(
                imageUrl: _portraitUrl,
                uploadTitle: _nameController.text,
                onChanged: (url) => setState(() => _portraitUrl = url),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
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
              : const Text('حفظ'),
        ),
      ],
    ),
  );
}

class _WriterSectionControllers {
  final TextEditingController title;
  final TextEditingController body;

  _WriterSectionControllers({String title = '', String body = ''})
    : title = TextEditingController(text: title),
      body = TextEditingController(text: body);

  void dispose() {
    title.dispose();
    body.dispose();
  }
}

class _BiographyError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _BiographyError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 44),
          const SizedBox(height: 10),
          const Text('تعذر تحميل صفحة الكاتب'),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
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
