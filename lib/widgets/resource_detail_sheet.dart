import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/resource_model.dart';
import '../providers/resource_provider.dart';
import '../providers/settings_provider.dart';
import '../services/archive_upload_service.dart';
import 'archive_ingestion_modal.dart';

class ResourceDetailSheet extends StatelessWidget {
  final ResourceModel resource;

  const ResourceDetailSheet({super.key, required this.resource});

  static void show(BuildContext context, ResourceModel resource) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ResourceDetailSheet(resource: resource),
    );
  }

  @override
  Widget build(BuildContext context) {
    const radiantGold = Color(0xFFF59E0B);
    const deepNavy = Color(0xFF0F172A);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context);
    final resProv = Provider.of<ResourceProvider>(context);

    final isReady = resProv.isResourceReady(
      resource,
      delaySeconds: settings.archiveIngestionDelaySeconds,
    );
    final isFav = settings.isFavorite(resource.id);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: radiantGold.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Center handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Top Badges & Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: deepNavy,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: radiantGold.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        resource.folderLabel,
                        style: const TextStyle(
                          color: radiantGold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        resource.typeLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isFav ? Icons.star : Icons.star_border,
                        color: isFav ? radiantGold : Colors.grey,
                      ),
                      tooltip: 'حفظ في المفضلة',
                      onPressed: () => settings.toggleFavorite(resource.id),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.share_outlined,
                        color: Colors.grey,
                      ),
                      tooltip: 'مشاركة',
                      onPressed: () {
                        Share.share(
                          '${resource.title}\n\n${resource.description ?? resource.textContent ?? ""}\n${resource.archiveUrl ?? ""}',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Title
            Text(
              resource.title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),

            // Publication Date & Source
            Text(
              'تاريخ الإضافة: ${resource.formattedDate} • دار الأثير للنشر',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Ingestion status alert banner if still in timer window
            if (!isReady) ...[
              InkWell(
                onTap: () {
                  ArchiveIngestionModal.show(context, resource: resource);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.amber.shade700.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.hourglass_top,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'الملف قيد التجهيز في أرشيف الإنترنت',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                            Text(
                              'متبقي حوالي ${resource.formattedRemainingTime(delaySeconds: settings.archiveIngestionDelaySeconds)} دقيقة لاكتمال الفهرسة لمنع خطأ (غير موجود). اضغط للفحص.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_left, color: Colors.amber),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Description or Text Content
            if (resource.description != null &&
                resource.description!.isNotEmpty) ...[
              const Text(
                'نبذة عن المحتوى:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: radiantGold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                resource.description!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (resource.textContent != null &&
                resource.textContent!.isNotEmpty) ...[
              const Text(
                'نص الفائدة / الاقتباس:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: radiantGold,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.amber.shade50)
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: radiantGold.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '«${resource.textContent!}»',
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.7,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Archive.org Reference details
            if (resource.archiveUrl != null &&
                resource.archiveUrl!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.04,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storage, size: 18, color: radiantGold),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'مستضاف بأمان ودقة عالية على شبكة أرشيف الإنترنت العالمية (Archive.org).',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        size: 16,
                        color: radiantGold,
                      ),
                      tooltip: 'نسخ الرابط المباشر',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: resource.archiveUrl!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم نسخ رابط الأرشيف بنجاح'),
                            backgroundColor: deepNavy,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Bottom Buttons
            Row(
              children: [
                if (resource.archiveUrl != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: radiantGold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(
                        Icons.open_in_browser,
                        size: 18,
                        color: radiantGold,
                      ),
                      label: const Text(
                        'عرض في Archive.org',
                        style: TextStyle(fontSize: 12, color: radiantGold),
                      ),
                      onPressed: () {
                        final details =
                            ArchiveUploadService.getDetailsUrlFromDirectUrl(
                              resource.archiveUrl,
                            );
                        if (details != null) {
                          launchUrl(
                            Uri.parse(details),
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: deepNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: radiantGold, width: 1.2),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'إغلاق',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
