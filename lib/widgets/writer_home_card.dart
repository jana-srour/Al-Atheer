import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/writer_biography_screen.dart';
import 'cover_image.dart';

class WriterHomeCard extends StatefulWidget {
  const WriterHomeCard({super.key});

  @override
  State<WriterHomeCard> createState() => _WriterHomeCardState();
}

class _WriterHomeCardState extends State<WriterHomeCard> {
  late Future<Map<String, dynamic>?> _writerFuture;

  @override
  void initState() {
    super.initState();
    _writerFuture = _loadWriter();
  }

  Future<Map<String, dynamic>?> _loadWriter() => Supabase.instance.client
      .from('writer_biography')
      .select()
      .eq('id', 1)
      .maybeSingle();

  void _retry() {
    setState(() => _writerFuture = _loadWriter());
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    child: FutureBuilder<Map<String, dynamic>?>(
      future: _writerFuture,
      builder: (context, snapshot) {
        final writer = snapshot.data;
        final name = writer?['writer_name']?.toString().trim();
        final portrait = writer?['portrait_url']?.toString();
        final excerpt = _excerpt(writer);
        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
            ),
          ),
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF060D1A),
                  Color(0xFF0F172A),
                  Color(0xFF1E3A5F),
                ],
              ),
            ),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WriterBiographyScreen(),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 560;
                    final portraitWidget = Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFF59E0B),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.2),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: CoverImage(
                        imageUrl: portrait,
                        width: 88,
                        height: 88,
                        borderRadius: BorderRadius.circular(50),
                        fallbackIcon: Icons.person_rounded,
                      ),
                    );
                    final details = Column(
                      crossAxisAlignment: isNarrow
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: isNarrow
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.auto_stories_rounded,
                              color: Color(0xFFFBBF24),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'عن الكاتب وأعماله',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: const Color(0xFFFBBF24),
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name?.isNotEmpty == true ? name! : 'كاتب دار الأثير',
                          textAlign: isNarrow
                              ? TextAlign.center
                              : TextAlign.start,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          snapshot.hasError
                              ? 'تعذر تحميل نبذة الكاتب.'
                              : excerpt,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: isNarrow
                              ? TextAlign.center
                              : TextAlign.start,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.86),
                                height: 1.5,
                              ),
                        ),
                      ],
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          portraitWidget,
                          const SizedBox(height: 12),
                          details,
                          if (snapshot.hasError)
                            TextButton(
                              onPressed: _retry,
                              child: const Text('إعادة المحاولة'),
                            ),
                          const SizedBox(height: 6),
                          _readMore(context),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        portraitWidget,
                        const SizedBox(width: 18),
                        Expanded(child: details),
                        if (snapshot.hasError)
                          IconButton(
                            tooltip: 'إعادة المحاولة',
                            onPressed: _retry,
                            color: const Color(0xFFFBBF24),
                            icon: const Icon(Icons.refresh),
                          ),
                        const SizedBox(width: 8),
                        _readMore(context),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  String _excerpt(Map<String, dynamic>? writer) {
    if (writer == null) return 'تعرّف على الكاتب وسيرته وأعماله.';

    final rawSections = writer['sections'];
    if (rawSections is List) {
      for (final section in rawSections.whereType<Map>()) {
        final body = section['body']?.toString().trim() ?? '';
        if (body.isNotEmpty) return body;
      }
    }

    final biography = writer['biography']?.toString().trim() ?? '';
    return biography.isNotEmpty
        ? biography
        : 'تعرّف على الكاتب وسيرته وأعماله.';
  }

  Widget _readMore(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'اقرأ المزيد',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: const Color(0xFFFBBF24),
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(width: 4),
      const Icon(
        Icons.arrow_forward_rounded,
        color: Color(0xFFFBBF24),
        size: 16,
      ),
    ],
  );
}
