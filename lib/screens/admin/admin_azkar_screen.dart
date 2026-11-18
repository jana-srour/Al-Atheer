import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/azkar_model.dart';
import '../../providers/azkar_provider.dart';
import '../../providers/resource_provider.dart';

class AdminAzkarScreen extends StatelessWidget {
  const AdminAzkarScreen({super.key});

  Future<void> _editAzkar(BuildContext context, [AzkarModel? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AzkarEditorDialog(item: item),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ الذكر')));
    }
  }

  Future<void> _deleteAzkar(BuildContext context, AzkarModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الذكر؟'),
        content: Text('سيتم حذف "${item.title}" والتنبيه المرتبط به.'),
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
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<AzkarProvider>().deleteAzkar(item.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر حذف الذكر: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AzkarProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الأذكار والتنبيهات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editAzkar(context),
        icon: const Icon(Icons.add),
        label: const Text('إضافة ذكر'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null && provider.azkar.isEmpty
          ? _LoadError(message: provider.error!, onRetry: provider.fetchAzkar)
          : provider.azkar.isEmpty
          ? const Center(child: Text('لم تُضف أذكار مجدولة بعد'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: provider.azkar.length,
              itemBuilder: (context, index) {
                final item = provider.azkar[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.notifications_active_outlined),
                    ),
                    title: Text(item.title),
                    subtitle: Text(
                      '${item.category} • ${item.repetitionCount} مرات • '
                      '${item.scheduledAt.toLocal()}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'تعديل',
                          onPressed: () => _editAzkar(context, item),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'حذف',
                          onPressed: () => _deleteAzkar(context, item),
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
          const Text('تعذر تحميل الأذكار'),
          const SizedBox(height: 8),
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

class _AzkarEditorDialog extends StatefulWidget {
  final AzkarModel? item;

  const _AzkarEditorDialog({this.item});

  @override
  State<_AzkarEditorDialog> createState() => _AzkarEditorDialogState();
}

class _AzkarEditorDialogState extends State<_AzkarEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _sourceController;
  late final TextEditingController _countController;
  late DateTime _scheduledAt;
  late String _category;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleController = TextEditingController(text: item?.title ?? '');
    _contentController = TextEditingController(text: item?.content ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _sourceController = TextEditingController(text: item?.source ?? '');
    _countController = TextEditingController(
      text: (item?.repetitionCount ?? 1).toString(),
    );
    _scheduledAt =
        item?.scheduledAt ?? DateTime.now().add(const Duration(minutes: 5));
    _category = item?.category ?? 'General';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _descriptionController.dispose();
    _sourceController.dispose();
    _countController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt.isBefore(DateTime.now())
          ? DateTime.now()
          : _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(
      () => _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_scheduledAt.isAfter(DateTime.now())) {
      setState(() => _error = 'اختر وقتاً مستقبلياً للتنبيه.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await context.read<AzkarProvider>().saveAzkar(
        AzkarModel(
          id: widget.item?.id ?? 0,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          description: _descriptionController.text.trim(),
          source: _sourceController.text.trim(),
          repetitionCount: int.parse(_countController.text.trim()),
          category: _category,
          scheduledAt: _scheduledAt,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = 'تعذر حفظ الذكر: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context
        .watch<ResourceProvider>()
        .categories
        .where((category) => category != 'All')
        .toList();
    if (!categories.contains(_category)) categories.add(_category);
    if (categories.isEmpty) categories.add('General');

    return AlertDialog(
      scrollable: true,
      title: Text(widget.item == null ? 'إضافة ذكر مجدول' : 'تعديل الذكر'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'العنوان *'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contentController,
                minLines: 3,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'نص الذكر/الدعاء/الآية *',
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'تفاصيل إضافية'),
                maxLines: 2,
              ),
              TextFormField(
                controller: _sourceController,
                decoration: const InputDecoration(labelText: 'المصدر'),
              ),
              TextFormField(
                controller: _countController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'عدد التكرار'),
                validator: (value) {
                  final count = int.tryParse(value ?? '');
                  return count == null || count < 1
                      ? 'أدخل عدداً صحيحاً'
                      : null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'المجلد'),
                items: categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: const Text('موعد التنبيه'),
                subtitle: Text(_scheduledAt.toLocal().toString()),
                onTap: _pickDateTime,
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
