import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/resource_provider.dart';

class DailyWisdomCard extends StatefulWidget {
  const DailyWisdomCard({super.key});

  @override
  State<DailyWisdomCard> createState() => _DailyWisdomCardState();
}

class _DailyWisdomCardState extends State<DailyWisdomCard> {
  bool _isExpanded = true;
  String? _selectedWisdomKey;

  String _keyFor(Map<String, String> item) =>
      '${item['title']}\n${item['quote']}\n${item['source']}';

  Map<String, String>? _chooseWisdom(List<Map<String, String>> wisdom) {
    if (wisdom.isEmpty) return null;
    final alternatives = wisdom
        .where((item) => _keyFor(item) != _selectedWisdomKey)
        .toList();
    final choices = alternatives.isEmpty ? wisdom : alternatives;
    final item = choices[Random().nextInt(choices.length)];
    _selectedWisdomKey = _keyFor(item);
    return item;
  }

  @override
  Widget build(BuildContext context) {
    const radiantGold = Color(0xFFF59E0B);
    const deepNavy = Color(0xFF0F172A);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<ResourceProvider>();
    final wisdom = [...provider.curatedQuotes, ...provider.uploadedQuotes]
        .where((item) => (item['quote'] ?? '').trim().isNotEmpty)
        .toList();
    Map<String, String>? item;
    for (final candidate in wisdom) {
      if (_keyFor(candidate) == _selectedWisdomKey) {
        item = candidate;
        break;
      }
    }
    item ??= _chooseWisdom(wisdom);
    final quoteText = item?['quote'];
    final sourceText = item?['source'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFFFFDF9), const Color(0xFFF8FAFF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: radiantGold.withValues(alpha: 0.38),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: radiantGold.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Bar
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: deepNavy,
                      border: Border.all(color: radiantGold, width: 1),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: radiantGold,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'درة اليوم • نفحات إيمانية',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  // Change wisdom button
                  IconButton(
                    icon: const Icon(Icons.sync, size: 16, color: radiantGold),
                    tooltip: 'درة أخرى',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      _selectedWisdomKey = null;
                    }),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const Divider(height: 1, thickness: 0.6),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    item?['title'] ?? 'لا توجد حكم متاحة حالياً',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: radiantGold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item == null ? 'أضف حكماً من مركز الإدارة أو انشر مادة نصية.' : '«${item['quote']}»',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFF1EAD9) : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sourceText,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: radiantGold,
                        ),
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('نسخ', style: TextStyle(fontSize: 11)),
                        onPressed: quoteText == null ? null : () {
                          Clipboard.setData(
                            ClipboardData(
                              text: '$quoteText\n— $sourceText',
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم نسخ الحكمة بنجاح'),
                              duration: Duration(seconds: 2),
                              backgroundColor: Color(0xFF0F172A),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: radiantGold,
                        ),
                        icon: const Icon(Icons.share, size: 14),
                        label: const Text('مشاركة', style: TextStyle(fontSize: 11)),
                        onPressed: quoteText == null ? null : () {
                          Share.share('$quoteText\n— $sourceText');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
