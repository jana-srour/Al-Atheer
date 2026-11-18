import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/azkar_provider.dart';
import '../providers/settings_provider.dart';
import '../services/web_push_client.dart';

class AzkarScreen extends StatelessWidget {
  const AzkarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AzkarProvider>();
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('الأذكار المجدولة')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null && provider.azkar.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('تعذر تحميل الأذكار'),
                    const SizedBox(height: 8),
                    Text(provider.error!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: provider.fetchAzkar,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (provider.notificationError != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.notifications_off_outlined),
                      title: const Text('التنبيهات المحلية غير متاحة'),
                      subtitle: Text(provider.notificationError!),
                    ),
                  ),
                Card(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.alarm),
                    title: const Text('تفعيل تنبيهات هذا الجهاز'),
                    subtitle: Text(
                      provider.remindersEnabled
                          ? 'سيتم تنبيهك في الأوقات المجدولة'
                          : 'يلزم السماح بالإشعارات لتلقي التنبيهات',
                    ),
                    value: provider.remindersEnabled,
                    onChanged: (enabled) async {
                      try {
                        await provider.setRemindersEnabled(enabled);
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تعذر تفعيل التنبيهات: $error'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
                if (kIsWeb)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.web),
                      title: const Text('تنبيهات الويب حتى بعد إغلاق الموقع'),
                      subtitle: const Text(
                        'تتطلب تسجيل الدخول والسماح بإشعارات المتصفح',
                      ),
                      trailing: const Icon(Icons.notifications_active_outlined),
                      onTap: () async {
                        try {
                          await WebPushClient.enable(
                            soundEnabled:
                                settings.notificationAlarmSoundEnabled,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تفعيل تنبيهات الويب'),
                              ),
                            );
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'تعذر تفعيل تنبيهات الويب: $error',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                if (provider.azkar.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('لا توجد أذكار مجدولة حالياً')),
                  ),
                ...provider.azkar.map(
                  (item) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            item.content,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 20, height: 1.8),
                          ),
                          if (item.description?.isNotEmpty == true) ...[
                            const SizedBox(height: 8),
                            Text(item.description!),
                          ],
                          if (item.source?.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.source!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const Divider(),
                          Text(
                            '${item.category} • يكرر ${item.repetitionCount} مرات • '
                            '${item.scheduledAt.toLocal()}',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (settings.isArabic)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'لتلقي التنبيه حتى عند إغلاق التطبيق، فعّل التنبيهات على هذا الجهاز.',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
    );
  }
}
