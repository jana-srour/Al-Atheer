import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class DailyWisdomCard extends StatefulWidget {
  const DailyWisdomCard({super.key});

  @override
  State<DailyWisdomCard> createState() => _DailyWisdomCardState();
}

class _DailyWisdomCardState extends State<DailyWisdomCard> {
  bool _isExpanded = true;
  int _currentIndex = 0;

  static const List<Map<String, String>> _wisdomList = [
    {
      'title': 'فضل العلم الشرعي',
      'quote': 'مَن سَلَكَ طَرِيقاً يَلْتَمِسُ فِيهِ عِلْماً، سَهَّلَ اللَّهُ لَهُ بِهِ طَرِيقاً إِلَى الْجَنَّةِ.',
      'source': 'صحيح مسلم • عن أبي هريرة رضي الله عنه',
    },
    {
      'title': 'بركة القرآن الكريم',
      'quote': 'خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ.',
      'source': 'صحيح البخاري • عن عثمان بن عفان رضي الله عنه',
    },
    {
      'title': 'حكمة الإمام الشافعي',
      'quote': 'العِلْمُ مَا نَفَعَ، لَيْسَ العِلْمُ مَا حُفِظَ.',
      'source': 'سير أعلام النبلاء • للإمام الشافعي رحمه الله',
    },
    {
      'title': 'نور البصيرة',
      'quote': 'مَن أَرادَ صَفاءَ قَلبِهِ فَلْيُؤثِرِ اللهَ على شَهوَتِهِ.',
      'source': 'الفوائد • لابن القيم رحمه الله',
    },
    {
      'title': 'العمل الصالح',
      'quote': 'أَحَبُّ الأَعْمَالِ إِلَى اللهِ أَدْوَمُهَا وَإِنْ قَلَّ.',
      'source': 'متفق عليه • عن عائشة رضي الله عنها',
    },
  ];

  void _nextWisdom() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _wisdomList.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    const radiantGold = Color(0xFFF59E0B);
    const deepNavy = Color(0xFF0F172A);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = _wisdomList[_currentIndex];

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
                    onPressed: _nextWisdom,
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
                    item['title']!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: radiantGold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '«${item['quote']}»',
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
                    item['source']!,
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
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: '${item['quote']}\n— ${item['source']}',
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
                        onPressed: () {
                          Share.share('${item['quote']}\n— ${item['source']}');
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
