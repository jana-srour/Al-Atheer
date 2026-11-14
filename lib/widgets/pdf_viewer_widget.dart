import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/resource_model.dart';
import '../providers/resource_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/pdf_reader_screen.dart';
import '../screens/player/pdf_reader_screen.dart' as native_pdf;
import 'archive_ingestion_modal.dart';

class PdfViewerWidget extends StatelessWidget {
  final ResourceModel resource;
  const PdfViewerWidget({super.key, required this.resource});

  Future<File> _downloadAndCachePdf(String url) async {
    final client = http.Client();
    try {
      final uri = Uri.parse(url);
      final request = http.Request('GET', uri)
        ..headers['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

      final streamedResponse = await client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/resource_${resource.id}.pdf');
        await file.writeAsBytes(bytes);
        return file;
      } else {
        throw HttpException(
          'PDF download failed with status ${response.statusCode}.',
          uri: uri,
        );
      }
    } finally {
      client.close();
    }
  }

  void _handleOpenPdf(BuildContext context, bool isReady) async {
    final archiveUrl = resource.archiveUrl?.trim();
    if (archiveUrl == null || archiveUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يتوفر رابط لهذا الملف.')),
      );
      return;
    }

    if (!isReady) {
      ArchiveIngestionModal.show(
        context,
        resource: resource,
        onReady: () => _handleOpenPdf(context, true),
      );
      return;
    }

    if (kIsWeb) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfReaderScreen(url: archiveUrl, title: resource.title),
        ),
      );
      return;
    }

    const radiantGold = Color(0xFFF59E0B);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: radiantGold),
            SizedBox(height: 12),
            Text(
              'جاري تجهيز وقراءة الكتاب داخل التطبيق...',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );

    File? file;
    Object? downloadError;
    try {
      file = await _downloadAndCachePdf(archiveUrl);
    } catch (error) {
      downloadError = error;
      debugPrint('Exception during PDF download: $error');
    }
    if (context.mounted) {
      Navigator.pop(context); // pop loading dialog
    }

    final downloadedFile = file;
    if (downloadedFile != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => native_pdf.PdfReaderScreen(
            pdfFile: downloadedFile,
            title: resource.title,
          ),
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloadError == null
                ? 'تعذر تنزيل ملف PDF. قد يكون الرابط غير جاهز بعد.'
                : 'فشل تنزيل ملف PDF. تحقق من اتصال الإنترنت ثم أعد المحاولة.',
          ),
          action: downloadError == null
              ? SnackBarAction(
                  label: 'فحص التجهيز',
                  textColor: radiantGold,
                  onPressed: () {
                    ArchiveIngestionModal.show(context, resource: resource);
                  },
                )
              : null,
          backgroundColor: Colors.amber.shade900,
          duration: const Duration(seconds: 5),
        ),
      );
    }
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
    final remainingTime = resource.formattedRemainingTime(
      delaySeconds: settings.archiveIngestionDelaySeconds,
    );
    final isFav = settings.isFavorite(resource.id);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 7),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isReady
              ? radiantGold.withValues(alpha: 0.35)
              : Colors.amber.withValues(alpha: 0.7),
          width: isReady ? 1.2 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: () => _handleOpenPdf(context, isReady),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF131F37), const Color(0xFF0B1426)]
                  : [Colors.white, const Color(0xFFF8FAFC)],
            ),
          ),
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
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
                          gradient: const LinearGradient(
                            colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.menu_book_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              resource.category,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!isReady)
                        InkWell(
                          onTap: () => ArchiveIngestionModal.show(
                            context,
                            resource: resource,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade400),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.hourglass_top,
                                  size: 10,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'تجهيز: $remainingTime',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Text(
                          resource.formattedDate,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.star : Icons.star_border,
                          size: 19,
                          color: isFav ? radiantGold : Colors.grey,
                        ),
                        tooltip: 'حفظ في المفضلة',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => settings.toggleFavorite(resource.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        tooltip: 'Share',
                        color: Colors.grey,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Share.share(
                            '${resource.title}\n${resource.archiveUrl ?? ""}',
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Book Cover Thumbnail & Details
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF991B1B), Color(0xFF450A0A)],
                      ),
                      border: Border.all(color: radiantGold, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(1, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 3,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 1.5,
                            color: radiantGold.withValues(alpha: 0.6),
                          ),
                        ),
                        const Icon(
                          Icons.picture_as_pdf,
                          color: Color(0xFFFAF7F0),
                          size: 26,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resource.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resource.description ??
                              'كتاب إلكتروني ووثيقة علمية متاح للمطالعة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Playable / Readable Action Button
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReady ? deepNavy : Colors.amber.shade900,
                    foregroundColor: Colors.white,
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isReady ? radiantGold : Colors.amberAccent,
                        width: 1,
                      ),
                    ),
                  ),
                  icon: Icon(
                    isReady ? Icons.auto_stories : Icons.hourglass_top,
                    size: 17,
                    color: radiantGold,
                  ),
                  label: Text(
                    isReady
                        ? (kIsWeb
                              ? 'فتح الوثيقة (Web PDF)'
                              : 'قراءة الكتاب داخل التطبيق')
                        : 'جاري التجهيز في الأرشيف ($remainingTime)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  onPressed: () => _handleOpenPdf(context, isReady),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
