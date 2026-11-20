import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/resource_model.dart';
import '../providers/resource_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/player/video_player_screen.dart';
import 'archive_ingestion_modal.dart';

class VideoPlayerWidget extends StatelessWidget {
  final ResourceModel resource;
  const VideoPlayerWidget({super.key, required this.resource});

  void _openVideo(BuildContext context, bool isReady) {
    if (!isReady) {
      ArchiveIngestionModal.show(
        context,
        resource: resource,
        onReady: () => _openVideo(context, true),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(resource: resource)),
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
        onTap: () => _openVideo(context, isReady),
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
              // Top Row: Category Pill & Ingestion Status & Favorites
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
                            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.videocam_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              resource.folderLabel,
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

              // Middle: Compact Video Thumbnail Preview + Title & Synopsis
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Compact Video Preview Thumbnail with Gold Play Badge
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 76,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          ),
                          border: Border.all(
                            color: radiantGold.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.movie_creation_outlined,
                          color: Colors.white24,
                          size: 28,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isReady ? radiantGold : Colors.amber.shade900,
                          boxShadow: [
                            BoxShadow(
                              color: radiantGold.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          isReady
                              ? Icons.play_arrow_rounded
                              : Icons.hourglass_top,
                          color: deepNavy,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Title and Snippet
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
                              'درس مرئي عالي الجودة من إصدارات دار الأثير',
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

              // Bottom Playable Action Button
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
                    isReady ? Icons.play_circle_fill : Icons.hourglass_top,
                    size: 17,
                    color: radiantGold,
                  ),
                  label: Text(
                    isReady
                        ? 'مشاهدة الدرس في شاشة كاملة (Play Video)'
                        : 'جاري التجهيز في الأرشيف ($remainingTime)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  onPressed: () => _openVideo(context, isReady),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
