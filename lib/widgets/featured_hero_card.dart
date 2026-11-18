import 'package:flutter/material.dart';
import '../models/resource_model.dart';
import 'resource_detail_sheet.dart';

class FeaturedHeroCard extends StatelessWidget {
  final ResourceModel resource;

  const FeaturedHeroCard({super.key, required this.resource});

  @override
  Widget build(BuildContext context) {
    const radiantGold = Color(0xFFF59E0B);
    const deepNavy = Color(0xFF0F172A);
    final resourceIcon = switch (resource.type) {
      'pdf' => Icons.menu_book,
      'audio' => Icons.audiotrack,
      'video' => Icons.videocam,
      'image' => Icons.image_outlined,
      'post' => Icons.post_add,
      _ => Icons.format_quote,
    };
    final actionLabel = switch (resource.type) {
      'pdf' => 'تصفح الكتاب',
      'audio' => 'استمع الآن',
      'video' => 'شاهد الدرس',
      'image' => 'عرض الصورة',
      'post' => 'عرض المنشور',
      _ => 'قراءة الفائدة',
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF060D1A), Color(0xFF0F172A), Color(0xFF1E3A5F)],
        ),
        border: Border.all(color: radiantGold, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: radiantGold.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => ResourceDetailSheet.show(context, resource),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag row: "Featured" badge & Category
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: radiantGold.withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 12, color: deepNavy),
                          SizedBox(width: 4),
                          Text(
                            'إصدار مميز مختار',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: deepNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: radiantGold.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        resource.category,
                        style: const TextStyle(
                          color: radiantGold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Main Content
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emblem / Cover icon
                    Container(
                      width: 54,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(2, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(resourceIcon, color: deepNavy, size: 30),
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
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            resource.description ??
                                resource.textContent ??
                                'منتقى من كنوز دار الأثير للنشر والعلوم الإسلامية.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Bottom Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'أضيف بتاريخ: ${resource.formattedDate}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: radiantGold,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionLabel,
                            style: const TextStyle(
                              color: deepNavy,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: deepNavy,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
