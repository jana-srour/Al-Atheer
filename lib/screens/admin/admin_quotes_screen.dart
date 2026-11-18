import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/resource_provider.dart';

class AdminQuotesScreen extends StatefulWidget {
  const AdminQuotesScreen({super.key});

  @override
  State<AdminQuotesScreen> createState() => _AdminQuotesScreenState();
}

class _AdminQuotesScreenState extends State<AdminQuotesScreen> {
  bool _isSavingSelection = false;
  bool _isSavingSchedule = false;

  Future<void> _addQuote() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AddCuratedQuoteDialog(),
    );
  }

  Future<void> _setQuoteSelected(int quoteId, bool selected) async {
    final provider = context.read<ResourceProvider>();
    final selectedIds = provider.dailyQuoteIds.toSet();
    if (selected) {
      selectedIds.add(quoteId);
    } else {
      selectedIds.remove(quoteId);
    }
    setState(() => _isSavingSelection = true);
    try {
      await provider.setDailyQuoteSelection(selectedIds);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث اختيار درر اليوم: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingSelection = false);
    }
  }

  Future<void> _manageQuoteSchedule(Map<String, String> quote) {
    final quoteId = int.parse(quote['id']!);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer<ResourceProvider>(
        builder: (context, provider, _) {
          final dates =
              provider.dailyQuoteSchedule.entries
                  .where((entry) => entry.value == quoteId)
                  .map((entry) => entry.key)
                  .toList()
                ..sort();
          return AlertDialog(
            scrollable: true,
            title: Text('جدولة ${quote['title']}'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'اختر يوماً لعرض هذه الحكمة. يمكن تحديد عدة أيام لها، '
                    'ويُسمح بحكمة واحدة فقط لكل يوم.',
                  ),
                  const SizedBox(height: 12),
                  if (dates.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('لا توجد تواريخ مجدولة لهذه الحكمة.'),
                    )
                  else
                    ...dates.map(
                      (date) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.event_available),
                        title: Text(_formatDate(date)),
                        trailing: IconButton(
                          tooltip: 'إزالة الجدولة',
                          onPressed: _isSavingSchedule
                              ? null
                              : () => _removeScheduleDate(date),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                  if (provider.dailyQuoteScheduleError != null)
                    Text(
                      'تعذر تحميل الجدول: '
                      '${provider.dailyQuoteScheduleError}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إغلاق'),
              ),
              FilledButton.icon(
                onPressed:
                    _isSavingSchedule ||
                        provider.isLoadingDailyQuoteSchedule ||
                        provider.dailyQuoteScheduleError != null
                    ? null
                    : () => _pickScheduleDate(dialogContext, quoteId),
                icon: const Icon(Icons.calendar_month),
                label: const Text('إضافة تاريخ'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickScheduleDate(
    BuildContext dialogContext,
    int quoteId,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = await showDatePicker(
      context: dialogContext,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(2100, 12, 31),
    );
    if (selectedDate == null || !mounted || !dialogContext.mounted) return;

    final provider = context.read<ResourceProvider>();
    final normalizedDate = DateTime.utc(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final existingQuoteId = provider.dailyQuoteSchedule[normalizedDate];
    if (existingQuoteId != null && existingQuoteId != quoteId) {
      final existingQuote = provider.curatedQuotes.firstWhere(
        (item) => int.tryParse(item['id'] ?? '') == existingQuoteId,
        orElse: () => {'title': 'حكمة أخرى'},
      );
      final shouldReplace = await showDialog<bool>(
        context: dialogContext,
        builder: (confirmationContext) => AlertDialog(
          title: const Text('التاريخ مستخدم'),
          content: Text(
            'هذا التاريخ مجدول بالفعل لـ «${existingQuote['title']}». '
            'هل تريد استبدالها بهذه الحكمة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(confirmationContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(confirmationContext, true),
              child: const Text('استبدال'),
            ),
          ],
        ),
      );
      if (shouldReplace != true || !mounted || !dialogContext.mounted) {
        return;
      }
    }

    setState(() => _isSavingSchedule = true);
    try {
      await provider.setDailyQuoteSchedule(
        date: selectedDate,
        quoteId: quoteId,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر حفظ موعد الحكمة: $error')));
      }
    } finally {
      if (mounted) setState(() => _isSavingSchedule = false);
    }
  }

  Future<void> _removeScheduleDate(DateTime date) async {
    final provider = context.read<ResourceProvider>();
    setState(() => _isSavingSchedule = true);
    try {
      await provider.setDailyQuoteSchedule(date: date, quoteId: null);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر إزالة الموعد: $error')));
      }
    } finally {
      if (mounted) setState(() => _isSavingSchedule = false);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResourceProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة درر اليوم'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () async {
              await Future.wait([
                provider.fetchCuratedQuotes(),
                provider.fetchDailyQuoteSelection(),
                provider.fetchDailyQuoteSchedule(),
              ]);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addQuote,
        icon: const Icon(Icons.add),
        label: const Text('إضافة حكمة'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child:
              provider.curatedQuotesError != null &&
                  provider.curatedQuotes.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'تعذر تحميل الحكم المُدارة. تأكد من إعداد جدول الحكم في Supabase.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        provider.curatedQuotesError!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: provider.fetchCuratedQuotes,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : provider.curatedQuotes.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'لا توجد حكم مُدارة بعد. أضف الحكم هنا، ثم حدّد واحدة '
                      'أو أكثر لتظهر في درة اليوم. لن تُستخدم النصوص المنشورة.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: provider.curatedQuotes.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      if (provider.dailyQuoteSelectionError != null ||
                          provider.dailyQuoteScheduleError != null) {
                        return Card(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (provider.dailyQuoteSelectionError != null)
                                  Text(
                                    'تعذر تحميل اختيارات درر اليوم: '
                                    '${provider.dailyQuoteSelectionError}',
                                  ),
                                if (provider.dailyQuoteScheduleError != null)
                                  Text(
                                    'تعذر تحميل مواعيد الحكم. شغّل '
                                    'supabase_daily_quote_schedule.sql في '
                                    'Supabase.\n'
                                    '${provider.dailyQuoteScheduleError}',
                                  ),
                              ],
                            ),
                          ),
                        );
                      }
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('اختيار درر اليوم'),
                          subtitle: Text(
                            provider.dailyQuoteIds.isEmpty
                                ? 'لم يتم تحديد حكم بعد. لن تظهر اقتباسات النصوص المنشورة.'
                                : 'المحدد: ${provider.dailyQuoteIds.length} '
                                      '— ستختار الصفحة الرئيسية يومياً من هذه الحكم فقط.',
                          ),
                        ),
                      );
                    }
                    if (index == 1) {
                      if (provider.isLoadingDailyQuoteSelection) {
                        return const LinearProgressIndicator();
                      }
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(8, 12, 8, 8),
                        child: Text(
                          'حدّد الحكم المستخدمة للاختيار العشوائي، واضغط رمز '
                          'التقويم لجدولة حكمة في يوم معين. في الأيام غير '
                          'المجدولة لن تتكرر الحكمة حتى تظهر بقية الحكم المحددة.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final quote = provider.curatedQuotes[index - 2];
                    final quoteId = int.parse(quote['id']!);
                    final scheduledDates =
                        provider.dailyQuoteSchedule.entries
                            .where((entry) => entry.value == quoteId)
                            .map((entry) => entry.key)
                            .toList()
                          ..sort();
                    final isNarrow = MediaQuery.sizeOf(context).width < 400;
                    return Card(
                      child: ListTile(
                        leading: Checkbox(
                          value: provider.dailyQuoteIds.contains(quoteId),
                          onChanged:
                              _isSavingSelection ||
                                  provider.isLoadingDailyQuoteSelection ||
                                  provider.dailyQuoteSelectionError != null
                              ? null
                              : (selected) {
                                  if (selected != null) {
                                    _setQuoteSelected(quoteId, selected);
                                  }
                                },
                        ),
                        title: Text(quote['title'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                quote['quote'] ?? '',
                                if ((quote['source'] ?? '').isNotEmpty)
                                  quote['source']!,
                              ].join('\n— '),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (scheduledDates.isNotEmpty)
                              Text(
                                'المواعيد: ${scheduledDates.map(_formatDate).join('، ')}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        trailing: isNarrow
                            ? PopupMenuButton<_QuoteAction>(
                                tooltip: 'خيارات الحكمة',
                                onSelected: (action) {
                                  if (action == _QuoteAction.schedule) {
                                    _manageQuoteSchedule(quote);
                                  } else {
                                    _deleteQuote(provider, quoteId);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    enabled:
                                        !_isSavingSchedule &&
                                        !provider.isLoadingDailyQuoteSchedule &&
                                        provider.dailyQuoteScheduleError ==
                                            null,
                                    value: _QuoteAction.schedule,
                                    child: const Text('جدولة الحكمة'),
                                  ),
                                  PopupMenuItem(
                                    enabled: !_isSavingSelection,
                                    value: _QuoteAction.delete,
                                    child: const Text('حذف الحكمة'),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'جدولة الحكمة بالتاريخ',
                                    onPressed:
                                        _isSavingSchedule ||
                                            provider
                                                .isLoadingDailyQuoteSchedule ||
                                            provider.dailyQuoteScheduleError !=
                                                null
                                        ? null
                                        : () => _manageQuoteSchedule(quote),
                                    icon: Icon(
                                      scheduledDates.isEmpty
                                          ? Icons.calendar_month_outlined
                                          : Icons.event_available,
                                      color: const Color(0xFFF59E0B),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'حذف',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: _isSavingSelection
                                        ? null
                                        : () => _deleteQuote(provider, quoteId),
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

  Future<void> _deleteQuote(ResourceProvider provider, int quoteId) async {
    try {
      await provider.deleteCuratedQuote(id: quoteId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر حذف الحكمة: $error')));
    }
  }
}

enum _QuoteAction { schedule, delete }

class _AddCuratedQuoteDialog extends StatefulWidget {
  const _AddCuratedQuoteDialog();

  @override
  State<_AddCuratedQuoteDialog> createState() => _AddCuratedQuoteDialogState();
}

class _AddCuratedQuoteDialogState extends State<_AddCuratedQuoteDialog> {
  final _titleController = TextEditingController();
  final _quoteController = TextEditingController();
  final _sourceController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _quoteController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    final quote = _quoteController.text.trim();
    if (title.isEmpty || quote.isEmpty) {
      setState(() => _error = 'أدخل العنوان ونص الحكمة.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await context.read<ResourceProvider>().addCuratedQuote(
        title: title,
        quote: quote,
        source: _sourceController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'تعذر حفظ الحكمة: $exception';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: AlertDialog(
        title: const Text('إضافة حكمة يومية'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                ),
                TextField(
                  controller: _quoteController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'النص'),
                ),
                TextField(
                  controller: _sourceController,
                  decoration: const InputDecoration(
                    labelText: 'المصدر (اختياري)',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
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
                : const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}
