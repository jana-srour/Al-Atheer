import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/resource_provider.dart';

class DailyWisdomCard extends StatefulWidget {
  const DailyWisdomCard({super.key});

  @override
  State<DailyWisdomCard> createState() => _DailyWisdomCardState();
}

class _DailyWisdomCardState extends State<DailyWisdomCard> {
  static const _selectedWisdomKeyPreference = 'daily_wisdom_selected_key';
  static const _selectedWisdomDayPreference = 'daily_wisdom_selected_day';
  static const _selectedWisdomKeysPreference = 'daily_wisdom_selected_keys';
  static const _wisdomSelectionConfiguredPreference =
      'daily_wisdom_selection_configured';

  bool _isExpanded = true;
  String? _selectedWisdomKey;
  String? _selectedWisdomDay;
  Set<String> _selectedWisdomKeys = {};
  bool _hasCustomWisdomSelection = false;
  int _selectionRevision = 0;

  @override
  void initState() {
    super.initState();
    _restoreWisdomSelection();
  }

  Future<void> _restoreWisdomSelection() async {
    final revision = _selectionRevision;
    try {
      final preferences = await SharedPreferences.getInstance();
      final day = preferences.getString(_selectedWisdomDayPreference);
      final key = preferences.getString(_selectedWisdomKeyPreference);
      final savedKeys = preferences.getStringList(
        _selectedWisdomKeysPreference,
      );
      var hasCustomSelection =
          preferences.getBool(_wisdomSelectionConfiguredPreference) ??
          savedKeys != null;
      var selectedKeys = savedKeys?.toSet() ?? <String>{};

      if (!hasCustomSelection &&
          day == _dayKey(DateTime.now()) &&
          key != null) {
        hasCustomSelection = true;
        selectedKeys = {key};
      }

      if (!mounted || revision != _selectionRevision) return;

      setState(() {
        _hasCustomWisdomSelection = hasCustomSelection;
        _selectedWisdomKeys = selectedKeys;
        if (day == _dayKey(DateTime.now()) && key != null) {
          _selectedWisdomDay = day;
          _selectedWisdomKey = key;
        }
      });
    } catch (error) {
      debugPrint('Could not restore the daily quote choice: $error');
    }
  }

  String _keyFor(Map<String, String> item) =>
      '${item['title']}\n${item['quote']}\n${item['source']}';

  String _dayKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  List<Map<String, String>> _wisdomChoices(List<Map<String, String>> wisdom) {
    if (!_hasCustomWisdomSelection) return wisdom;
    final selected = wisdom
        .where((item) => _selectedWisdomKeys.contains(_keyFor(item)))
        .toList();
    return selected.isEmpty ? wisdom : selected;
  }

  Map<String, String>? _chooseWisdom(List<Map<String, String>> wisdom) {
    if (wisdom.isEmpty) return null;
    final now = DateTime.now();
    final today = _dayKey(now);
    final choices = _wisdomChoices(wisdom);

    if (_selectedWisdomDay == today && _selectedWisdomKey != null) {
      for (final item in choices) {
        if (_keyFor(item) == _selectedWisdomKey) return item;
      }
    }

    final seed = now.year * 10000 + now.month * 100 + now.day;
    final item = choices[Random(seed).nextInt(choices.length)];
    _selectedWisdomKey = _keyFor(item);
    _selectedWisdomDay = today;
    return item;
  }

  Future<void> _saveWisdomSelection(
    Set<String> selectedKeys,
    List<Map<String, String>> wisdom,
  ) async {
    final selectedWisdom = wisdom
        .where((item) => selectedKeys.contains(_keyFor(item)))
        .toList();
    if (selectedWisdom.isEmpty) return;

    final day = _dayKey(DateTime.now());
    final item = selectedWisdom[Random().nextInt(selectedWisdom.length)];
    final key = _keyFor(item);
    final keys = selectedWisdom.map(_keyFor).toSet();
    _selectionRevision++;
    setState(() {
      _hasCustomWisdomSelection = true;
      _selectedWisdomKeys = keys;
      _selectedWisdomKey = key;
      _selectedWisdomDay = day;
    });

    try {
      final preferences = await SharedPreferences.getInstance();
      final selectionSaved = await preferences.setStringList(
        _selectedWisdomKeysPreference,
        selectedWisdom.map(_keyFor).toList(),
      );
      final configuredSaved = await preferences.setBool(
        _wisdomSelectionConfiguredPreference,
        true,
      );
      final keySaved = await preferences.setString(
        _selectedWisdomKeyPreference,
        key,
      );
      final daySaved = await preferences.setString(
        _selectedWisdomDayPreference,
        day,
      );
      if (!selectionSaved || !configuredSaved || !keySaved || !daySaved) {
        throw StateError('Could not save the daily quote choices.');
      }
    } catch (error) {
      debugPrint('Could not save the daily quote choice: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ اختيارات حكم اليوم: $error')),
        );
      }
    }
  }

  Future<void> _showAnotherWisdom(List<Map<String, String>> wisdom) async {
    if (wisdom.isEmpty) return;

    final choices = _wisdomChoices(wisdom);
    final alternatives = choices
        .where((item) => _keyFor(item) != _selectedWisdomKey)
        .toList();
    final available = alternatives.isEmpty ? choices : alternatives;
    final item = available[Random().nextInt(available.length)];
    final day = _dayKey(DateTime.now());
    final key = _keyFor(item);
    _selectionRevision++;
    setState(() {
      _selectedWisdomKey = key;
      _selectedWisdomDay = day;
    });

    try {
      final preferences = await SharedPreferences.getInstance();
      final keySaved = await preferences.setString(
        _selectedWisdomKeyPreference,
        key,
      );
      final daySaved = await preferences.setString(
        _selectedWisdomDayPreference,
        day,
      );
      if (!keySaved || !daySaved) {
        throw StateError('Could not save the daily quote choice.');
      }
    } catch (error) {
      debugPrint('Could not save the daily quote choice: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ اختيار حكمة اليوم: $error')),
        );
      }
    }
  }

  Future<void> _chooseWisdomFromList(List<Map<String, String>> wisdom) async {
    final allKeys = wisdom.map(_keyFor).toSet();
    final selectedKeys = _hasCustomWisdomSelection
        ? _selectedWisdomKeys.intersection(allKeys)
        : allKeys;
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('اختر حكم اليوم'),
          content: SizedBox(
            width: 520,
            height: 420,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('حدد حكمة واحدة أو أكثر للاختيار منها يومياً.'),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: wisdom.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final quote = wisdom[index];
                      final key = _keyFor(quote);
                      return Card(
                        child: CheckboxListTile(
                          value: selectedKeys.contains(key),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            quote['title']?.isNotEmpty == true
                                ? quote['title']!
                                : 'حكمة',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '«${quote['quote'] ?? ''}»',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if ((quote['source'] ?? '').isNotEmpty)
                                Text('— ${quote['source']}'),
                            ],
                          ),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selectedKeys.add(key);
                              } else {
                                selectedKeys.remove(key);
                              }
                            });
                          },
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: selectedKeys.isEmpty
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      Set<String>.of(selectedKeys),
                    ),
              child: const Text('حفظ الاختيارات'),
            ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      await _saveWisdomSelection(selected, wisdom);
    }
  }

  @override
  Widget build(BuildContext context) {
    const radiantGold = Color(0xFFF59E0B);
    const deepNavy = Color(0xFF0F172A);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<ResourceProvider>();
    final wisdom = [
      ...provider.curatedQuotes,
      ...provider.uploadedQuotes,
    ].where((item) => (item['quote'] ?? '').trim().isNotEmpty).toList();
    Map<String, String>? item;
    if (_selectedWisdomDay == _dayKey(DateTime.now())) {
      for (final candidate in _wisdomChoices(wisdom)) {
        if (_keyFor(candidate) == _selectedWisdomKey) {
          item = candidate;
          break;
        }
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
                  IconButton(
                    icon: const Icon(
                      Icons.format_list_bulleted,
                      size: 16,
                      color: radiantGold,
                    ),
                    tooltip: 'اختر حكمة اليوم من القائمة',
                    visualDensity: VisualDensity.compact,
                    onPressed: wisdom.isEmpty
                        ? null
                        : () => _chooseWisdomFromList(wisdom),
                  ),
                  // Change wisdom button
                  IconButton(
                    icon: const Icon(Icons.sync, size: 16, color: radiantGold),
                    tooltip: 'درة أخرى',
                    visualDensity: VisualDensity.compact,
                    onPressed: wisdom.isEmpty
                        ? null
                        : () => _showAnotherWisdom(wisdom),
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
                    item == null
                        ? 'أضف حكماً من مركز الإدارة أو انشر مادة نصية.'
                        : '«${item['quote']}»',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFF1EAD9)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sourceText,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
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
                        label: const Text(
                          'نسخ',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: quoteText == null
                            ? null
                            : () {
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
                        label: const Text(
                          'مشاركة',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: quoteText == null
                            ? null
                            : () {
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
