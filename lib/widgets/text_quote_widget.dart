import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/resource_model.dart';
import '../providers/settings_provider.dart';
import '../screens/text_reader_screen.dart';

class TextQuoteWidget extends StatefulWidget {
  final ResourceModel resource;
  const TextQuoteWidget({super.key, required this.resource});

  @override
  State<TextQuoteWidget> createState() => _TextQuoteWidgetState();
}

class _TextQuoteWidgetState extends State<TextQuoteWidget> {
  double _fontSize = 15.0;

  void _adjustFontSize(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(12.0, 22.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    const radiantGold = Color(0xFFF59E0B);
    const deepNavy = Color(0xFF0F172A);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context);
    final isFav = settings.isFavorite(widget.resource.id);

    final displayContent =
        widget.resource.textContent ?? widget.resource.description ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 7),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: radiantGold.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TextReaderScreen(resource: widget.resource),
          ),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF131F37), const Color(0xFF0B1426)]
                  : [Colors.white, const Color(0xFFFFFDF9)],
            ),
          ),
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Badges & Actions Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD97706), Color(0xFFB45309)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.format_quote,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.resource.folderLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions (Font zoom, Favorite, Copy, Share)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.text_decrease, size: 16),
                        tooltip: 'تصغير الخط',
                        color: Colors.grey,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _adjustFontSize(-1.5),
                      ),
                      IconButton(
                        icon: const Icon(Icons.text_increase, size: 16),
                        tooltip: 'تكبير الخط',
                        color: Colors.grey,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _adjustFontSize(1.5),
                      ),
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.star : Icons.star_border,
                          size: 19,
                          color: isFav ? radiantGold : Colors.grey,
                        ),
                        tooltip: 'حفظ في المفضلة',
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            settings.toggleFavorite(widget.resource.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 17),
                        tooltip: 'نسخ',
                        color: Colors.grey,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          final textToCopy =
                              '${widget.resource.title}\n\n"$displayContent"';
                          Clipboard.setData(ClipboardData(text: textToCopy));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم نسخ الفائدة إلى الحافظة'),
                              duration: Duration(seconds: 2),
                              backgroundColor: deepNavy,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 17),
                        tooltip: 'مشاركة',
                        color: Colors.grey,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Share.share(
                            '${widget.resource.title}\n\n"$displayContent"',
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                widget.resource.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),

              // Quote Body with decorative quotation mark
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.amber.shade50)
                      .withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: radiantGold.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayContent,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _fontSize,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFFF1EAD9)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Date Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.resource.formattedDate,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: radiantGold,
                    ),
                    icon: const Icon(Icons.auto_stories, size: 14),
                    label: const Text(
                      'عرض الفائدة كاملة',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TextReaderScreen(resource: widget.resource),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
