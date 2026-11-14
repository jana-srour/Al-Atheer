import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/resource_provider.dart';

class AdminQuotesScreen extends StatefulWidget {
  const AdminQuotesScreen({super.key});

  @override
  State<AdminQuotesScreen> createState() => _AdminQuotesScreenState();
}

class _AdminQuotesScreenState extends State<AdminQuotesScreen> {
  Future<void> _addQuote() async {
    final titleController = TextEditingController();
    final quoteController = TextEditingController();
    final sourceController = TextEditingController();
    var saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة حكمة يومية'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                  ),
                  TextField(
                    controller: quoteController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'النص'),
                  ),
                  TextField(
                    controller: sourceController,
                    decoration: const InputDecoration(
                      labelText: 'المصدر (اختياري)',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
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
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      final quote = quoteController.text.trim();
                      if (title.isEmpty || quote.isEmpty) {
                        setDialogState(
                          () => error = 'أدخل العنوان ونص الحكمة.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await context.read<ResourceProvider>().addCuratedQuote(
                          title: title,
                          quote: quote,
                          source: sourceController.text.trim(),
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (exception) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            saving = false;
                            error = 'تعذر حفظ الحكمة: $exception';
                          });
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    quoteController.dispose();
    sourceController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResourceProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة درر اليوم'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: provider.fetchCuratedQuotes,
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
                        'تعذر تحميل الحكم المُدارة. تأكد من تشغيل ملف إعداد الحكم في Supabase.',
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
                      'لا توجد حكم مُدارة بعد. سيعرض التطبيق اقتباسات المواد النصية المنشورة تلقائياً، ويمكنك إضافة قائمة حكم خاصة هنا.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: provider.curatedQuotes.length,
                  itemBuilder: (context, index) {
                    final quote = provider.curatedQuotes[index];
                    return Card(
                      child: ListTile(
                        title: Text(quote['title'] ?? ''),
                        subtitle: Text(
                          [
                            quote['quote'] ?? '',
                            if ((quote['source'] ?? '').isNotEmpty)
                              quote['source']!,
                          ].join('\n— '),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'حذف',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () async {
                            try {
                              await provider.deleteCuratedQuote(
                                id: int.parse(quote['id']!),
                              );
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('تعذر حذف الحكمة: $error'),
                                  ),
                                );
                              }
                            }
                          },
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
