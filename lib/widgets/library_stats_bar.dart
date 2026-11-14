import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/resource_provider.dart';
import '../providers/settings_provider.dart';
import 'archive_ingestion_modal.dart';

class LibraryStatsBar extends StatelessWidget {
  final Function(String type)? onSelectType;
  final bool showStats;

  const LibraryStatsBar({
    super.key,
    this.onSelectType,
    this.showStats = true,
  });

  @override
  Widget build(BuildContext context) {
    const radiantGold = Color(0xFFF59E0B);
    final resProv = Provider.of<ResourceProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final processingList = resProv.processingResources;
    final totalCount = resProv.resources.length;
    final pdfCount = resProv.countByType('pdf');
    final audioCount = resProv.countByType('audio');
    final videoCount = resProv.countByType('video');
    final textCount = resProv.countByType('text');

    return Column(
      children: [
        // Live Processing Alert Banner if Archive.org is currently indexing items
        if (processingList.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: InkWell(
              onTap: () {
                ArchiveIngestionModal.show(
                  context,
                  resource: processingList.first,
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.shade900.withValues(alpha: 0.2),
                      Colors.amber.shade800.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: radiantGold.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top, color: radiantGold, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${processingList.length} ملف قيد التجهيز في أرشيف الإنترنت',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: radiantGold,
                            ),
                          ),
                          Text(
                            'المتبقي: ${processingList.first.formattedRemainingTime(delaySeconds: settings.archiveIngestionDelaySeconds)} • جاري البث التلقائي',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 12, color: radiantGold),
                  ],
                ),
              ),
            ),
          ),
        ],

        // Informative Snapshot Stats Row
        if (showStats && onSelectType != null)
          SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              _buildStatChip(
                label: 'الكل',
                count: totalCount,
                icon: Icons.grid_view_rounded,
                color: radiantGold,
                isSelected: resProv.selectedType == 'all',
                onTap: () => onSelectType!('all'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                label: 'كتب PDF',
                count: pdfCount,
                icon: Icons.menu_book_rounded,
                color: Colors.redAccent,
                isSelected: resProv.selectedType == 'pdf',
                onTap: () => onSelectType!('pdf'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                label: 'صوتيات',
                count: audioCount,
                icon: Icons.audiotrack_rounded,
                color: radiantGold,
                isSelected: resProv.selectedType == 'audio',
                onTap: () => onSelectType!('audio'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                label: 'مرئيات',
                count: videoCount,
                icon: Icons.videocam_rounded,
                color: Colors.purpleAccent,
                isSelected: resProv.selectedType == 'video',
                onTap: () => onSelectType!('video'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                label: 'درر وفوائد',
                count: textCount,
                icon: Icons.format_quote_rounded,
                color: radiantGold,
                isSelected: resProv.selectedType == 'text',
                onTap: () => onSelectType!('text'),
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    const radiantGold = Color(0xFFF59E0B);
    const deepNavy = Color(0xFF0F172A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? deepNavy
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? radiantGold
                : radiantGold.withValues(alpha: 0.25),
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: radiantGold.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? radiantGold : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? radiantGold
                    : (isDark ? Colors.grey.shade300 : Colors.black87),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? radiantGold.withValues(alpha: 0.2)
                    : (isDark ? Colors.white12 : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? radiantGold : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
